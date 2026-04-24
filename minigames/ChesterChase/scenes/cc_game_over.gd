extends Control

func _ready() -> void:
	_build_ui()
	if MinigameReturn.vn_scene_path != "":
		ResourceLoader.load_threaded_request(MinigameReturn.vn_scene_path)

func _build_ui() -> void:
	# Dark game-over background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 28)
	add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.95, 0.18, 0.12, 1.0))
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Chester caught you..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.80, 0.65, 0.60, 1.0))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var replay_btn   := _make_btn("TRY AGAIN")
	var continue_btn := _make_btn("CONTINUE STORY")
	hbox.add_child(replay_btn)
	hbox.add_child(continue_btn)

	replay_btn.pressed.connect(_on_replay)
	continue_btn.pressed.connect(_on_continue)


func _make_btn(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(210, 54)
	btn.focus_mode = Control.FOCUS_NONE

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.99, 0.93, 0.25, 1.0)
	sn.set_corner_radius_all(27)
	sn.content_margin_left   = 24
	sn.content_margin_right  = 24
	sn.content_margin_top    = 12
	sn.content_margin_bottom = 12

	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(1.0, 1.0, 0.45, 1.0)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color",       Color(0.15, 0.07, 0.00, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.08, 0.04, 0.00, 1.0))
	btn.add_theme_font_size_override("font_size", 21)
	return btn


func _on_replay() -> void:
	get_tree().change_scene_to_file("res://minigames/ChesterChase/scenes/Game.tscn")


func _on_continue() -> void:
	MinigameReturn.returning_from_minigame = true
	var path: String = MinigameReturn.vn_scene_path
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path) as PackedScene)
	else:
		get_tree().change_scene_to_file(path)
