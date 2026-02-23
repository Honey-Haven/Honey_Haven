extends Node

signal advance_requested()

@export var vn_theme: Resource

var _packets: Array = []
var _index: int = 0
var _labels: Dictionary = {}
var _waiting_for_input: bool = false
var _choice_pending: bool = false
var _in_minigame: bool = false

func load_script(json_array: Array) -> void:
	_packets = ScriptParser.parse(json_array)
	_index = 0
	_labels = _build_label_map(_packets)
	_waiting_for_input = false
	_choice_pending = false

func start() -> void:
	_process_next()

func _ready() -> void:
	SignalBus.choice_selected.connect(_on_choice_selected)
	SignalBus.dialogue_line_finished.connect(_on_advance)
	SignalBus.minigame_end.connect(_on_minigame_end)

func _on_advance() -> void:
	print("VNLogic: advance received. waiting=", _waiting_for_input)
	if not _waiting_for_input:
		return
	_waiting_for_input = false
	_process_next()

func _process_next() -> void:
	if _index >= _packets.size():
		SignalBus.script_finished.emit()
		return

	var packet: Dictionary = _packets[_index]
	_index += 1
	print("VNLogic processing: ", packet.get("type"), " index=", _index)

	match packet.get("type", ""):
		"dialogue":
			_handle_dialogue(packet)
		"choice":
			_handle_choice(packet)
		"label":
			_process_next()
		"jump":
			_jump_to_label(packet["label"])
		"wait":
			_do_wait(packet["duration"])
		"actor_show":
			SignalBus.actor_show.emit(packet["actor"], packet["expression"], packet["position"])
			_process_next()
		"actor_hide":
			SignalBus.actor_hide.emit(packet["actor"])
			_process_next()
		"actor_move":
			SignalBus.actor_move.emit(packet["actor"], packet["position"], packet["anim"])
			_process_next()
		"actor_anim":
			SignalBus.actor_animate.emit(packet["actor"], packet["anim"])
			_process_next()
		"actor_expression":
			SignalBus.actor_expression.emit(packet["actor"], packet["expression"])
			_process_next()
		"background":
			SignalBus.background_change.emit(packet["path"], packet["transition"])
			_process_next()
		"bgm":
			if packet["action"] == "play":
				SignalBus.bgm_play.emit(packet["path"], packet["fade"])
			else:
				SignalBus.bgm_stop.emit(packet["fade"])
			_process_next()
		"sfx":
			SignalBus.sfx_play.emit(packet["path"])
			_process_next()
		"minigame":
			_in_minigame = true
			SignalBus.minigame_start.emit(packet["id"], packet["data"])
		_:
			_process_next()

func _handle_dialogue(packet: Dictionary) -> void:
	if packet.get("expression", "") != "":
		SignalBus.actor_expression.emit(packet["speaker"], packet["expression"])
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
	# find the choice packet (it's the one just before current index)
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
