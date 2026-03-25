extends CanvasLayer

@export var vn_theme: Resource

# ══════════════════════════════════════════════════════════════
#  DEMON TUNING — adjust these to taste
# ══════════════════════════════════════════════════════════════
const DEMON_LINGER_TIME:    float = 1.2   # seconds to pause AFTER last char lands before advancing
const DEMON_SCREEN_W:       float = 1280.0
const DEMON_SCREEN_H:       float = 720.0
const DEMON_PADDING:        float = 80.0  # inset from screen edges
const DEMON_FONT_SIZE_MAX:  int   = 120
const DEMON_FONT_SIZE_MIN:  int   = 28
const DEMON_CHAR_DELAY:     float = 0.002 # seconds between each character starting its slam
const DEMON_CHAR_SLAM_DUR:  float = 0.1 # how long each individual character's slam animation takes
const DEMON_COLOR: Color = Color(0.88, 0.55, 1.0, 1.0)

# ── BUTTON TUNING
const BTN_FONT_SIZE_DEFAULT: int   = 20    # starting (max) font size for choice buttons
const BTN_FONT_SIZE_MIN:     int   = 11    # smallest we'll go before giving up
const BTN_H_PADDING:         float = 24.0  # horizontal cushion on each side inside button
const BTN_V_PADDING:         float = 10.0  # vertical cushion top+bottom inside button

# ══════════════════════════════════════════════════════════════

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

# ── Demon overlay state
var _demon_overlay: ColorRect      # solid black full-screen cover
var _demon_char_root: Control      # parent node for per-character labels
var _demon_growl_tween: Tween      # drives the character slam-in sequence
var _demon_linger_tween: Tween     # brief pause after last char before advancing
var _demon_active: bool = false

# ══════════════════════════════════════════════════════════════
#  READY
# ══════════════════════════════════════════════════════════════
func _ready() -> void:
	print("DialogueUI _ready")
	SignalBus.scene_packet_ready.connect(_on_packet)
	SignalBus.dialogue_line_finished.connect(_on_line_finish_signal)
	SignalBus.textbox_effect.connect(_play_textbox_effect)
	SignalBus.back_button_visibility_changed.connect(_on_back_visibility_changed)

	textbox_panel.mouse_filter    = Control.MOUSE_FILTER_STOP
	nameplate_panel.mouse_filter  = Control.MOUSE_FILTER_PASS
	name_label.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	dialogue_label.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	choice_container.mouse_filter = Control.MOUSE_FILTER_PASS
	continue_arrow.mouse_filter   = Control.MOUSE_FILTER_IGNORE

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

	# ── Demon overlay: solid black cover, then a Control to hold char labels ─
	_demon_overlay = ColorRect.new()
	_demon_overlay.color = Color(0, 0, 0, 1)
	_demon_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_demon_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demon_overlay.visible = false
	add_child(_demon_overlay)

	_demon_char_root = Control.new()
	_demon_char_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_demon_char_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demon_char_root.visible = false
	add_child(_demon_char_root)

# ══════════════════════════════════════════════════════════════
#  THEME
# ══════════════════════════════════════════════════════════════
func _get_theme() -> Resource:
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
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT:
			if not _demon_active:
				_handle_advance()
		KEY_LEFT:
			if not _demon_active:
				_on_back_pressed()

func _handle_advance() -> void:
	if _choice_active or _demon_active:
		return
	if _typewriting:
		_finish_typewriter_instant()
	else:
		SignalBus.dialogue_line_finished.emit()

func _on_back_pressed() -> void:
	if _demon_active:
		return
	SignalBus.go_back_requested.emit()

# ══════════════════════════════════════════════════════════════
#  PACKETS
# ══════════════════════════════════════════════════════════════
func _on_packet(packet: Dictionary) -> void:
	_apply_theme()
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
		_back_button.visible = is_visible and not _demon_active

# ══════════════════════════════════════════════════════════════
#  DIALOGUE ROUTING
# ══════════════════════════════════════════════════════════════
func _show_dialogue(packet: Dictionary) -> void:
	var speaker: String = packet.get("speaker", "").strip_edges()

	if speaker.to_lower() == "demon":
		_show_demon_dialogue(packet)
		return

	_dismiss_demon_overlay()

	choice_container.hide()
	textbox_panel.show()
	continue_arrow.hide()
	_click_catcher.show()

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

# ══════════════════════════════════════════════════════════════
#  DEMON DIALOGUE
# ══════════════════════════════════════════════════════════════
func _show_demon_dialogue(packet: Dictionary) -> void:
	textbox_panel.hide()
	nameplate_panel.hide()
	choice_container.hide()
	continue_arrow.hide()
	_click_catcher.hide()
	_back_button.hide()

	_demon_active = true
	_demon_overlay.visible = true
	_demon_char_root.visible = true

	# Clear any leftover char labels from a previous demon line
	for child in _demon_char_root.get_children():
		child.queue_free()
	if _demon_growl_tween:
		_demon_growl_tween.kill()
		_demon_growl_tween = null

	var text: String = packet.get("text", "")
	_demon_growl_animate(text)


# ── Font-size binary search ───────────────────────────────────
# Finds the largest font size where the text fits inside the usable area.
func _find_demon_font_size(text: String) -> int:
	var tb := _tb()
	var font: Font
	if tb and tb.get("demon_font") and tb.demon_font:
		font = tb.demon_font
	else:
		font = ThemeDB.fallback_font

	var max_w: float = DEMON_SCREEN_W - DEMON_PADDING * 2
	var max_h: float = DEMON_SCREEN_H - DEMON_PADDING * 2

	var lo: int = DEMON_FONT_SIZE_MIN
	var hi: int = DEMON_FONT_SIZE_MAX
	var best: int = lo

	while lo <= hi:
		var mid: int = (lo + hi) / 2
		if _text_fits(text, font, mid, max_w, max_h):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best


func _text_fits(text: String, font: Font, size: int, max_w: float, max_h: float) -> bool:
	# Manually word-wrap and measure total height.
	var words: Array = text.split(" ")
	var line_h: float = font.get_height(size)
	var space_w: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var total_h: float = line_h
	var cur_w: float = 0.0
	var first_word_on_line: bool = true

	for word in words:
		if word == "":
			continue
		var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if first_word_on_line:
			cur_w = w
			first_word_on_line = false
		elif cur_w + space_w + w <= max_w:
			cur_w += space_w + w
		else:
			total_h += line_h
			cur_w = w
			if total_h > max_h:
				return false

	return total_h <= max_h


# ── Build per-character label nodes and lay them out ─────────
# Uses a simple manual word-wrap pass to position each char label,
# then animates them in with a growl slam.
func _demon_growl_animate(text: String) -> void:
	var tb := _tb()
	var font: Font
	if tb and tb.get("demon_font") and tb.demon_font:
		font = tb.demon_font
	else:
		font = ThemeDB.fallback_font

	var font_size: int = _find_demon_font_size(text)
	var color: Color = DEMON_COLOR
	if tb and tb.get("demon_font_color"):
		color = tb.demon_font_color

	var max_w: float  = DEMON_SCREEN_W - DEMON_PADDING * 2
	var line_h: float = font.get_height(font_size)
	var space_w: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# ── First pass: measure line widths for centering ─────────
	var lines_chars: Array  = []   # Array of Arrays of {char, x_offset}
	var lines_widths: Array = []

	var current_line_chars: Array = []
	var current_line_w: float = 0.0
	var words_in_line: Array  = []

	# split into words, track per-char positions
	var words: Array = text.split(" ")
	for wi in words.size():
		var word: String = words[wi]
		if word == "":
			continue
		var word_w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var gap: float    = space_w if current_line_chars.size() > 0 else 0.0

		if current_line_chars.size() > 0 and current_line_w + gap + word_w > max_w:
			# Flush current line
			lines_chars.append(current_line_chars.duplicate())
			lines_widths.append(current_line_w)
			current_line_chars = []
			current_line_w = 0.0
			gap = 0.0

		# Append space chars if not first word on line
		if gap > 0.0:
			for _s in " ":
				current_line_chars.append({"char": " ", "x": current_line_w})
				current_line_w += space_w

		# Append each char of the word
		for ci in word.length():
			var ch: String = word[ci]
			var ch_w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			current_line_chars.append({"char": ch, "x": current_line_w})
			current_line_w += ch_w

	if current_line_chars.size() > 0:
		lines_chars.append(current_line_chars.duplicate())
		lines_widths.append(current_line_w)

	# ── Second pass: create Label nodes centred on screen ────
	var total_h: float = lines_chars.size() * line_h
	var start_y: float = (DEMON_SCREEN_H - total_h) * 0.5
	var char_labels: Array = []

	for li in lines_chars.size():
		var line_x_start: float = (DEMON_SCREEN_W - lines_widths[li]) * 0.5
		var line_y: float = start_y + li * line_h

		for entry in lines_chars[li]:
			if entry["char"] == " ":
				continue   # spaces are baked into x offsets; skip visual node

			var lbl := Label.new()
			lbl.text = entry["char"]
			lbl.add_theme_font_size_override("font_size", font_size)
			lbl.add_theme_color_override("font_color", color)
			if tb and tb.get("demon_font") and tb.demon_font:
				lbl.add_theme_font_override("font", tb.demon_font)
			lbl.position = Vector2(line_x_start + entry["x"], line_y)
			# Start invisible, scaled to 0 (slams in via tween)
			lbl.modulate.a = 0.0
			lbl.pivot_offset = Vector2(lbl.size.x * 0.5, lbl.size.y * 0.5)
			_demon_char_root.add_child(lbl)
			char_labels.append(lbl)

	# ── Third pass: animate each character in with growl slam ─
	_demon_growl_tween = create_tween()
	for i in char_labels.size():
		var lbl: Label = char_labels[i]
		var delay: float = i * DEMON_CHAR_DELAY
		var jitter: Vector2 = Vector2(
			randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0)
		)
		var base_pos: Vector2 = lbl.position
		var slam_pos: Vector2 = base_pos + Vector2(0, -30)   # start above

		# Appear + drop from above + overshoot + settle
		_demon_growl_tween.tween_callback(
			func():
				lbl.position = slam_pos + jitter
				lbl.modulate.a = 1.0
				lbl.scale = Vector2(1.6, 1.6)
				var t := lbl.create_tween()
				t.set_parallel(true)
				t.tween_property(lbl, "position", base_pos, DEMON_CHAR_SLAM_DUR)\
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				t.tween_property(lbl, "scale", Vector2(1.0, 1.0), DEMON_CHAR_SLAM_DUR * 1.3)\
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		).set_delay(delay)

	# After last character finishes, linger briefly then auto-advance
	var total_growl_time: float = (char_labels.size() - 1) * DEMON_CHAR_DELAY + DEMON_CHAR_SLAM_DUR * 1.3
	_demon_growl_tween.tween_callback(_on_demon_growl_done).set_delay(total_growl_time)


func _on_demon_growl_done() -> void:
	# Growl finished — linger briefly then advance
	if not _demon_active:
		return
	_demon_linger_tween = create_tween()
	_demon_linger_tween.tween_interval(DEMON_LINGER_TIME)
	_demon_linger_tween.tween_callback(_on_demon_linger_done)

func _on_demon_linger_done() -> void:
	_demon_linger_tween = null
	_dismiss_demon_overlay()
	SignalBus.dialogue_line_finished.emit()


func _dismiss_demon_overlay() -> void:
	if not _demon_active:
		return
	_demon_active = false
	_demon_overlay.visible = false
	_demon_char_root.visible = false
	if _demon_growl_tween:
		_demon_growl_tween.kill()
		_demon_growl_tween = null
	if _demon_linger_tween:
		_demon_linger_tween.kill()
		_demon_linger_tween = null
	for child in _demon_char_root.get_children():
		child.queue_free()
	textbox_panel.show()
	_click_catcher.show()

# ══════════════════════════════════════════════════════════════
#  TEXTBOX STYLE HELPERS
# ══════════════════════════════════════════════════════════════
func _set_textbox_normal_style() -> void:
	var tb := _tb()
	var np := _np()
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
	if tb and tb.get("font") and tb.font:
		dialogue_label.add_theme_font_override("normal_font", tb.font)
	else:
		dialogue_label.remove_theme_font_override("normal_font")
	dialogue_label.add_theme_font_size_override("normal_font_size", tb.font_size if tb else 22)
	var nps := StyleBoxFlat.new()
	nps.bg_color     = np.bg_color     if np else Color(0.1, 0.1, 0.25, 1.0)
	nps.border_color = np.border_color if np else Color(0.5, 0.7, 1.0, 1.0)
	nps.set_border_width_all(  np.border_width   if np else 2)
	nps.set_corner_radius_all( np.corner_radius  if np else 8)
	nps.content_margin_left   = np.padding.x if np else 14
	nps.content_margin_top    = np.padding.y if np else 4
	nps.content_margin_right  = np.padding.z if np else 14
	nps.content_margin_bottom = np.padding.w if np else 4
	nameplate_panel.add_theme_stylebox_override("panel", nps)
	name_label.add_theme_color_override("default_color", np.font_color if np else Color(0.8, 0.9, 1.0))

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
		_fit_btn_font_size(btn, choices[i].get("label", "???"), ch_res)
		choice_container.add_child(btn)
		btn.pressed.connect(func(): _on_choice_pressed(idx))
	choice_container.show()

func _fit_btn_font_size(btn: Button, text: String, ch: Resource) -> void:
	# Find the button font and its default size
	var font: Font
	if ch and ch.get("font") and ch.font:
		font = ch.font
	else:
		font = btn.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font

	var base_size: int = BTN_FONT_SIZE_DEFAULT
	if ch and ch.get("font_size"):
		base_size = ch.font_size

	# Available text area inside button (button min size minus padding)
	var btn_w: float = btn.custom_minimum_size.x
	var btn_h: float = btn.custom_minimum_size.y
	var avail_w: float = btn_w - BTN_H_PADDING * 2
	var avail_h: float = btn_h - BTN_V_PADDING * 2

	# Walk down from base_size until text fits in one line within avail_w and avail_h
	var size: int = base_size
	while size >= BTN_FONT_SIZE_MIN:
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var text_h: float = font.get_height(size)
		if text_w <= avail_w and text_h <= avail_h:
			break
		size -= 1

	btn.add_theme_font_size_override("font_size", size)

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
