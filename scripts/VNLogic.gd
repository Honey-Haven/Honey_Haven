extends Node
class_name VNLogic
signal advance_requested()
@export var vn_theme: Resource

var _packets: Array = []
var _index: int = 0
var _labels: Dictionary = {}
var _waiting_for_input: bool = false
var _choice_pending: bool = false
var _in_minigame: bool = false
var _history: Array = [] # Stores: {"idx": int, "stage_snapshot": {}, "overlay_active": bool, "overlay_path": str, "bg": str}
var _current_stage_state: Dictionary = {} # { actor_id: {"expression": "...", "position": "..."} }
var _current_overlay_active: bool = false
var _current_bg: String = ""
var _current_overlay_path: String = ""
var _current_bgm: String = ""
var skip_next_day_splash: bool = false

# must_visit tracking: hub_id → Array of unvisited passage names
var _must_visit_remaining: Dictionary = {}
var _must_visit_continuation: Dictionary = {}
var _active_hub: Dictionary = {}

# Reference to DialogueUI for direct method calls (screen flash, day splash)
var _dialogue_ui: Node = null

func load_script(json_array: Array) -> void:
	_packets = ScriptParser.parse(json_array)
	_index = 0
	_labels = _build_label_map(_packets)
	_history.clear()

func load_twine_script(packets: Array) -> void:
	_packets = packets
	_index = 0
	_labels = _build_label_map(_packets)
	_history.clear()
	_must_visit_remaining.clear()
	_must_visit_continuation.clear()
	_active_hub = {}
	_current_overlay_active = false
	_current_bg = ""
	_current_overlay_path = ""
	_current_bgm = ""

func start() -> void:
	_dialogue_ui = _find_dialogue_ui(get_tree().root)
	_process_next()

func _find_dialogue_ui(node: Node) -> Node:
	if node.get_script() and node.get_script().resource_path.ends_with("DialogueUI.gd"):
		return node
	for child in node.get_children():
		var result = _find_dialogue_ui(child)
		if result:
			return result
	return null

func _ready() -> void:
	SignalBus.choice_selected.connect(_on_choice_selected)
	SignalBus.dialogue_line_finished.connect(_on_advance)
	SignalBus.go_back_requested.connect(go_back)

func _on_advance() -> void:
	if not _waiting_for_input: return
	_waiting_for_input = false
	_process_next()

func _process_next() -> void:
	if _index >= _packets.size():
		SignalBus.script_finished.emit()
		return

	var packet: Dictionary = _packets[_index]
	var current_idx: int   = _index
	_index += 1

	match packet.get("type", ""):
		"appear":
			var appear_pos: String = packet.get("position", "")
			if appear_pos == "" or appear_pos == "center":
				var used: Array = []
				for aid in _current_stage_state:
					used.append(_current_stage_state[aid].get("position", ""))
				if not used.has("left"):
					appear_pos = "left"
				elif not used.has("right"):
					appear_pos = "right"
				else:
					appear_pos = "left"
			var actor_id: String    = packet["actor_id"]
			var enter_expr: String  = packet.get("expression", "neutral")
			# If already on stage at the same position, just update expression.
			if _current_stage_state.has(actor_id) and _current_stage_state[actor_id].get("position", "") == appear_pos:
				_current_stage_state[actor_id]["expression"] = enter_expr
				SignalBus.actor_expression.emit(actor_id, enter_expr)
			else:
				_current_stage_state[actor_id] = {"expression": enter_expr, "position": appear_pos}
				SignalBus.actor_appear.emit(actor_id, enter_expr, appear_pos)
			_process_next()

		"dialogue":
			_history.append({
				"idx":            current_idx,
				"stage_snapshot": _current_stage_state.duplicate(true),
				"overlay_active": _current_overlay_active,
				"overlay_path":   _current_overlay_path,
				"bg":             _current_bg,
				"bgm":            _current_bgm,
			})
			_handle_dialogue(packet)

		"actor_hide":
			_current_stage_state.erase(packet["actor_id"])
			SignalBus.actor_hide.emit(packet["actor_id"])
			_process_next()

		"background":
			_current_bg = packet["path"]
			SignalBus.background_change.emit(packet["path"], packet.get("transition", "fade"))
			_process_next()

		"choice":
			_handle_choice(packet)

		"label":
			_process_next()

		"jump":
			_jump_to_label(packet["label"])

		"wait":
			_do_wait(packet["duration"])

		"actor_move":
			SignalBus.actor_move.emit(packet["actor_id"], packet.get("position", "center"), packet.get("anim", "slide"))
			_process_next()

		"actor_anim":
			SignalBus.actor_animate.emit(packet["actor_id"], packet["anim"])
			_process_next()

		"actor_expression":
			var expr_actor: String = packet["actor_id"]
			var expr_val:   String = packet["expression"]
			if _current_stage_state.has(expr_actor):
				_current_stage_state[expr_actor]["expression"] = expr_val
			SignalBus.actor_expression.emit(expr_actor, expr_val)
			_process_next()

		"bgm":
			if packet["action"] == "play":
				_current_bgm = packet["path"]
				SignalBus.bgm_play.emit(packet["path"], packet["fade"], packet.get("volume", 0.0))
			else:
				_current_bgm = ""
				SignalBus.bgm_stop.emit(packet.get("fade", 0.5))
			_process_next()

		"sfx":
			SignalBus.sfx_play.emit(packet["path"])
			_process_next()

		"screen_flash":
			if _dialogue_ui and _dialogue_ui.has_method("play_screen_flash"):
				_dialogue_ui.play_screen_flash()
			_process_next()

		"day_splash":
			if skip_next_day_splash:
				skip_next_day_splash = false
				_process_next()
				return
			# The splash plays its full animation then emits dialogue_line_finished.
			# _waiting_for_input MUST be true so _on_advance() triggers _process_next().
			# The click-catcher is hidden inside play_day_splash so the player
			# cannot skip the animation by clicking.
			if _dialogue_ui and _dialogue_ui.has_method("play_day_splash"):
				_waiting_for_input = true
				_dialogue_ui.play_day_splash(
					packet.get("day_text", ""),
					packet.get("is_end", false),
					packet.get("bg_path", "")
				)
			else:
				_process_next()

		"overlay_sprite":
			if _dialogue_ui:
				if packet.get("show", false):
					_current_overlay_active = true
					_current_overlay_path   = packet.get("path", "")
					if _dialogue_ui.has_method("show_overlay_sprite"):
						_dialogue_ui.show_overlay_sprite(_current_overlay_path)
				else:
					_current_overlay_active = false
					_current_overlay_path   = ""
					if _dialogue_ui.has_method("hide_overlay_sprite"):
						_dialogue_ui.hide_overlay_sprite()
			_process_next()

		"minigame":
			_in_minigame = true
			SignalBus.minigame_start.emit(packet["id"], packet.get("data", {}))

		"must_visit_hub":
			_handle_must_visit_hub(packet)

		_:
			_process_next()

	SignalBus.back_button_visibility_changed.emit(_history.size() >= 2)


# ── Must-visit hub ────────────────────────────────────────────────────────────

func _handle_must_visit_hub(packet: Dictionary) -> void:
	var hub_id: String       = packet.get("hub_id", "")
	var all_branches: Array  = packet.get("must_visit", [])
	var continuation: String = packet.get("continuation", "")

	if hub_id == "":
		push_error("VNLogic: must_visit_hub packet is missing 'hub_id' — check TwineParser output.")
		_process_next()
		return

	# Only initialise on the first visit; returning visits preserve the
	# already-reduced remaining list.
	if not _must_visit_remaining.has(hub_id):
		_must_visit_remaining[hub_id]     = all_branches.duplicate()
		_must_visit_continuation[hub_id]  = continuation

	_active_hub = packet
	_show_must_visit_menu(hub_id)


func _show_must_visit_menu(hub_id: String) -> void:
	var remaining: Array = _must_visit_remaining.get(hub_id, [])

	if remaining.is_empty():
		_active_hub = {}
		var cont: String = _must_visit_continuation.get(hub_id, "")
		if cont != "":
			# cont is already a label string produced by TwineParser._label_for()
			_jump_to_label(cont)
		else:
			_process_next()
		return

	# Build choice buttons — one per remaining (unvisited) branch.
	# label_map: passage_name → display text sent by TwineParser.
	var label_map: Dictionary = _active_hub.get("label_map", {})
	var choices: Array = []
	for branch_name in remaining:
		var display: String = label_map.get(branch_name, branch_name)
		choices.append({
			"label":        display,
			"goto":         TwineParser._label_for(branch_name),
			"passage_name": branch_name,
		})

	_active_hub = {
		"type":             "choice",
		"prompt":           "Where to?",
		"choices":          choices,
		"__must_visit_hub": hub_id,
	}
	_choice_pending     = true
	_waiting_for_input  = false
	SignalBus.scene_packet_ready.emit(_active_hub)


# ── Go back ───────────────────────────────────────────────────────────────────

func go_back() -> void:
	if _history.size() < 2: return

	_history.pop_back()
	var prev_state = _history.pop_back()

	SignalBus.clear_visual_state.emit()
	# Wait one frame so ActorManager fully finishes clearing (kills all hide-tweens,
	# resets all sprites) before we re-appear actors from the previous state.
	# Without this, actors from the forward state can ghost-appear on top of the restored ones.
	await get_tree().process_frame

	var prev_bg: String = prev_state.get("bg", "")
	if prev_bg != "":
		_current_bg = prev_bg
		SignalBus.background_change.emit(prev_bg, "cut")

	var prev_bgm: String = prev_state.get("bgm", "")
	if prev_bgm != _current_bgm:
		_current_bgm = prev_bgm
		if prev_bgm != "":
			SignalBus.bgm_play.emit(prev_bgm, 0.5, 0.0)
		else:
			SignalBus.bgm_stop.emit(0.5)

	var was_overlay_active: bool  = prev_state.get("overlay_active", false)
	var prev_overlay_path: String = prev_state.get("overlay_path", "")
	_current_overlay_active = was_overlay_active
	_current_overlay_path   = prev_overlay_path
	if _dialogue_ui:
		if was_overlay_active and prev_overlay_path != "":
			if _dialogue_ui.has_method("show_overlay_sprite"):
				_dialogue_ui.show_overlay_sprite(prev_overlay_path)
		else:
			if _dialogue_ui.has_method("hide_overlay_sprite"):
				_dialogue_ui.hide_overlay_sprite()

	_current_stage_state = prev_state.get("stage_snapshot", {}).duplicate(true)
	for actor_id in _current_stage_state:
		var data = _current_stage_state[actor_id]
		SignalBus.actor_appear.emit(actor_id, data["expression"], data["position"], true)
		SignalBus.actor_expression.emit(actor_id, data["expression"])

	_index = prev_state["idx"]
	_waiting_for_input = false
	_process_next()


# ── Dialogue ──────────────────────────────────────────────────────────────────

func _handle_dialogue(packet: Dictionary) -> void:
	var speaker:    String = packet.get("speaker", "").strip_edges()
	var expression: String = packet.get("expression", "").strip_edges()
	if speaker != "" and expression != "" and _current_stage_state.has(speaker):
		_current_stage_state[speaker]["expression"] = expression
		SignalBus.actor_expression.emit(speaker, expression)
	# Quiver tag — also shake the speaking character's sprite
	if packet.get("char_effect", "") == "quiver" and speaker != "":
		SignalBus.actor_animate.emit(speaker, "shake")
	_waiting_for_input = true
	SignalBus.scene_packet_ready.emit(packet)
	SignalBus.dialogue_line_started.emit(packet)


# ── Choice ────────────────────────────────────────────────────────────────────

func _handle_choice(packet: Dictionary) -> void:
	_choice_pending    = true
	_waiting_for_input = false
	SignalBus.scene_packet_ready.emit(packet)


func _on_choice_selected(choice_index: int) -> void:
	if not _choice_pending:
		return
	_choice_pending = false

	# Must-visit branch selection
	if not _active_hub.is_empty() and _active_hub.has("__must_visit_hub"):
		var hub_id: String  = _active_hub["__must_visit_hub"]
		var choices: Array  = _active_hub.get("choices", [])
		if choice_index < choices.size():
			var chosen_passage: String = choices[choice_index].get("passage_name", choices[choice_index].get("label", ""))
			var remaining: Array = _must_visit_remaining.get(hub_id, [])
			remaining.erase(chosen_passage)
			_must_visit_remaining[hub_id] = remaining
			_history.clear()
			SignalBus.back_button_visibility_changed.emit(false)
			var goto_label: String = choices[choice_index].get("goto", "")
			_active_hub = {}
			_jump_to_label(goto_label)
		return

	# Regular choice selection
	var prev: Dictionary = _packets[_index - 1]
	var choices: Array   = prev.get("choices", [])
	_history.clear()
	SignalBus.back_button_visibility_changed.emit(false)
	if choice_index < choices.size():
		var goto_label: String = choices[choice_index].get("goto", "")
		if goto_label != "":
			_jump_to_label(goto_label)
			return
	var continuation: String = prev.get("continuation", "")
	if continuation != "":
		_jump_to_label(continuation)
		return
	_process_next()


# ── Snapshot getters ──────────────────────────────────────────────────────────

func get_stage_state() -> Dictionary:
	return _current_stage_state.duplicate(true)

func get_current_bg() -> String:
	return _current_bg

func get_resume_label() -> String:
	for i in range(_index, _packets.size()):
		if _packets[i].get("type") == "label":
			return _packets[i].get("name", "")
	return ""

func resume_after_minigame(label: String, stage_state: Dictionary = {}, saved_bg: String = "") -> void:
	_in_minigame = false
	if saved_bg != "":
		_current_bg = saved_bg
		SignalBus.background_change.emit(saved_bg, "cut")
	if not stage_state.is_empty():
		_current_stage_state = stage_state.duplicate(true)
		for actor_id in _current_stage_state:
			var data = _current_stage_state[actor_id]
			SignalBus.actor_appear.emit(actor_id, data["expression"], data["position"], true)
	if label != "":
		_jump_to_label(label)
	else:
		_process_next()

func _on_minigame_end(_result: Dictionary) -> void:
	_in_minigame = false
	_process_next()


# ── Internals ─────────────────────────────────────────────────────────────────

func _jump_to_label(label_name: String) -> void:
	if _labels.has(label_name):
		_index = _labels[label_name]
		_process_next()
	else:
		push_error("VNLogic: label '%s' not found! Available: %s" % [label_name, _labels.keys()])

func _do_wait(duration: float) -> void:
	_waiting_for_input = false
	await get_tree().create_timer(duration).timeout
	_process_next()

func _build_label_map(packets: Array) -> Dictionary:
	var map: Dictionary = {}
	for i in packets.size():
		if packets[i].get("type") == "label":
			map[packets[i]["name"]] = i + 1
	return map

func get_history_count() -> int:
	return _history.size()
