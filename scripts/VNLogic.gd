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
var _history: Array = [] # Stores: {"type": string, "id": string, "idx": int}
var _current_stage_state: Dictionary = {} # Stores: { "actor_id": {"expression": "...", "pos": "..."} }

# must_visit tracking: hub_id → Array of unvisited passage names
# Populated when TwineParser emits a "must_visit_hub" packet.
var _must_visit_remaining: Dictionary = {}
# Stores the continuation label for each hub (the passage after all branches done).
var _must_visit_continuation: Dictionary = {}
# The hub packet currently being managed (so we can re-show the menu).
var _active_hub: Dictionary = {}

func load_script(json_array: Array) -> void:
	_packets = ScriptParser.parse(json_array)
	_index = 0
	_labels = _build_label_map(_packets)
	_history.clear()

## Use this instead of load_script() when feeding TwineParser output.
## Twine packets are already fully formed — ScriptParser would strip
## any type it doesn't recognise (e.g. must_visit_hub), so we skip it.
func load_twine_script(packets: Array) -> void:
	_packets = packets
	_index = 0
	_labels = _build_label_map(_packets)
	_history.clear()
	_must_visit_remaining.clear()
	_must_visit_continuation.clear()
	_active_hub = {}

func start() -> void:
	_process_next()

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
	var current_idx = _index
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
			_current_stage_state[packet["actor_id"]] = {"expression": packet.get("expression", "neutral"), "position": appear_pos}
			SignalBus.actor_appear.emit(packet["actor_id"], _current_stage_state[packet["actor_id"]]["expression"], appear_pos)
			_process_next()
		"dialogue":
			_history.append({"idx": current_idx, "stage_snapshot": _current_stage_state.duplicate(true)})
			_handle_dialogue(packet)
		"actor_hide":
			_current_stage_state.erase(packet["actor_id"])
			SignalBus.actor_hide.emit(packet["actor_id"])
			_process_next()
		"background":
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
			var expr_actor = packet["actor_id"]
			var expr_val = packet["expression"]
			if _current_stage_state.has(expr_actor):
				_current_stage_state[expr_actor]["expression"] = expr_val
			SignalBus.actor_expression.emit(expr_actor, expr_val)
			_process_next()
		"bgm":
			if packet["action"] == "play":
				SignalBus.bgm_play.emit(packet["path"], packet["fade"], packet.get("volume", 0.0))
			else:
				SignalBus.bgm_stop.emit(packet.get("fade", 0.5))
			_process_next()
		"sfx":
			SignalBus.sfx_play.emit(packet["path"])
			_process_next()
		"minigame":
			_in_minigame = true
			SignalBus.minigame_start.emit(packet["id"], packet.get("data", {}))
		"must_visit_hub":
			_handle_must_visit_hub(packet)
		_:
			_process_next()
	SignalBus.back_button_visibility_changed.emit(_history.size() >= 2)
	
func _handle_must_visit_hub(packet: Dictionary) -> void:
	var hub_id: String      = packet.get("hub_id", "")
	var all_branches: Array = packet.get("must_visit", [])
	var continuation: String = packet.get("continuation", "")

	# First time we see this hub – register it.
	if not _must_visit_remaining.has(hub_id):
		_must_visit_remaining[hub_id] = all_branches.duplicate()
		_must_visit_continuation[hub_id] = continuation

	_active_hub = packet
	_show_must_visit_menu(hub_id)

func _show_must_visit_menu(hub_id: String) -> void:
	var remaining: Array = _must_visit_remaining.get(hub_id, [])

	if remaining.is_empty():
		_active_hub = {}
		var cont: String = _must_visit_continuation.get(hub_id, "")
		if cont != "":
			_jump_to_label(TwineParser._label_for(cont))
		else:
			_process_next()
		return

	var label_map: Dictionary = _active_hub.get("label_map", {})
	var choices: Array = []
	for branch_name in remaining:
		var display: String = label_map.get(branch_name, branch_name)
		choices.append({
			"label":        display,
			"goto":         TwineParser._label_for(branch_name),
			"passage_name": branch_name,   # needed to erase from remaining
		})

	# Store on instance so _on_choice_selected reads it directly,
	# without touching _packets (which would corrupt _index).
	_active_hub = {
		"type":             "choice",
		"prompt":           "Where to?",
		"choices":          choices,
		"__must_visit_hub": hub_id,
	}
	_choice_pending = true
	_waiting_for_input = false
	SignalBus.scene_packet_ready.emit(_active_hub)

func go_back() -> void:
	if _history.size() < 2: return
	
	_history.pop_back() # Discard current line
	var prev_state = _history.pop_back() # Get the snapshot
	
	# 1. Clear everyone
	SignalBus.clear_visual_state.emit()
	
	# 2. Restore the stage from the snapshot
	_current_stage_state = prev_state.get("stage_snapshot", {}).duplicate(true)
	for actor_id in _current_stage_state:
		var data = _current_stage_state[actor_id]
		SignalBus.actor_appear.emit(actor_id, data["expression"], data["position"], true)
		
	# 3. Resume the script
	_index = prev_state["idx"]
	_waiting_for_input = false
	_process_next()

func _handle_dialogue(packet: Dictionary) -> void:
	var speaker: String = packet.get("speaker", "").strip_edges()
	var expression: String = packet.get("expression", "").strip_edges()
	if speaker != "" and expression != "" and _current_stage_state.has(speaker):
		_current_stage_state[speaker]["expression"] = expression
		SignalBus.actor_expression.emit(speaker, expression)
	_waiting_for_input = true
	SignalBus.scene_packet_ready.emit(packet)
	SignalBus.dialogue_line_started.emit(packet)

func _handle_choice(packet: Dictionary) -> void:
	_choice_pending = true
	_waiting_for_input = false
	SignalBus.scene_packet_ready.emit(packet)

func _on_choice_selected(choice_index: int) -> void:
	if not _choice_pending:
		return
	_choice_pending = false

	# ── must_visit hub path ──────────────────────────────────────────────────
	# _active_hub is set by _show_must_visit_menu and holds the live packet,
	# so we never need to read _packets[_index-1] for hub choices.
	if not _active_hub.is_empty() and _active_hub.has("__must_visit_hub"):
		var hub_id: String  = _active_hub["__must_visit_hub"]
		var choices: Array  = _active_hub.get("choices", [])
		if choice_index < choices.size():
			var chosen_passage: String = choices[choice_index].get("passage_name", choices[choice_index].get("label", ""))
			var remaining: Array = _must_visit_remaining.get(hub_id, [])
			remaining.erase(chosen_passage)
			_must_visit_remaining[hub_id] = remaining
			# Clear history and hide back button — no going back after a hub choice.
			_history.clear()
			SignalBus.back_button_visibility_changed.emit(false)
			# Clear _active_hub BEFORE jumping so that normal choices inside
			# the branch are not mistaken for must_visit hub choices.
			var goto_label: String = choices[choice_index].get("goto", "")
			_active_hub = {}
			_jump_to_label(goto_label)
		return

	# ── Normal choice path ────────────────────────────────────────────────────
	var prev: Dictionary = _packets[_index - 1]
	var choices: Array   = prev.get("choices", [])
	_history.clear()
	SignalBus.back_button_visibility_changed.emit(false)
	if choice_index < choices.size():
		var goto_label: String = choices[choice_index].get("goto", "")
		if goto_label != "":
			_jump_to_label(goto_label)
			return
	# Fall back to silent continuation ([[PassageName]] with no arrow)
	var continuation: String = prev.get("continuation", "")
	if continuation != "":
		_jump_to_label(continuation)
		return
	_process_next()

func _on_minigame_end(_result: Dictionary) -> void:
	_in_minigame = false
	_process_next()

func _jump_to_label(label_name: String) -> void:
	if _labels.has(label_name):
		_index = _labels[label_name]
		_process_next()
	else:
		push_error("VNLogic: label '%s' not found!" % label_name)

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

func get_history_count(): 
	return _history.size()
