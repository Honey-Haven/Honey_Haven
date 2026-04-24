extends Control

# ── EDIT THESE TO CHANGE THE INTRO SCREEN CONTENT ────────────────────────────
const TITLE_TEXT := "Chester Chase"

const RULES_TEXT := """Survive for 30 seconds without getting caught!

CONTROLS
   Arrow Keys  —  Move Marty

PICKUPS & HAZARDS
   Cheese       —  Grab it for a speed boost
   Mousetrap    —  Avoid it or you'll be frozen briefly!
   Portals      —  Step to teleport; Chester cannot use these
   Shadow       —  Watch out, he's good at jumping over rocks!

GOAL
   Chester the cat is always chasing you...
   Don't let him catch you!"""
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Full-screen light yellow background
	var bg := ColorRect.new()
	bg.color = Color(1.0, 0.98, 0.87, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centered vertical layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color(0.25, 0.12, 0.02, 1.0))
	vbox.add_child(title)

	# Thin decorative line
	var line := ColorRect.new()
	line.color = Color(0.80, 0.65, 0.20, 0.8)
	line.custom_minimum_size = Vector2(500, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(line)

	# Rules panel
	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(1.0, 1.0, 0.93, 0.75)
	pstyle.set_corner_radius_all(16)
	pstyle.content_margin_left   = 44
	pstyle.content_margin_right  = 44
	pstyle.content_margin_top    = 10
	pstyle.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(panel)

	var rules_label := Label.new()
	rules_label.text = RULES_TEXT
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rules_label.add_theme_font_size_override("font_size", 21)
	rules_label.add_theme_color_override("font_color", Color(0.18, 0.09, 0.01, 1.0))
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules_label.custom_minimum_size = Vector2(640, 0)
	panel.add_child(rules_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# START button
	var start_btn := _make_yellow_button("START")
	start_btn.custom_minimum_size = Vector2(140, 40)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_size_override("font_size", 18)
	start_btn.pressed.connect(_on_start)
	vbox.add_child(start_btn)


func _make_yellow_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.focus_mode = Control.FOCUS_NONE

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.98, 0.85, 0.15, 1.0)
	sn.set_corner_radius_all(18)
	sn.content_margin_left   = 18
	sn.content_margin_right  = 18
	sn.content_margin_top    = 8
	sn.content_margin_bottom = 8

	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(1.0, 0.92, 0.28, 1.0)

	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color",       Color(0.20, 0.10, 0.00, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.12, 0.06, 0.00, 1.0))
	return btn


func _on_start() -> void:
	get_tree().change_scene_to_file("res://minigames/ChesterChase/scenes/Game.tscn")
