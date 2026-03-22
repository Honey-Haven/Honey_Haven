extends Node

@export var vn_theme: Resource
@export var actor_manager_path: NodePath = "ActorManager"
@export var logic_path: NodePath = "VNLogic"

@onready var actor_manager: Node = get_node(actor_manager_path)
@onready var logic: Node = get_node(logic_path)

func _ready() -> void:
	print("VNController ready. vn_theme=", vn_theme)
	SignalBus.minigame_start.connect(_on_minigame_start)
	SignalBus.minigame_end.connect(_on_minigame_end)
	SignalBus.script_finished.connect(_on_script_finished)
	_propagate_theme()
	_register_actors()
	logic.load_script(EXAMPLE_SCRIPT)
	# Wait two frames: one for all _ready() to finish,
	# one for DialogueUI's pre-render await to complete
	await get_tree().process_frame
	await get_tree().process_frame
	logic.start()

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
			"neutral": preload("res://actors/marty/marty_normal.jpg"),
			"happy":   preload("res://actors/marty/marty_happy.jpg"),
			"sad":     preload("res://actors/marty/marty_sad.jpg"),
		}
	})    

	actor_manager.register_actor({
		"id": "Matthew",
		"scale": 1.0,
		"expressions": {
			"neutral": preload("res://actors/matthew/matthew_normal.jpg"),
			"happy":   preload("res://actors/matthew/matthew_happy.jpg"),
		}
	})    

func _on_minigame_start(minigame_id: String, data: Dictionary) -> void:
	var scene_path := "res://minigames/%s/%s.tscn" % [minigame_id, minigame_id]
	if ResourceLoader.exists(scene_path):
		var inst: Node = (load(scene_path) as PackedScene).instantiate()
		if inst.has_method("setup"):
			inst.setup(data)
		get_tree().root.add_child(inst)
		get_tree().current_scene.visible = false
	else:
		push_warning("Minigame not found: " + scene_path)
		SignalBus.minigame_end.emit({})

func _on_minigame_end(_result: Dictionary) -> void:
	get_tree().current_scene.visible = true

func _on_script_finished() -> void:
	print("Script finished!")

# ================================================================
#  EXAMPLE SCRIPT
# ================================================================
const EXAMPLE_SCRIPT: Array = [
	# ── Scene 1: Morning ─────────────────────────────────────
	{"type": "dialogue", "speaker": "", "text": "Regretfully, you wake up."},
	{"type": "dialogue", "speaker": "", "text": "It took a long time to go to bed last night, and even then you never really slept."},
	{"type": "dialogue", "speaker": "", "text": "But duty calls, and the mail doesn't wait for anybody. Time to get up."},
	{"type": "dialogue", "speaker": "", "text": "The tea is hot, smells sweet, and tastes terrible.", "textbox_effect": "flash"},
	{"type": "dialogue", "speaker": "", "text": "But it clears your head, at least."},
	
	# Marty will auto-assign to the first slot (Left)
	{"type": "appear", "actor_id": "Marty",   "expression": "neutral", "position": ""},
	
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "What's in this stuff?"},
	{"type": "dialogue", "speaker": "",       "text": "The tea doesn't respond."},
	{"type": "dialogue", "speaker": "",       "text": "Well, you'll be ready for your doctor's appointment later today."},
	{"type": "dialogue", "speaker": "",       "text": "You pick up the mail. There is a letter for Matthew, Ms. Buttons, Peanut, and Mr. Scotch."},
	
	# Matthew will auto-assign to the second slot (Right)
	{"type": "appear", "actor_id": "Matthew", "expression": "happy",  "position": ""},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "hop"},
	
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "Hey Marty! What's up?"},

	{"type": "choice", "choices": [
		{"label": "Not much.",            "goto": "matthew_suspicious"},
		{"label": "Nothing important.",   "goto": "matthew_suspicious"}
	]},

	{"type": "label", "name": "matthew_suspicious"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "I mean, come on, there must be something."},

	{"type": "choice", "choices": [
		{"label": "There really isn't.",                                                   "goto": "branch_A"},
		{"label": "Well, to be perfectly honest, I don't think I'm getting enough sleep.",   "goto": "branch_B"}
	]},

	{"type": "label", "name": "branch_A"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "Well, how about I tell you about mine first? I just finished reading Of Mice and Monkeys. Very sad ending. Have you ever read it?"},

	{"type": "choice", "choices": [
		{"label": "In fact, I have.",                                                        "goto": "branch_A1"},
		{"label": "No, I have not.",                                                         "goto": "branch_A2"},
		{"label": "I've never heard of that book before in my life.",                        "goto": "branch_A3"}
	]},

	{"type": "label", "name": "branch_A1"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "How did you like the ending? I wasn't a fan of Lenny dying killing gorillas at the end of the book is a little cliché."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Well, Of Mice and Monkeys is a literary staple of the entire canon of English language literature and clichés have to come from somewhere."},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "Really, it only feels cliché because so many other works have done it before, making the original work feel unoriginal by contrast."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "And so the only way to feel original in the modern day is to take pre-established literary concepts and turn them on their head?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "Not necessarily. Once something has been parodied and satirized enough it once again becomes subversive to play it straight."},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "bounce"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "Interesting."},
	{"type": "jump", "label": "branch_A4"},

	{"type": "label", "name": "branch_A2"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "hop"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "Oh, you haven't? It's really good! I feel like classic literature is a bit of a gamble sometimes, but I really liked it."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Now, what's up with you?"},
	{"type": "jump", "label": "branch_A4"},

	{"type": "label", "name": "branch_A3"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "shake"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "What? You've never heard of one of the great foundations of modern literature?!", "textbox_effect": "shake"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "No, I'm afraid I ha-"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Of Mice and Monkeys was the pinnacle of modernist writing, when the genre had fully rejected the false hope of the romantic era!", "word_shake": true},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "I'm sorry, I'll get to it even-"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "bounce"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "It's fine."},
	{"type": "jump", "label": "branch_A4"},

	{"type": "label", "name": "branch_A4"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Hang on a second, we're getting off-topic! What's wrong?"},
	{"type": "actor_anim", "actor_id": "Marty", "anim": "shake"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "Well, to be perfectly honest, I don't think I'm getting enough sleep."},
	{"type": "jump", "label": "branch_B"},

	{"type": "label", "name": "branch_B"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "What do you mean? You been having trouble keeping your eyes open?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "Well... I'd rather not talk about it."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Are you sure? If you're overworked we should probably deal with it now."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "You know, before it REALLY becomes a problem."},
	{"type": "actor_anim", "actor_id": "Marty", "anim": "shake"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "I... think it already has."},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "hop"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Oh! What's wrong?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "Well... I think I saw something in the sky last night."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Saw... something?"},

	{"type": "choice", "choices": [
		{"label": "...Yeah. Something that wasn't real.",                "goto": "branch_unreal"},
		{"label": "Yeah. The moon looked like a giant eye.",             "goto": "branch_C"}
	]},

	{"type": "label", "name": "branch_unreal"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "...How unreal are we talking?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "I'd really rather not talk about this..."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "No, Marty, look, this is a problem. If you're really seeing things then your insomnia or exhaustion or something is playing tricks on you."},
	{"type": "actor_anim", "actor_id": "Marty", "anim": "shake"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "Or I could be going crazy like... you know... Jonathan F. Smith d-"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "bounce"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "No! You are not going crazy! We're going to fix this.", "textbox_effect": "flash"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "I'll buy you some dinner, you'll go to bed at a reasonable time, and this will all go away."},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "...what did you see?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "Well, the moon looked like a giant eye."},
	{"type": "jump", "label": "branch_C"},

	{"type": "label", "name": "branch_C"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "shake"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "G.O.A.T. above, that IS bad!", "textbox_effect": "shake"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "What did it look like???"},

	{"type": "choice", "choices": [
		{"label": "The whites were black and the iris was the moon. It was enormous, and shone as bright as the light in my room.", "goto": "branch_D1"},
		{"label": "It was big and round, like you'd see on an elephant.",                    "goto": "branch_D2"},
		{"label": "I'll tell you when I'm ready. Later.",                                    "goto": "branch_F"}
	]},

	{"type": "label", "name": "branch_D1"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "shake"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Oh my goodness.", "textbox_effect": "shake"},
	{"type": "jump", "label": "branch_E"},

	{"type": "label", "name": "branch_D2"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Well, that doesn't sound so bad."},
	{"type": "actor_anim", "actor_id": "Marty", "anim": "shake"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "It was looking down directly at me, like the portal to the mind of a dark god.", "word_shake": true},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "shake"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "…Oh.", "textbox_effect": "flash"},
	{"type": "jump", "label": "branch_E"},

	{"type": "label", "name": "branch_E"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "How did you get any sleep?!"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "I didn't."},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "You think it could mean something?"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "What do you mean?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "Well, they say your dreams reflect your subconscious."},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "I guess I'm asking…"},
	{"type": "actor_anim", "actor_id": "Marty", "anim": "pulse"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "sad",     "text": "What do I think is watching us?", "word_shake": true},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "…"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "bounce"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "You WON'T be thinking that tomorrow, once you go to bed on time.", "textbox_effect": "flash"},
	{"type": "jump", "label": "branch_G"},

	{"type": "label", "name": "branch_F"},
	{"type": "dialogue", "speaker": "Matthew","expression": "neutral", "text": "Well, I'm here if you need me."},
	{"type": "jump", "label": "branch_G"},

	{"type": "label", "name": "branch_G"},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "hop"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "Did you get any of that honey tea Dr. Muffins gives out?"},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "Yes, I have some."},
	{"type": "actor_anim", "actor_id": "Matthew", "anim": "spin"},
	{"type": "dialogue", "speaker": "Matthew","expression": "happy",   "text": "I'm sure that'll fix all of your… problems."},
	{"type": "dialogue", "speaker": "Marty",  "expression": "neutral", "text": "I hope it will."},
	{"type": "dialogue", "speaker": "",        "text": "And yet you know it won't."},
]
