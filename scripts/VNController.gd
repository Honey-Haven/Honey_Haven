extends Node

@export var vn_theme: Resource
@export_file("*.json") var script_path: String = "res://scripts/epilogue.json"
@export var actor_manager_path:     NodePath = "ActorManager"
@export var logic_path:             NodePath = "VNLogic"
@export var background_manager_path: NodePath = "BackgroundManager"

@onready var actor_manager:      Node = get_node(actor_manager_path)
@onready var logic:              Node = get_node(logic_path)
@onready var background_manager: Node = get_node(background_manager_path)

# ── Minigame registry ─────────────────────────────────────────────────────────
# Maps the Twine tag name → the scene path to load.
# Add a new entry here for every minigame you create.
const MINIGAME_SCENES: Dictionary = {
	"minigame_carrots":  "res://minigames/CarrotMinigame/scenes/main.tscn",
	"minigame_gameee":   "res://minigames/Gameee/Gameee.tscn",
	"minigame_chester":  "res://minigames/ChesterChase/scenes/chester_rules.tscn",
}

# The path to THIS scene, so we can return to it after a minigame.
const VN_SCENE_PATH = "res://resources/VNScene.tscn"  # ← CHANGE THIS to your actual VN scene path

func _ready() -> void:
	print("VNController ready. vn_theme=", vn_theme)
	SignalBus.minigame_start.connect(_on_minigame_start)
	SignalBus.script_finished.connect(_on_script_finished)
	_propagate_theme()
	_register_actors()
	_register_backgrounds()
	_register_audio()

	# ── Returning from a minigame ─────────────────────────────────────────────
	# MinigameReturn is an Autoload singleton. If the flag is set, a minigame
	# just finished and switched back to this scene. Resume from saved label.
	if MinigameReturn.returning_from_minigame:
		MinigameReturn.returning_from_minigame = false

		var resume_label: String    = MinigameReturn.pending_result.get("resume_label", "")
		var saved_stage: Dictionary = MinigameReturn.pending_result.get("stage_state", {})
		var saved_bg: String        = MinigameReturn.pending_result.get("current_bg", "")
		var saved_bgm: String       = MinigameReturn.pending_result.get("current_bgm", "")
		var saved_bgm_vol: float    = MinigameReturn.pending_result.get("current_bgm_vol", 0.0)
		MinigameReturn.pending_result = {}

		var return_script: String = MinigameReturn.script_path
		var packets: Array = _load_twine_json(return_script)
		if packets.is_empty():
			push_error("VNController: Twine JSON produced no packets on minigame return.")
			return
		logic.load_twine_script(packets)

		await get_tree().process_frame
		await get_tree().process_frame

		logic._dialogue_ui = logic._find_dialogue_ui(get_tree().root)
		if resume_label != "":
			logic.resume_after_minigame(resume_label, saved_stage, saved_bg, saved_bgm, saved_bgm_vol)
		else:
			logic.skip_next_day_splash = true
			logic.start()
		return

	# ── Normal startup ────────────────────────────────────────────────────────
	if menucontrolflow.selected_script != "":
		script_path = menucontrolflow.selected_script
		menucontrolflow.selected_script = ""
	var packets: Array = _load_twine_json(script_path)
	if packets.is_empty():
		push_error("VNController: Twine JSON produced no packets – check the file path.")
		return

	logic.load_twine_script(packets)

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
			"neutral": preload("res://actors/marty/Martyneutral(1).PNG"),
			"happy":   preload("res://actors/marty/Martyhappy(1).PNG"),
			"sad":     preload("res://actors/marty/Martysad(1).PNG"),
			"angry": preload("res://actors/marty/Martangry.PNG"),
			"surprised": preload("res://actors/marty/Martysuprised(1).PNG"),
			"serious": preload("res://actors/marty/Martyserious.PNG"),
			"scared": preload("res://actors/marty/Martyserious.PNG")
			
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
			"neutral": preload("res://actors/chester/chesterNeutral.webp"),
			"angry": preload("res://actors/chester/chesterAngry.webp"),
			"happy": preload("res://actors/chester/chesterHappy.webp"),
			"sad": preload("res://actors/chester/chesterSad.webp")
		}
	})

	actor_manager.register_actor({
		"id": "Barnaby",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/barnaby/barnaby_normal.png"),
			"angry": preload("res://actors/barnaby/barnaby_angry.png"),
			"happy": preload("res://actors/barnaby/barnaby_happy.png"),
			"sad": preload("res://actors/barnaby/barnaby_sad.png")
		}
	})

	actor_manager.register_actor({
		"id": "Peanut",
		"scale": 1.0,
		"expressions": {
			"open": preload("res://actors/peanut/peanutOpen.webp"),
			"sad": preload("res://actors/peanut/peanutCry.webp"),
			"neutral": preload("res://actors/peanut/peanutNeutral.webp")
		}
	})

	actor_manager.register_actor({
		"id": "Peaches",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/peaches/Opposumneutral.PNG"),
			"happy": preload("res://actors/peaches/Opposumhappu.PNG"),
			"angry": preload("res://actors/peaches/Opossumangry.PNG"),
			"sad": preload("res://actors/peaches/Opposumsad.PNG"),
		}
	})

	actor_manager.register_actor({
		"id": "Buttons",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/buttons/buttonsneutral.webp"),
			"angry": preload("res://actors/buttons/buttonsAngry.webp"),
			"happy": preload("res://actors/buttons/buttonsHappy.webp"),
			"sad": preload("res://actors/buttons/buttonsSad.webp"),
			"fake-smile": preload("res://actors/buttons/buttonsFakeSmile.webp")
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

	actor_manager.register_actor({
		"id": "Jane",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/jane/Janeneutral.PNG"),
			"angry": preload("res://actors/jane/Janeangry.PNG")
		}
	})

	actor_manager.register_actor({
		"id": "Smith",
		"scale": 1.1,
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
	
	actor_manager.register_actor({
		"id": "Muffins",
		"scale": .75,
		"expressions": {
			"neutral": preload("res://actors/muffins/muffinsNeutral.webp"),
			"scared": preload("res://actors/muffins/muffinsAngry.webp"),
			"happy": preload("res://actors/muffins/muffinsHappy.webp"),
			"sad": preload("res://actors/muffins/muffinSad.webp")
		}
	})
	
	actor_manager.register_actor({
		"id": "Mochi",
		"scale": 1.1,
		"expressions": {
			"neutral": preload("res://actors/mochi/mochiNeutral.webp"),
			"angry": preload("res://actors/mochi/mochiAngry.webp"),
			"happy": preload("res://actors/mochi/mochiHappy.webp"),
			"stern": preload("res://actors/mochi/mochiStern.webp")
		}
	})

func _register_backgrounds() -> void:
	TwineParser.register_background("sunny_bedroom", "res://backgrounds/sunny_bedroom.png")
	TwineParser.register_background("pepper_lane",  "res://backgrounds/pepper_lane.PNG")
	TwineParser.register_background("casserole_avenue",  "res://backgrounds/casserole_carrots.PNG")
	TwineParser.register_background("truffle_corner",  "res://backgrounds/truffleCorner.PNG")
	TwineParser.register_background("outside_town_square",  "res://backgrounds/TownsquareOutside.PNG")
	TwineParser.register_background("inside_town_square",  "res://backgrounds/JaneOffice.PNG")
	TwineParser.register_background("casserole_tear",  "res://backgrounds/tear.png")
	TwineParser.register_background("black_screen",  "res://backgrounds/black-screen.png")
	TwineParser.register_background("white_screen",  "res://backgrounds/white-screen.jpg")
	TwineParser.register_background("baby",  "res://backgrounds/baby.png")
	TwineParser.register_background("night_moon_bedroom",  "res://backgrounds/night_moon_bedroom.png")
	TwineParser.register_background("night_closed_bedroom",  "res://backgrounds/night_closed_bedroom.png")
	TwineParser.register_background("demon1",  "res://backgrounds/demon/Demon1.PNG")
	TwineParser.register_background("demon2",  "res://backgrounds/demon/Demon2.PNG")
	TwineParser.register_background("demon3",  "res://backgrounds/demon/Demon3.PNG")
	TwineParser.register_background("demon4",  "res://backgrounds/demon/Demon4.PNG")
	TwineParser.register_background("demon5",  "res://backgrounds/demon/Demon5.PNG")
	TwineParser.register_background("demon6",  "res://backgrounds/demon/Demon6.PNG")
	TwineParser.register_background("demon7",  "res://backgrounds/demon/Demon7.PNG")
	TwineParser.register_background("demon8",  "res://backgrounds/demon/Demon8.PNG")
	TwineParser.register_background("mirror",  "res://backgrounds/demon/mirror.PNG")	
	TwineParser.register_background("closet_letter",  "res://backgrounds/demon/Closet_letter.webp")
	TwineParser.register_background("night_eye_bedroom",  "res://backgrounds/night_eye_bedroom.png")
	TwineParser.register_background("foxs_house",  "res://backgrounds/foxshouse.jpg")


func _register_audio() -> void:
	TwineParser.register_bgm("music_A_Home_Called_Honey_Haven", "res://audio/bgm/ok/AHCHH.mp3", 0.0);
	TwineParser.register_bgm("music_Chester_Chase", "res://audio/bgm/musicupdated/Music/Chester Chase.mp3", -10.0);
	TwineParser.register_bgm("music_Chester", "res://audio/bgm/musicupdated/Music/Chester.mp3", -10.0);
	TwineParser.register_bgm("music_Demonic_Sympathy", "res://audio/bgm/musicupdated/Music/Demonic-Sympathy.mp3", 0.0);
	TwineParser.register_bgm("music_Demonic_Apathy", "res://audio/bgm/DA.mp3", 0.0);
	TwineParser.register_bgm("music_Demonic_Empathy", "res://audio/bgm/DE.mp3", 0.0);
	TwineParser.register_bgm("music_Dont_Talk_To_Me", "res://audio/bgm/musicupdated/Music/Don_t-Talk-To-Me-_Honey-Haven_.mp3", 10.0);
	TwineParser.register_bgm("music_Goodbye_Moon", "res://audio/bgm/musicupdated/Music/Goodbye Moon.mp3", 10.0);
	TwineParser.register_bgm("music_Goodnight_Moon", "res://audio/bgm/musicupdated/Music/Goodnight Moon.mp3", 10.0);
	#TwineParser.register_bgm("music_title_theme", "res://audio/bgm/musicupdated/Music/Honey Haven Title.mp3", -10.0);
	TwineParser.register_bgm("music_title_theme", "res://audio/bgm/musicupdated/Music/Honey-Haven-Title.mp3", -10.0);
	TwineParser.register_bgm("music_Peanut", "res://audio/bgm/musicupdated/Music/Peanut-_Honey-Haven_.mp3", 0.0);
	TwineParser.register_bgm("music_A_Great_Big_Helping_Of_Sarcasm", "res://audio/bgm/musicupdated/Music/REAL FINAL A Great Big Helping Of Sarcasm.mp3", -10.0);
	TwineParser.register_bgm("music_A_Touch_Of_Sarcasm", "res://audio/bgm/musicupdated/Music/REAL FINAL A Touch Of Sarcasm.mp3", -10.0);
	TwineParser.register_bgm("music_Untitled_Man", "res://audio/bgm/musicupdated/Music/Untitled Man.mp3", -10.0);
	TwineParser.register_bgm("music_Who_Is_This_Kid", "res://audio/bgm/musicupdated/Music/Who the hell is this kid! (Chester)_1.mp3", -10.0);
	
	TwineParser.register_overlay_sprite("hand-beckon-sprite", "res://hands/Hand-beckon-sprite(1).png")
	TwineParser.register_overlay_sprite("hand-grab-sprite", "res://hands/Hand-grab-sprite(1).png")
	TwineParser.register_overlay_sprite("hand-outstretched-sprite", "res://hands/Hand-outstretched-sprite.png")

	# ── Stranger SFX ─────────────────────────────────────────────────────────
	# Set this path to a distinct typewriter/blip sound for the Stranger character.
	# If the file doesn't exist yet, it will silently fall back to no sound.
	TwineParser.register_stranger_sfx("res://audio/sfx/stranger_blip.wav")
func _on_minigame_start(minigame_id: String, _data: Dictionary) -> void:
	var scene_path: String = MINIGAME_SCENES.get(minigame_id, "")

	if scene_path == "":
		push_warning("VNController: no scene registered for minigame tag '%s'" % minigame_id)
		# Nothing to launch — tell VNLogic to move on immediately
		SignalBus.minigame_end.emit({})
		return

	if not ResourceLoader.exists(scene_path):
		push_warning("VNController: scene file not found: " + scene_path)
		SignalBus.minigame_end.emit({})
		return

	# Save the label VNLogic should resume at, and which scene to return to.
	# VNLogic.get_resume_label() returns the label immediately AFTER the
	# minigame packet — i.e. the next passage in the script.
	MinigameReturn.vn_scene_path           = VN_SCENE_PATH
	MinigameReturn.script_path             = script_path
	MinigameReturn.returning_from_minigame = false
	MinigameReturn.pending_result          = {
		"resume_label":    logic.get_resume_label(),
		"stage_state":     logic.get_stage_state(),
		"current_bg":      logic.get_current_bg(),
		"current_bgm":     logic.get_current_bgm(),
		"current_bgm_vol": logic.get_current_bgm_volume(),
	}

	# Fade out BGM before the scene switch so the minigame starts silent.
	# Position is saved by AudioManager so we can resume from the same spot
	# when the player returns to the VN.
	SignalBus.bgm_stop.emit(0.5)

	# Full scene switch — the VN disappears, minigame takes over completely.
	get_tree().change_scene_to_file(scene_path)


func _on_script_finished() -> void:
	print("Script finished!")
	AudioManager.stop_and_forget()
	MinigameReturn.returning_from_minigame = false
	MinigameReturn.pending_result = {}
	MinigameReturn.script_path = ""
	get_tree().change_scene_to_file("res://scenes/days_menu.tscn")
