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

func load_script(json_array: Array) -> void:
	_packets = ScriptParser.parse(json_array)
	_index = 0
	_labels = _build_label_map(_packets)
	_history.clear()

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
			SignalBus.actor_appear.emit(packet["actor_id"], _current_stage_state[packet["actor_id"]]["expression"], packet.get("position", ""))
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
				SignalBus.bgm_play.emit(packet["path"], packet.get("fade", 0.5))
			else:
				SignalBus.bgm_stop.emit(packet.get("fade", 0.5))
			_process_next()
		"sfx":
			SignalBus.sfx_play.emit(packet["path"])
			_process_next()
		"minigame":
			_in_minigame = true
			SignalBus.minigame_start.emit(packet["id"], packet.get("data", {}))
		_:
			_process_next()
	SignalBus.back_button_visibility_changed.emit(_history.size() >= 2)
	
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
	_history.clear()
	SignalBus.back_button_visibility_changed.emit(false)
	var prev: Dictionary = _packets[_index - 1]
	var choices: Array = prev.get("choices", [])
	if choice_index < choices.size():
		var goto_label: String = choices[choice_index].get("goto", "")
		if goto_label != "":
			_jump_to_label(goto_label)
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
