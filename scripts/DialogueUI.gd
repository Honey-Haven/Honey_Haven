extends CanvasLayer

@export var vn_theme: Resource

@onready var textbox_panel:    PanelContainer = $TextboxPanel
@onready var nameplate_panel: PanelContainer = $NameplatePanel
@onready var name_label: RichTextLabel       = $NameplatePanel/NameLabel
@onready var dialogue_label:   RichTextLabel  = $TextboxPanel/VBox/DialogueLabel
@onready var choice_container: VBoxContainer  = $ChoiceContainer
@onready var continue_arrow:   Control        = $ContinueArrow
@onready var button_container: HBoxContainer = $ButtonContainer
@onready var _back_button: Button = $ButtonContainer/BackButton

var _typewriter_tween: Tween
var _full_text: String = ""
var _typewriting: bool = false
var _current_packet: Dictionary = {}
var _choice_active: bool = false
var _click_catcher: Button
var _theme_applied: bool = false

# ══════════════════════════════════════════════════════════════
#  READY
# ══════════════════════════════════════════════════════════════
func _ready() -> void:
	print("DialogueUI _ready")
	SignalBus.scene_packet_ready.connect(_on_packet)
	SignalBus.dialogue_line_finished.connect(_on_line_finish_signal)
	SignalBus.textbox_effect.connect(_play_textbox_effect)
	SignalBus.back_button_visibility_changed.connect(_on_back_visibility_changed)

	# Mouse filters
	textbox_panel.mouse_filter    = Control.MOUSE_FILTER_STOP
	nameplate_panel.mouse_filter  = Control.MOUSE_FILTER_PASS
	name_label.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	dialogue_label.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	choice_container.mouse_filter = Control.MOUSE_FILTER_PASS
	continue_arrow.mouse_filter   = Control.MOUSE_FILTER_IGNORE

	# Click catcher over textbox area
	_click_catcher = Button.new()
	_click_catcher.flat = true
	_click_catcher.z_index = -1
	_click_catcher.focus_mode = Control.FOCUS_NONE
	_click_catcher.anchor_left   = 0.0
	_click_catcher.anchor_right  = 1.0
	_click_catcher.anchor_top    = 1.0
	_click_catcher.anchor_bottom = 1.0
	_click_catcher.offset_top    = -210
	_click_catcher.offset_bottom = 0
	_click_catcher.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var empty := StyleBoxEmpty.new()
	for s in ["normal","hover","pressed","focus"]:
		_click_catcher.add_theme_stylebox_override(s, empty)
	add_child(_click_catcher)
	_click_catcher.pressed.connect(_handle_advance)

	textbox_panel.hide()
	choice_container.hide()
	continue_arrow.hide()
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.hide()
# ══════════════════════════════════════════════════════════════
#  THEME 
# ══════════════════════════════════════════════════════════════
func _get_theme() -> Resource:
	# Use exported vn_theme if set, otherwise grab from root node
	if vn_theme:
		return vn_theme
	var root := get_tree().root.get_child(0)
	if root and root.get("vn_theme"):
		vn_theme = root.vn_theme
	return vn_theme

func _tb() -> Resource:
	var t := _get_theme()
	return t.textbox if t else null

func _np() -> Resource:
	var t := _get_theme()
	return t.nameplate if t else null

func _ch() -> Resource:
	var t := _get_theme()
	return t.choices if t else null

func _tw() -> Resource:
	var t := _get_theme()
	return t.typewriter if t else null

func _fx() -> Resource:
	var t := _get_theme()
	return t.effects if t else null

func _apply_theme() -> void:
	if _theme_applied:
		return
	var t := _get_theme()
	print("_get_theme() = ", t)
	if t:
		print("t.textbox = ", t.textbox)
		print("t.nameplate = ", t.nameplate)
	var tb := _tb()
	var np := _np()
	print("tb=", tb, " np=", np)

	if not tb and not np:
		push_warning("DialogueUI: sub-themes are null — check my_theme.tres has sub-resources assigned")
		return
	_theme_applied = true

	# Textbox
	var tbs := StyleBoxFlat.new()
	tbs.bg_color     = tb.bg_color     if tb else Color(0.05, 0.05, 0.1, 0.88)
	tbs.border_color = tb.border_color if tb else Color(0.5, 0.7, 1.0, 1.0)
	tbs.set_border_width_all(tb.border_width    if tb else 2)
	tbs.set_corner_radius_all(tb.corner_radius  if tb else 12)
	tbs.content_margin_left   = tb.padding.x if tb else 20
	tbs.content_margin_top    = tb.padding.y if tb else 12
	tbs.content_margin_right  = tb.padding.z if tb else 20
	tbs.content_margin_bottom = tb.padding.w if tb else 12
	textbox_panel.add_theme_stylebox_override("panel", tbs)
	dialogue_label.add_theme_font_size_override("normal_font_size", tb.font_size if tb else 22)
	dialogue_label.add_theme_color_override("default_color", tb.font_color if tb else Color.WHITE)
	if tb and tb.get("font") and tb.font:
		dialogue_label.add_theme_font_override("normal_font", tb.font)

	# Nameplate
	var nps := StyleBoxFlat.new()
	nps.bg_color     = np.bg_color     if np else Color(0.1, 0.1, 0.25, 1.0)
	nps.border_color = np.border_color if np else Color(0.5, 0.7, 1.0, 1.0)
	nps.set_border_width_all(np.border_width    if np else 2)
	nps.set_corner_radius_all(np.corner_radius  if np else 8)
	nps.content_margin_left   = np.padding.x if np else 14
	nps.content_margin_top    = np.padding.y if np else 4
	nps.content_margin_right  = np.padding.z if np else 14
	nps.content_margin_bottom = np.padding.w if np else 4
	nameplate_panel.add_theme_stylebox_override("panel", nps)
	name_label.add_theme_font_size_override("normal_font_size", np.font_size if np else 20)
	name_label.add_theme_color_override("default_color", np.font_color if np else Color(0.8,0.9,1.0))
	if np and np.get("font") and np.font:
		name_label.add_theme_font_override("normal_font", np.font)

	print("Theme done! textbox bg=", tbs.bg_color)

# ══════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════
func _unhandled_key_input(event: InputEvent) -> void:
	if _choice_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_handle_advance()

func _handle_advance() -> void:
	if _choice_active:
		return
	if _typewriting:
		_finish_typewriter_instant()
	else:
		SignalBus.dialogue_line_finished.emit()

func _on_back_pressed() -> void:
	SignalBus.go_back_requested.emit()
	
# ══════════════════════════════════════════════════════════════
#  PACKETS
# ══════════════════════════════════════════════════════════════
func _on_packet(packet: Dictionary) -> void:
	_apply_theme()   # safe to call repeatedly — guards with _theme_applied
	print("UI packet: ", packet.get("type"), " | ", packet.get("text", ""))
	_current_packet = packet
	match packet.get("type", ""):
		"dialogue":
			_choice_active = false
			_show_dialogue(packet)
		"choice":
			_choice_active = true
			_show_choices(packet)

func _on_back_visibility_changed(is_visible: bool) -> void:
	if _back_button:
		_back_button.visible = is_visible
# ══════════════════════════════════════════════════════════════
#  DIALOGUE
# ══════════════════════════════════════════════════════════════
func _show_dialogue(packet: Dictionary) -> void:
	choice_container.hide()
	textbox_panel.show()
	continue_arrow.hide()
	_click_catcher.show()

	var speaker: String = packet.get("speaker", "").strip_edges()
	if speaker == "":
		nameplate_panel.hide()
		_set_textbox_narrator_style()
	else:
		name_label.text = speaker
		nameplate_panel.show()
		_set_textbox_normal_style()
		
	var effect: String = packet.get("textbox_effect", "none")
	if effect != "none":
		_play_textbox_effect(effect)

	_start_typewriter(packet.get("text", ""), packet.get("word_shake", false))
	_back_button.show()

func _set_textbox_normal_style() -> void:
	var tb := _tb()
	var s := StyleBoxFlat.new()
	s.bg_color              = tb.bg_color     if tb else Color(0.05, 0.05, 0.1, 0.88)
	s.border_color          = tb.border_color if tb else Color(0.5, 0.7, 1.0, 1.0)
	s.set_border_width_all(   tb.border_width  if tb else 2)
	s.set_corner_radius_all(  tb.corner_radius if tb else 12)
	s.content_margin_left   = tb.padding.x if tb else 20
	s.content_margin_top    = tb.padding.y if tb else 12
	s.content_margin_right  = tb.padding.z if tb else 20
	s.content_margin_bottom = tb.padding.w if tb else 12
	textbox_panel.add_theme_stylebox_override("panel", s)
	dialogue_label.add_theme_color_override("default_color", tb.font_color if tb else Color.WHITE)

func _set_textbox_narrator_style() -> void:
	var tb := _tb()
	var s := StyleBoxFlat.new()
	s.bg_color              = tb.narrator_bg_color     if tb else Color(0.041, 0.003, 0.005, 0.88)
	s.border_color          = tb.narrator_border_color if tb else Color(0.183, 0.089, 0.102, 1.0)
	s.set_border_width_all(   tb.border_width           if tb else 2)
	s.set_corner_radius_all(  tb.corner_radius          if tb else 12)
	s.content_margin_left   = tb.padding.x if tb else 20
	s.content_margin_top    = tb.padding.y if tb else 12
	s.content_margin_right  = tb.padding.z if tb else 20
	s.content_margin_bottom = tb.padding.w if tb else 12
	textbox_panel.add_theme_stylebox_override("panel", s)
	dialogue_label.add_theme_color_override("default_color", tb.narrator_font_color if tb else Color(0.75, 0.495, 0.546, 1.0))

# ══════════════════════════════════════════════════════════════
#  TYPEWRITER
# ══════════════════════════════════════════════════════════════
func _start_typewriter(text: String, word_shake: bool) -> void:
	_full_text = text
	_typewriting = true
	dialogue_label.text = ""
	if _typewriter_tween:
		_typewriter_tween.kill()

	var tw_res := _tw()
	var speed: float = tw_res.speed if tw_res else 0.04
	var punct: float = tw_res.punctuation_pause if tw_res else 0.15

	_typewriter_tween = create_tween()
	for i in text.length():
		var ch: String = text[i]
		var d: float = speed + (punct if ch in [".", ",", "!", "?", "…", ";"] else 0.0)
		_typewriter_tween.tween_callback(_reveal_char.bind(i, word_shake)).set_delay(d)
	_typewriter_tween.tween_callback(_on_typewriter_done)

func _reveal_char(index: int, word_shake: bool) -> void:
	var t: String = _full_text.substr(0, index + 1)
	dialogue_label.text = "[shake rate=20 level=3]%s[/shake]" % t if word_shake else t

func _on_typewriter_done() -> void:
	_typewriting = false
	if not _current_packet.get("word_shake", false):
		dialogue_label.text = _full_text
	continue_arrow.show()

func _finish_typewriter_instant() -> void:
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriting = false
	dialogue_label.text = _full_text
	continue_arrow.show()

func _on_line_finish_signal() -> void:
	continue_arrow.hide()

# ══════════════════════════════════════════════════════════════
#  CHOICES
# ══════════════════════════════════════════════════════════════
func _show_choices(packet: Dictionary) -> void:
	textbox_panel.show()
	continue_arrow.hide()
	_click_catcher.hide()

	choice_container.hide()
	for child in choice_container.get_children():
		child.free()

	choice_container.anchor_left   = 0.5
	choice_container.anchor_right  = 0.5
	choice_container.anchor_top    = 0.5
	choice_container.anchor_bottom = 0.5
	choice_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	choice_container.grow_vertical   = Control.GROW_DIRECTION_BOTH
	choice_container.offset_left   = -230
	choice_container.offset_right  =  230
	choice_container.offset_top    = -170
	choice_container.offset_bottom =  170

	var ch_res := _ch()
	var choices: Array = packet.get("choices", [])
	for i in choices.size():
		var idx: int = i
		var btn := Button.new()
		btn.text = choices[i].get("label", "???")
		btn.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.custom_minimum_size = ch_res.button_min_size if ch_res else Vector2(420, 52)
		_style_btn(btn, ch_res)
		choice_container.add_child(btn)
		btn.pressed.connect(func(): _on_choice_pressed(idx))
	choice_container.show()

func _on_choice_pressed(index: int) -> void:
	print("Choice: ", index)
	_choice_active = false
	choice_container.hide()
	_click_catcher.show()
	SignalBus.choice_selected.emit(index)

func _style_btn(btn: Button, ch: Resource) -> void:
	var n := StyleBoxFlat.new()
	var h := StyleBoxFlat.new()
	n.bg_color = ch.bg_color       if ch else Color(0.1, 0.1, 0.3, 0.9)
	h.bg_color = ch.hover_bg_color if ch else Color(0.25, 0.35, 0.65, 1.0)
	n.set_corner_radius_all(ch.corner_radius if ch else 8)
	h.set_corner_radius_all(ch.corner_radius if ch else 8)
	if ch:
		n.border_color = ch.border_color
		h.border_color = ch.border_color
		n.set_border_width_all(ch.border_width)
		h.set_border_width_all(ch.border_width)
		btn.add_theme_color_override("font_color",       ch.font_color)
		btn.add_theme_color_override("font_hover_color", ch.hover_font_color)
		btn.add_theme_font_size_override("font_size",    ch.font_size)
		if ch.get("font") and ch.font:
			btn.add_theme_font_override("font", ch.font)
	else:
		btn.add_theme_color_override("font_color",       Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   n)

# ══════════════════════════════════════════════════════════════
#  EFFECTS
# ══════════════════════════════════════════════════════════════
func _play_textbox_effect(effect: String) -> void:
	var fx := _fx()
	match effect:
		"flash":
			var dur: float = fx.flash_duration if fx else 0.5
			var tw := create_tween()
			tw.tween_property(textbox_panel, "modulate", Color(2,2,2,1), dur * 0.15).set_ease(Tween.EASE_OUT)
			tw.tween_property(textbox_panel, "modulate", Color(1.4,1.4,1.4,1), dur * 0.2)
			tw.tween_property(textbox_panel, "modulate", Color.WHITE,    dur * 0.65).set_ease(Tween.EASE_IN)
		"shake":
			var strength: float = fx.shake_strength if fx else 6.0
			var dur: float      = fx.shake_duration  if fx else 0.4
			var origin := textbox_panel.position
			var tw := create_tween()
			for _i in 12:
				tw.tween_property(textbox_panel, "position",
					origin + Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
					dur / 12.0)
			tw.tween_property(textbox_panel, "position", origin, 0.05)
