extends Node

@export var vn_theme: Resource
@export var actor_manager_path:     NodePath = "ActorManager"
@export var logic_path:             NodePath = "VNLogic"
@export var background_manager_path: NodePath = "BackgroundManager"

@onready var actor_manager:      Node = get_node(actor_manager_path)
@onready var logic:              Node = get_node(logic_path)
@onready var background_manager: Node = get_node(background_manager_path)

func _ready() -> void:
	print("VNController ready. vn_theme=", vn_theme)
	SignalBus.minigame_start.connect(_on_minigame_start)
	SignalBus.minigame_end.connect(_on_minigame_end)
	SignalBus.script_finished.connect(_on_script_finished)
	_propagate_theme()
	_register_actors()
	_register_backgrounds()
	_register_audio()

	# ── Load a Twine JSON export ──────────────────────────────────────────────
	#  Drop your exported .json file anywhere under res:// and point to it here.
	var packets: Array = _load_twine_json("res://scripts/day6.json")
	if packets.is_empty():
		push_error("VNController: Twine JSON produced no packets – check the file path.")
		return

	logic.load_twine_script(packets)

	# Wait two frames: one for all _ready() to finish,
	# one for DialogueUI's pre-render await to complete.
	await get_tree().process_frame
	await get_tree().process_frame
	logic.start()


## Loads a Twine-to-JSON export from `path` and converts it to VN packets.
func _load_twine_json(path: String) -> Array:
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		push_error("VNController: JSON file not found at '%s'" % path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("VNController: Could not open '%s'" % path)
		return []
	var raw: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err: int = json.parse(raw)
	if err != OK:
		push_error("VNController: JSON parse error in '%s': %s" % [path, json.get_error_message()])
		return []
	return TwineParser.parse(json.data)

func _propagate_theme() -> void:
	if not vn_theme:
		push_warning("VNController: vn_theme not assigned!")
		return
	_push_theme_recursive(self)

func _push_theme_recursive(node: Node) -> void:
	for child in node.get_children():
		if "vn_theme" in child:
			child.vn_theme = vn_theme
			print("Pushed theme to: ", child.name)
		_push_theme_recursive(child)

func _register_actors() -> void:
	actor_manager.register_actor({
		"id": "Marty",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/marty/Martyneutral.PNG"),
			"happy":   preload("res://actors/marty/Martyhappy.PNG"),
			"sad":     preload("res://actors/marty/Martysad.PNG"),
			"angry": preload("res://actors/marty/Martyangry.PNG"),
			"surprised": preload("res://actors/marty/Martysuprised.PNG")
			
		}
	})

	actor_manager.register_actor({
		"id": "Matthew",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/matthew/sheepNeutral.webp"),
			"happy":   preload("res://actors/matthew/sheepHappy.webp"),
			"sad":   preload("res://actors/matthew/sheepSad.webp"),
		}
	})

	actor_manager.register_actor({
		"id": "Chester",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/chester/chesterNeutral.webp")
		}
	})

	actor_manager.register_actor({
		"id": "Barnaby",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/barnaby/barnaby_happy.png")
		}
	})

	actor_manager.register_actor({
		"id": "Peanut",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/peanut/peanutOpen.webp")
		}
	})

	actor_manager.register_actor({
		"id": "Peaches",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/peaches/Opposumneutral.PNG")
		}
	})

	actor_manager.register_actor({
		"id": "Buttons",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/buttons/buttonsneutral.webp")
		}
	})

	
	actor_manager.register_actor({
		"id": "Scotch",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/scotch/Slothneutral.PNG"),
			"happy": preload("res://actors/scotch/Slothhappy.PNG"),
			"sad": preload("res://actors/scotch/Slothsad.PNG")
		}
	})
	actor_manager.register_actor({
		"id": "Tofu",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/tofu/Tofuneutral.PNG"),
			"happy": preload("res://actors/tofu/Tofuhappy.PNG"),
			"sad": preload("res://actors/tofu/Tofusad.PNG")
		}
	})
	#actor_manager.register_actor({
		#"id": "Mochi",
		#"scale": 1.0,
		#"expressions": {
			#"neutral": preload("res://actors/mochi/mochi_neutral.png")
		#}
	#})
#
	actor_manager.register_actor({
		"id": "Jane",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/jane/Janeneutral.PNG"),
			"angry": preload("res://actors/jane/Janeangry.PNG")
		}
	})
#
	actor_manager.register_actor({
		"id": "Smith",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/jonathon/jonathon_normal.png"),
			"scared": preload("res://actors/jonathon/jonathon_scared.png"),
			"happy": preload("res://actors/jonathon/jonathon_happy.png")
		}
	})
	
	actor_manager.register_actor({
		"id": "Wolf",
		"scale": 1.3,
		"expressions": {
			"neutral": preload("res://actors/wolf/wolfneutral2.png"),
			"angry": preload("res://actors/wolf/wolfangry2.png"),
			"happy": preload("res://actors/wolf/wolfhappy2.png")
		}
	})

func _register_backgrounds() -> void:
	TwineParser.register_background("sunny_bedroom", "res://backgrounds/sunny_bedroom.png")
	# Add more backgrounds here as you create them:
	TwineParser.register_background("pepper",  "res://backgrounds/TEMPpepper.jpg")
	TwineParser.register_background("casserole_avenue",  "res://backgrounds/casserole_carrots.PNG")
	TwineParser.register_background("truffle",  "res://backgrounds/TEMPtruffle.jpg")
	TwineParser.register_background("towncenter",  "res://backgrounds/TEMPtowncenter.jpg")

func _register_audio() -> void:
	TwineParser.register_bgm("honey-haven-title", "res://audio/bgm/Honey-Haven-Title.mp3", -20.0);
	TwineParser.register_bgm("demonic-sympathy", "res://audio/bgm/Demonic-Sympathy.mp3", -20.0);

	
func _on_minigame_start(minigame_id: String, data: Dictionary) -> void:
	var scene_path := "res://minigames/%s/%s.tscn" % [minigame_id, minigame_id]
	if ResourceLoader.exists(scene_path):
		var inst: Node = (load(scene_path) as PackedScene).instantiate()
		if inst.has_method("setup"):
			inst.setup(data)
		get_tree().root.add_child(inst)
		_set_scene_visible(false)
	else:
		push_warning("Minigame not found: " + scene_path)
		SignalBus.minigame_end.emit({})

func _on_minigame_end(_result: Dictionary) -> void:
	_set_scene_visible(true)

## Hide or show all CanvasItem children of this node.
## VNController extends Node (not CanvasItem), so we can't set .visible directly.
func _set_scene_visible(show: bool) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.visible = show

func _on_script_finished() -> void:
	print("Script finished!")
