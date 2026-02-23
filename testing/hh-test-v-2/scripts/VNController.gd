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
	pass

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
	{"type": "dialogue", "speaker": "",             "text": "Regretfully, you wake up.",                                                                   "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "It took a long time to go to bed last night, and even then you never really slept.",          "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "But duty calls, and the mail doesn't wait for anybody. Time to get up.",                      "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "The tea is hot, smells sweet, and tastes terrible.",                                          "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "But it clears your head, at least.",                                                          "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "What's in this stuff?",                                                                       "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "The tea doesn't respond.",                                                                    "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "Well, you'll be ready for your doctor's appointment later today.",                            "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "You pick up the mail. There is a letter for Matthew, Ms. Buttons, Peanut, and Mr. Scotch.",   "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "New conversation! This one is with your best friend, the sheep Matthew.",                     "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Hey Marty! What's up?",                                                                       "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},

	{"type": "choice", "choices": [
		{"label": "Not much.",                                                               "goto": "matthew_suspicious"},
		{"label": "Nothing important.",                                                      "goto": "matthew_suspicious"}
	]},

	{"type": "label", "name": "matthew_suspicious"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "I mean, come on, there must be something.",                                                   "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},

	{"type": "choice", "choices": [
		{"label": "There really isn't.",                                                     "goto": "branch_A"},
		{"label": "Well, to be perfectly honest, I don't think I'm getting enough sleep.",   "goto": "branch_B"}
	]},

	{"type": "label", "name": "branch_A"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Well, how about I tell you about mine first? I just finished reading Of Mice and Monkeys. Very sad ending. Have you ever read it?", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},

	{"type": "choice", "choices": [
		{"label": "In fact, I have.",                                                        "goto": "branch_A1"},
		{"label": "No, I have not.",                                                         "goto": "branch_A2"},
		{"label": "I've never heard of that book before in my life.",                        "goto": "branch_A3"}
	]},

	{"type": "label", "name": "branch_A1"},
	{"type": "dialogue", "speaker": "Marty",        "text": "How did you like the ending? I wasn't a fan of Lenny dying killing gorillas at the end of the book is a little cliché.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Well, Of Mice and Monkeys is a literary staple of the entire canon of English language literature and clichés have to come from somewhere.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Really, it only feels cliché because so many other works have done it before, making the original work feel unoriginal by contrast.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "And so the only way to feel original in the modern day is to take pre-established literary concepts and turn them on their head?", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Not necessarily. Once something has been parodied and satirized enough it once again becomes subversive to play it straight.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Interesting.",                                                                                "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_A4"},

	{"type": "label", "name": "branch_A2"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Oh, you haven't? It's really good! I feel like classic literature is a bit of a gamble sometimes, but I really liked it.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Now, what's up with you?",                                                                    "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_A4"},

	{"type": "label", "name": "branch_A3"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "What? You've never heard of one of the great foundations of modern literature?!",             "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "No, I'm afraid I ha-",                                                                        "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Of Mice and Monkeys was the pinnacle of modernist writing, when the genre had fully rejected the false hope of the romantic era!", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "I'm sorry, I'll get to it even-",                                                             "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "It's fine.",                                                                                  "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_A4"},

	{"type": "label", "name": "branch_A4"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Hang on a second, we're getting off-topic! What's wrong?",                                    "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Well, to be perfectly honest, I don't think I'm getting enough sleep.",                       "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_B"},

	{"type": "label", "name": "branch_B"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "What do you mean? You been having trouble keeping your eyes open?",                           "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Well... I'd rather not talk about it.",                                                       "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Are you sure? If you're overworked we should probably deal with it now.",                     "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "You know, before it REALLY becomes a problem.",                                               "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "I... think it already has.",                                                                  "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Oh! What's wrong?",                                                                           "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Well... I think I saw something in the sky last night.",                                      "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Saw... something?",                                                                           "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},

	{"type": "choice", "choices": [
		{"label": "...Yeah. Something that wasn't real.",                                    "goto": "branch_unreal"},
		{"label": "Yeah. The moon looked like a giant eye.",                                 "goto": "branch_C"}
	]},

	{"type": "label", "name": "branch_unreal"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "...How unreal are we talking?",                                                               "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "I'd really rather not talk about this...",                                                    "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "No, Marty, look, this is a problem. If you're really seeing things then your insomnia or exhaustion or something is playing tricks on you.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Or I could be going crazy like... you know... Jonathan F. Smith d-",                          "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "No! You are not going crazy! We're going to fix this.",                                       "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "I'll buy you some dinner, you'll go to bed at a reasonable time, and this will all go away.", "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "...what did you see?",                                                                        "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Well, the moon looked like a giant eye.",                                                     "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_C"},

	{"type": "label", "name": "branch_C"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "G.O.A.T. above, that IS bad!",                                                                "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "What did it look like???",                                                                    "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},

	{"type": "choice", "choices": [
		{"label": "The whites were black and the iris was the moon. It was enormous, and shone as bright as the light in my room.", "goto": "branch_D1"},
		{"label": "It was big and round, like you’d see on an elephant.",                    "goto": "branch_D2"},
		{"label": "I’ll tell you when I’m ready. Later.",                                    "goto": "branch_F"}
	]},

	{"type": "label", "name": "branch_D1"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Oh my goodness.",                                                                             "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_E"},

	{"type": "label", "name": "branch_D2"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Well, that doesn’t sound so bad.",                                                            "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "It was looking down directly at me, like the portal to the mind of a dark god.",              "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "…Oh.",                                                                                        "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_E"},

	{"type": "label", "name": "branch_E"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "How did you get any sleep?!",                                                                 "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "I didn’t.",                                                                                   "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "You think it could mean something?",                                                          "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "What do you mean?",                                                                           "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Well, they say your dreams reflect your subconscious.",                                       "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "I guess I’m asking…",                                                                         "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "What do I think is watching us?",                                                             "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "…",                                                                                           "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "You WON’T be thinking that tomorrow, once you go to bed on time.",                            "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_G"},

	{"type": "label", "name": "branch_F"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Well, I’m here if you need me.",                                                              "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "jump", "label": "branch_G"},

	{"type": "label", "name": "branch_G"},
	{"type": "dialogue", "speaker": "Matthew",      "text": "Did you get any of that honey tea Dr. Muffins gives out?",                                    "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "Yes, I have some.",                                                                           "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Matthew",      "text": "I’m sure that’ll fix all of your… problems.",                                                 "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "Marty",        "text": "I hope it will.",                                                                             "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5},
	{"type": "dialogue", "speaker": "",             "text": "And yet you know it won’t.",                                                                  "textbox_effect": "none", "word_shake": false, "auto_advance": false, "auto_delay": 1.5}
]
