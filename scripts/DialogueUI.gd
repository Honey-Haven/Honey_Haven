extends CanvasLayer

@export var vn_theme: Resource
@export var typewriter_sfx: AudioStream   # used for characters (blip)
@export var narrator_sfx: AudioStream     # used for narrator (typewriter tick)
var _type_player: AudioStreamPlayer
var _narrator_type_player: AudioStreamPlayer
var _is_narrator_line: bool = false

# ══════════════════════════════════════════════════════════════
#  DEMON TUNING — adjust these to taste
# ══════════════════════════════════════════════════════════════
const DEMON_LINGER_TIME:    float = 1.2
const DEMON_SCREEN_W:       float = 1280.0
const DEMON_SCREEN_H:       float = 720.0
const DEMON_PADDING:        float = 80.0
const DEMON_FONT_SIZE_MAX:  int   = 120
const DEMON_FONT_SIZE_MIN:  int   = 28
const DEMON_CHAR_DELAY:     float = 0.002
const DEMON_CHAR_SLAM_DUR:  float = 0.1
const DEMON_COLOR: Color = Color(0.88, 0.55, 1.0, 1.0)

# ── BUTTON TUNING
const BTN_FONT_SIZE_DEFAULT: int   = 20
const BTN_FONT_SIZE_MIN:     int   = 11
const BTN_H_PADDING:         float = 24.0
const BTN_V_PADDING:         float = 10.0

# ══════════════════════════════════════════════════════════════
#  NARRATOR OVERLAY TUNING
# ══════════════════════════════════════════════════════════════
const NARRATOR_OVERLAY_ALPHA:    float = 0.3
const NARRATOR_OVERLAY_FADE_DUR: float = 0.25

# ══════════════════════════════════════════════════════════════
#  SCREEN FLASH TUNING
# ══════════════════════════════════════════════════════════════
const SCREEN_FLASH_COLOR:      Color = Color(0, 0, 0, 1)
const SCREEN_FLASH_IN_DUR:     float = 0.05
const SCREEN_FLASH_PEAK_ALPHA: float = 0.75
const SCREEN_FLASH_OUT_DUR:    float = 0.25

# ══════════════════════════════════════════════════════════════
#  STRANGER TEXTBOX TUNING
# ══════════════════════════════════════════════════════════════
const STRANGER_BG_COLOR:    Color = Color(0.05, 0.05, 0.07, 0.92)
const STRANGER_BORDER_COLOR: Color = Color(0.3, 0.6, 0.4, 1.0)
const STRANGER_FONT_COLOR:   Color = Color(0.7, 0.95, 0.75, 1.0)
const STRANGER_NP_BG_COLOR:  Color = Color(0.07, 0.12, 0.08, 1.0)
const STRANGER_NP_BORDER:    Color = Color(0.3, 0.6, 0.4, 1.0)
const STRANGER_NP_FONT:      Color = Color(0.6, 0.9, 0.65, 1.0)

# ══════════════════════════════════════════════════════════════
#  TEXT SIZE EFFECTS  (big / small tags)
# ══════════════════════════════════════════════════════════════
const TEXT_EFFECT_BIG_SCALE:   float = 1.6
const TEXT_EFFECT_SMALL_SCALE: float = 0.65

# ══════════════════════════════════════════════════════════════
#  DAY SPLASH TUNING
# ══════════════════════════════════════════════════════════════
const DAY_SPLASH_HOLD_DUR:   float = 1.8   # seconds the card stays fully visible after typing
const DAY_SPLASH_FADE_IN:    float = 0.6   # fade-in for the background/overlay
const DAY_SPLASH_FADE_OUT:   float = 0.6   # fade-out at the end
const DAY_SPLASH_FONT_SIZE:  int   = 72
const DAY_SPLASH_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

# ══════════════════════════════════════════════════════════════

@onready var textbox_panel:    PanelContainer = $TextboxPanel
@onready var nameplate_panel:  PanelContainer = $NameplatePanel
@onready var name_label:       RichTextLabel  = $NameplatePanel/NameLabel
@onready var dialogue_label:   RichTextLabel  = $TextboxPanel/VBox/DialogueLabel
@onready var choice_container: VBoxContainer  = $ChoiceContainer
@onready var continue_arrow:   Control        = $ContinueArrow
@onready var button_container: HBoxContainer  = $ButtonContainer
@onready var _back_button:     Button         = $ButtonContainer/BackButton

var _typewriter_tween: Tween
var _full_text: String = ""
var _typewriting: bool = false
var _current_packet: Dictionary = {}
var _choice_active: bool = false
var _click_catcher: Button
var _theme_applied: bool = false

# ── Demon overlay state
var _demon_overlay:     ColorRect
var _demon_char_root:   Control
var _demon_growl_tween: Tween
var _demon_linger_tween: Tween
var _demon_active: bool = false

# ── Narrator overlay state
var _narrator_overlay:       ColorRect
var _narrator_overlay_tween: Tween

# ── Screen flash overlay state
var _flash_overlay: ColorRect
var _flash_tween:   Tween

# ── Hands / overlay sprite state
var _overlay_sprite:       TextureRect
var _overlay_sprite_tween: Tween

# ── Stranger SFX player
var _stranger_type_player: AudioStreamPlayer

# ── Demon SFX player
var _demon_type_player: AudioStreamPlayer

# ── Day splash SFX player
var _day_splash_type_player: AudioStreamPlayer

# ── Day splash state
var _day_splash_overlay:  ColorRect
var _day_splash_label:    Label
var _day_splash_active:   bool = false   # true while splash is playing (blocks input)

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
	dialogue_label.bbcode_enabled = true
	_back_button.pressed.connect(_on_back_pressed)
	_back_button.hide()

	# ── Demon overlay ─────────────────────────────────────────
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

	# ── Narrator overlay ──────────────────────────────────────
	_narrator_overlay = ColorRect.new()
	_narrator_overlay.color = Color(0, 0, 0, 0)
	_narrator_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_narrator_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narrator_overlay.z_index = -1
	_narrator_overlay.visible = false
	add_child(_narrator_overlay)

	# ── Screen flash overlay ──────────────────────────────────
	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(SCREEN_FLASH_COLOR.r, SCREEN_FLASH_COLOR.g, SCREEN_FLASH_COLOR.b, 0.0)
	_flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.z_index = 100
	_flash_overlay.visible = false
	add_child(_flash_overlay)

	# ── Hands / overlay sprite ────────────────────────────────
	_overlay_sprite = TextureRect.new()
	_overlay_sprite.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_overlay_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_sprite.z_index      = 10
	_overlay_sprite.modulate.a   = 0.0
	_overlay_sprite.visible      = false
	_overlay_sprite.anchor_left   = 0.0
	_overlay_sprite.anchor_right  = 1.0
	_overlay_sprite.anchor_top    = 0.0
	_overlay_sprite.anchor_bottom = 1.0
	add_child(_overlay_sprite)

	# ── Typewriter audio players ──────────────────────────────
	_type_player = AudioStreamPlayer.new()
	_type_player.name = "TypewriterAudioPlayer"
	add_child(_type_player)
	_type_player.bus = "Master"
	_type_player.volume_db = -6.0
	if typewriter_sfx:
		_type_player.stream = typewriter_sfx
	else:
		print("DEBUG: No character blip sound assigned in Inspector!")

	_narrator_type_player = AudioStreamPlayer.new()
	_narrator_type_player.name = "NarratorAudioPlayer"
	add_child(_narrator_type_player)
	_narrator_type_player.bus = "Master"
	_narrator_type_player.volume_db = -6.0
	if narrator_sfx:
		_narrator_type_player.stream = narrator_sfx
	else:
		print("DEBUG: No narrator typewriter sound assigned in Inspector!")

	_stranger_type_player = AudioStreamPlayer.new()
	_stranger_type_player.name = "StrangerAudioPlayer"
	add_child(_stranger_type_player)
	_stranger_type_player.bus = "Master"
	_stranger_type_player.volume_db = -6.0

	_demon_type_player = AudioStreamPlayer.new()
	_demon_type_player.name = "DemonAudioPlayer"
	add_child(_demon_type_player)
	_demon_type_player.bus = "Master"
	_demon_type_player.volume_db = -6.0

	_day_splash_type_player = AudioStreamPlayer.new()
	_day_splash_type_player.name = "DaySplashAudioPlayer"
	add_child(_day_splash_type_player)
	_day_splash_type_player.bus = "Master"
	_day_splash_type_player.volume_db = -6.0

	# ── Day splash overlay ────────────────────────────────────
	# z_index 200 — sits above absolutely everything.
	# mouse_filter STOP so clicks during the splash go nowhere.
	_day_splash_overlay = ColorRect.new()
	_day_splash_overlay.color = Color(0, 0, 0, 1)
	_day_splash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day_splash_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_day_splash_overlay.z_index = 200
	_day_splash_overlay.visible = true
	add_child(_day_splash_overlay)

	_day_splash_label = Label.new()
	_day_splash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_splash_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_day_splash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day_splash_label.add_theme_font_size_override("font_size", DAY_SPLASH_FONT_SIZE)
	_day_splash_label.add_theme_color_override("font_color", DAY_SPLASH_TEXT_COLOR)
	_day_splash_label.modulate.a = 0.0
	_day_splash_label.visible    = false
	_day_splash_overlay.add_child(_day_splash_label)

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

func _st() -> Resource:
	# Returns the VNThemeStranger sub-resource (t.stranger), or null.
	var t := _get_theme()
	return t.get("stranger") if t else null

func _ds() -> Resource:
	# Returns the VNThemeDaySplash sub-resource (t.day_splash), or null.
	var t := _get_theme()
	return t.get("day_splash") if t else null

func _apply_theme() -> void:
	if _theme_applied:
		return
	var t  := _get_theme()
	var tb := _tb()
	var np := _np()
	print("_apply_theme: tb=", tb, " np=", np)

	if not tb and not np:
		push_warning("DialogueUI: sub-themes are null — check my_theme.tres has sub-resources assigned")
		return
	_theme_applied = true

	var tbs := StyleBoxFlat.new()
	tbs.bg_color     = tb.bg_color     if tb else Color(0.05, 0.05, 0.1, 0.88)
	tbs.border_color = tb.border_color if tb else Color(0.5, 0.7, 1.0, 1.0)
	tbs.set_border_width_all(tb.border_width if tb else 2)
	tbs.set_corner_radius_all(tb.corner_radius  if tb else 12)
	tbs.content_margin_left   = tb.padding.x if tb else 20
	tbs.content_margin_top    = tb.padding.y if tb else 12
	tbs.content_margin_right  = tb.padding.z if tb else 20
	tbs.content_margin_bottom = tb.padding.w if tb else 12
	textbox_panel.add_theme_stylebox_override("panel", tbs)

	var f_size = tb.font_size if tb else 22
	dialogue_label.add_theme_font_size_override("normal_font_size",       f_size)
	dialogue_label.add_theme_font_size_override("italics_font_size",      f_size)
	dialogue_label.add_theme_font_size_override("bold_font_size",         f_size)
	dialogue_label.add_theme_font_size_override("bold_italics_font_size", f_size)
	dialogue_label.add_theme_color_override("default_color", tb.font_color if tb else Color.WHITE)
	if tb and tb.get("font") and tb.font:
		dialogue_label.add_theme_font_override("normal_font",       tb.font)
		dialogue_label.add_theme_font_override("italics_font",      tb.font)
		dialogue_label.add_theme_font_override("bold_font",         tb.font)
		dialogue_label.add_theme_font_override("bold_italics_font", tb.font)

	var nps := StyleBoxFlat.new()
	nps.bg_color     = np.bg_color     if np else Color(0.1, 0.1, 0.25, 1.0)
	nps.border_color = np.border_color if np else Color(0.5, 0.7, 1.0, 1.0)
	nps.set_border_width_all(np.border_width if np else 2)
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
	print("Theme applied. textbox bg=", tbs.bg_color)

# ══════════════════════════════════════════════════════════════
#  INPUT
# ══════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if _day_splash_active:
		return
	var handled := false
	match (event as InputEventKey).keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT:
			if not _demon_active:
				_handle_advance()
				handled = true
		KEY_LEFT:
			if not _demon_active:
				_on_back_pressed()
				handled = true
	if handled:
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _handle_advance() -> void:
	# Day splash is unskippable
	if _day_splash_active or _choice_active or _demon_active:
		return
	if _typewriting:
		_finish_typewriter_instant()
	else:
		SignalBus.dialogue_line_finished.emit()

func _on_back_pressed() -> void:
	if _demon_active or _day_splash_active:
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
		_back_button.visible = is_visible and not _demon_active and not _day_splash_active

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

	var is_stranger: bool = packet.get("is_stranger", false) or speaker.to_lower() == "stranger"

	if speaker == "":
		nameplate_panel.hide()
		_set_textbox_narrator_style()
		_show_narrator_overlay()
	elif is_stranger:
		name_label.text = speaker
		nameplate_panel.show()
		_set_textbox_stranger_style()
		_hide_narrator_overlay()
		_play_stranger_sfx_if_needed()
	else:
		name_label.text = speaker
		nameplate_panel.show()
		_set_textbox_normal_style()
		_hide_narrator_overlay()

	var tb_effect: String  = packet.get("textbox_effect", "")
	if tb_effect != "":
		_play_textbox_effect(tb_effect)

	var is_narrator: bool  = (speaker == "")
	var text_effect: String = packet.get("text_effect", "")
	var char_effect: String = packet.get("char_effect", "")
	_start_typewriter(packet.get("text", ""), packet.get("word_shake", false), is_narrator, text_effect, char_effect)
	_back_button.show()

# ══════════════════════════════════════════════════════════════
#  NARRATOR OVERLAY
# ══════════════════════════════════════════════════════════════
func _show_narrator_overlay() -> void:
	if _narrator_overlay_tween:
		_narrator_overlay_tween.kill()
	_narrator_overlay.visible = true
	_narrator_overlay_tween = create_tween()
	_narrator_overlay_tween.tween_property(
		_narrator_overlay, "color",
		Color(0, 0, 0, NARRATOR_OVERLAY_ALPHA),
		NARRATOR_OVERLAY_FADE_DUR
	)

func _hide_narrator_overlay() -> void:
	if not _narrator_overlay.visible:
		return
	if _narrator_overlay_tween:
		_narrator_overlay_tween.kill()
	_narrator_overlay_tween = create_tween()
	_narrator_overlay_tween.tween_property(
		_narrator_overlay, "color",
		Color(0, 0, 0, 0),
		NARRATOR_OVERLAY_FADE_DUR
	)
	_narrator_overlay_tween.tween_callback(func(): _narrator_overlay.visible = false)

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

	for child in _demon_char_root.get_children():
		child.queue_free()
	if _demon_growl_tween:
		_demon_growl_tween.kill()
		_demon_growl_tween = null

	# Set up demon SFX from theme.
	var tb := _tb()
	if tb and tb.get("demon_typewriter_sfx") and tb.demon_typewriter_sfx:
		_demon_type_player.stream    = tb.demon_typewriter_sfx
		_demon_type_player.volume_db = tb.demon_typewriter_volume_db if tb.get("demon_typewriter_volume_db") else -6.0

	var text: String = packet.get("text", "")
	_demon_growl_animate(text)


func _find_demon_font_size(text: String) -> int:
	var tb := _tb()
	var font: Font = tb.demon_font if (tb and tb.get("demon_font") and tb.demon_font) else ThemeDB.fallback_font

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
	var words: Array = text.split(" ")
	var line_h: float  = font.get_height(size)
	var space_w: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var total_h: float = line_h
	var cur_w: float   = 0.0
	var first_on_line: bool = true

	for word in words:
		if word == "":
			continue
		var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if first_on_line:
			cur_w = w
			first_on_line = false
		elif cur_w + space_w + w <= max_w:
			cur_w += space_w + w
		else:
			total_h += line_h
			cur_w = w
			if total_h > max_h:
				return false
	return total_h <= max_h


func _demon_growl_animate(text: String) -> void:
	var tb := _tb()
	var font: Font = tb.demon_font if (tb and tb.get("demon_font") and tb.demon_font) else ThemeDB.fallback_font
	var font_size: int = _find_demon_font_size(text)
	var color: Color = tb.demon_font_color if (tb and tb.get("demon_font_color")) else DEMON_COLOR

	var max_w: float   = DEMON_SCREEN_W - DEMON_PADDING * 2
	var line_h: float  = font.get_height(font_size)
	var space_w: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var lines_chars:  Array = []
	var lines_widths: Array = []
	var cur_line_chars: Array = []
	var cur_line_w: float = 0.0

	for wi in text.split(" ").size():
		var word: String = text.split(" ")[wi]
		if word == "":
			continue
		var word_w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var gap: float    = space_w if cur_line_chars.size() > 0 else 0.0

		if cur_line_chars.size() > 0 and cur_line_w + gap + word_w > max_w:
			lines_chars.append(cur_line_chars.duplicate())
			lines_widths.append(cur_line_w)
			cur_line_chars = []
			cur_line_w = 0.0
			gap = 0.0

		if gap > 0.0:
			for _s in " ":
				cur_line_chars.append({"char": " ", "x": cur_line_w})
				cur_line_w += space_w

		for ci in word.length():
			var ch: String  = word[ci]
			var ch_w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			cur_line_chars.append({"char": ch, "x": cur_line_w})
			cur_line_w += ch_w

	if cur_line_chars.size() > 0:
		lines_chars.append(cur_line_chars.duplicate())
		lines_widths.append(cur_line_w)

	var total_h: float = lines_chars.size() * line_h
	var start_y: float = (DEMON_SCREEN_H - total_h) * 0.5
	var char_labels: Array = []

	for li in lines_chars.size():
		var line_x_start: float = (DEMON_SCREEN_W - lines_widths[li]) * 0.5
		var line_y: float = start_y + li * line_h
		for entry in lines_chars[li]:
			if entry["char"] == " ":
				continue
			var lbl := Label.new()
			lbl.text = entry["char"]
			lbl.add_theme_font_size_override("font_size", font_size)
			lbl.add_theme_color_override("font_color", color)
			if tb and tb.get("demon_font") and tb.demon_font:
				lbl.add_theme_font_override("font", tb.demon_font)
			lbl.position     = Vector2(line_x_start + entry["x"], line_y)
			lbl.modulate.a   = 0.0
			lbl.pivot_offset = Vector2(lbl.size.x * 0.5, lbl.size.y * 0.5)
			_demon_char_root.add_child(lbl)
			char_labels.append(lbl)

	_demon_growl_tween = create_tween()
	for i in char_labels.size():
		var lbl: Label   = char_labels[i]
		var delay: float = i * DEMON_CHAR_DELAY
		var jitter: Vector2 = Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		var base_pos: Vector2 = lbl.position
		var slam_pos: Vector2 = base_pos + Vector2(0, -30)
		_demon_growl_tween.tween_callback(
			func():
				lbl.position = slam_pos + jitter
				lbl.modulate.a = 1.0
				lbl.scale = Vector2(1.6, 1.6)
				if _demon_type_player and _demon_type_player.stream:
					_demon_type_player.play()
				var t := lbl.create_tween()
				t.set_parallel(true)
				t.tween_property(lbl, "position", base_pos, DEMON_CHAR_SLAM_DUR)\
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				t.tween_property(lbl, "scale", Vector2(1.0, 1.0), DEMON_CHAR_SLAM_DUR * 1.3)\
					.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		).set_delay(delay)

	var total_growl_time: float = (char_labels.size() - 1) * DEMON_CHAR_DELAY + DEMON_CHAR_SLAM_DUR * 1.3
	_demon_growl_tween.tween_callback(_on_demon_growl_done).set_delay(total_growl_time)


func _on_demon_growl_done() -> void:
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
	s.bg_color     = tb.bg_color     if tb else Color(0.05, 0.05, 0.1, 0.88)
	s.border_color = tb.border_color if tb else Color(0.5, 0.7, 1.0, 1.0)
	s.set_border_width_all(  tb.border_width  if tb else 2)
	s.set_corner_radius_all( tb.corner_radius if tb else 12)
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
	nps.set_border_width_all(  np.border_width  if np else 2)
	nps.set_corner_radius_all( np.corner_radius if np else 8)
	nps.content_margin_left   = np.padding.x if np else 14
	nps.content_margin_top    = np.padding.y if np else 4
	nps.content_margin_right  = np.padding.z if np else 14
	nps.content_margin_bottom = np.padding.w if np else 4
	nameplate_panel.add_theme_stylebox_override("panel", nps)
	name_label.add_theme_color_override("default_color", np.font_color if np else Color(0.8, 0.9, 1.0))
	# Nameplate font matches the textbox font so they read as the same "voice".
	if tb and tb.get("font") and tb.font:
		name_label.add_theme_font_override("normal_font", tb.font)
	else:
		name_label.remove_theme_font_override("normal_font")

func _set_textbox_narrator_style() -> void:
	var tb := _tb()
	var s := StyleBoxFlat.new()
	s.bg_color     = tb.narrator_bg_color     if tb else Color(0.041, 0.003, 0.005, 0.88)
	s.border_color = tb.narrator_border_color if tb else Color(0.183, 0.089, 0.102, 1.0)
	s.set_border_width_all(  tb.border_width  if tb else 2)
	s.set_corner_radius_all( tb.corner_radius if tb else 12)
	s.content_margin_left   = tb.padding.x if tb else 20
	s.content_margin_top    = tb.padding.y if tb else 12
	s.content_margin_right  = tb.padding.z if tb else 20
	s.content_margin_bottom = tb.padding.w if tb else 12
	textbox_panel.add_theme_stylebox_override("panel", s)
	dialogue_label.add_theme_color_override("default_color", tb.narrator_font_color if tb else Color(0.75, 0.495, 0.546, 1.0))
	# Apply narrator font — falls back to main textbox font.
	var n_font: Font = null
	if tb and tb.get("narrator_font") and tb.narrator_font:
		n_font = tb.narrator_font
	elif tb and tb.get("font") and tb.font:
		n_font = tb.font
	if n_font:
		dialogue_label.add_theme_font_override("normal_font",       n_font)
		dialogue_label.add_theme_font_override("italics_font",      n_font)
		dialogue_label.add_theme_font_override("bold_font",         n_font)
		dialogue_label.add_theme_font_override("bold_italics_font", n_font)
	else:
		dialogue_label.remove_theme_font_override("normal_font")
	var n_size: int = 0
	if tb and tb.get("narrator_font_size") and tb.narrator_font_size > 0:
		n_size = tb.narrator_font_size
	elif tb and tb.font_size > 0:
		n_size = tb.font_size
	if n_size > 0:
		dialogue_label.add_theme_font_size_override("normal_font_size",       n_size)
		dialogue_label.add_theme_font_size_override("italics_font_size",      n_size)
		dialogue_label.add_theme_font_size_override("bold_font_size",         n_size)
		dialogue_label.add_theme_font_size_override("bold_italics_font_size", n_size)

func _set_textbox_stranger_style() -> void:
	var tb := _tb()
	var np := _np()
	var st := _st()  # VNThemeStranger sub-resource
	var s := StyleBoxFlat.new()
	s.bg_color     = st.bg_color     if st else STRANGER_BG_COLOR
	s.border_color = st.border_color if st else STRANGER_BORDER_COLOR
	s.set_border_width_all(  tb.border_width  if tb else 2)
	s.set_corner_radius_all( tb.corner_radius if tb else 12)
	s.content_margin_left   = tb.padding.x if tb else 20
	s.content_margin_top    = tb.padding.y if tb else 12
	s.content_margin_right  = tb.padding.z if tb else 20
	s.content_margin_bottom = tb.padding.w if tb else 12
	textbox_panel.add_theme_stylebox_override("panel", s)

	var fc: Color = st.font_color if st else STRANGER_FONT_COLOR
	dialogue_label.add_theme_color_override("default_color", fc)

	# Apply stranger font (falls back to main textbox font, then no override).
	var st_font: Font = null
	if st and st.get("font") and st.font:
		st_font = st.font
	elif tb and tb.get("font") and tb.font:
		st_font = tb.font
	if st_font:
		dialogue_label.add_theme_font_override("normal_font",       st_font)
		dialogue_label.add_theme_font_override("italics_font",      st_font)
		dialogue_label.add_theme_font_override("bold_font",         st_font)
		dialogue_label.add_theme_font_override("bold_italics_font", st_font)
	else:
		dialogue_label.remove_theme_font_override("normal_font")

	# Apply stranger font size (falls back to main textbox size).
	var st_size: int
	if st and st.get("font_size") and st.font_size > 0:
		st_size = st.font_size
	elif tb and tb.font_size > 0:
		st_size = tb.font_size
	else:
		st_size = 22
	dialogue_label.add_theme_font_size_override("normal_font_size",       st_size)
	dialogue_label.add_theme_font_size_override("italics_font_size",      st_size)
	dialogue_label.add_theme_font_size_override("bold_font_size",         st_size)
	dialogue_label.add_theme_font_size_override("bold_italics_font_size", st_size)

	# Nameplate panel style.
	var nps := StyleBoxFlat.new()
	nps.bg_color     = st.np_bg_color     if st else STRANGER_NP_BG_COLOR
	nps.border_color = st.np_border_color if st else STRANGER_NP_BORDER
	nps.set_border_width_all(  np.border_width  if np else 2)
	nps.set_corner_radius_all( np.corner_radius if np else 8)
	nps.content_margin_left   = np.padding.x if np else 14
	nps.content_margin_top    = np.padding.y if np else 4
	nps.content_margin_right  = np.padding.z if np else 14
	nps.content_margin_bottom = np.padding.w if np else 4
	nameplate_panel.add_theme_stylebox_override("panel", nps)

	var nfc: Color = st.np_font_color if st else STRANGER_NP_FONT
	name_label.add_theme_color_override("default_color", nfc)

	# Apply stranger font to the nameplate name label too.
	if st_font:
		name_label.add_theme_font_override("normal_font", st_font)
	else:
		name_label.remove_theme_font_override("normal_font")
	# Nameplate font size: use stranger np_font_size if available, else nameplate default.
	var np_st_size: int = 0
	if st and st.get("np_font_size") and st.np_font_size > 0:
		np_st_size = st.np_font_size
	elif np and np.font_size > 0:
		np_st_size = np.font_size
	if np_st_size > 0:
		name_label.add_theme_font_size_override("normal_font_size", np_st_size)

func _play_stranger_sfx_if_needed() -> void:
	if not _stranger_type_player:
		return
	var st := _st()
	# Priority 1: AudioStream assigned directly on the VNThemeStranger resource.
	if st and st.get("typewriter_sfx") and st.typewriter_sfx:
		_stranger_type_player.stream    = st.typewriter_sfx
		_stranger_type_player.volume_db = st.typewriter_volume_db if st.get("typewriter_volume_db") else -6.0
		return
	# Priority 2: Path registered via TwineParser.register_stranger_sfx().
	var path: String = TwineParser.STRANGER_SFX_PATH
	if path != "" and ResourceLoader.exists(path):
		if not _stranger_type_player.stream:
			_stranger_type_player.stream = load(path)

# ══════════════════════════════════════════════════════════════
#  TYPEWRITER
# ══════════════════════════════════════════════════════════════
static func _to_bbcode(text: String) -> String:
	var result: String = text
	var re_bold2 := RegEx.new()
	re_bold2.compile("\\*\\*(.+?)\\*\\*")
	result = re_bold2.sub(result, "[b]$1[/b]", true)
	var re_bold1 := RegEx.new()
	re_bold1.compile("\\*([^*]+?)\\*")
	result = re_bold1.sub(result, "[b]$1[/b]", true)
	var re_italic := RegEx.new()
	re_italic.compile("//(.+?)//")
	result = re_italic.sub(result, "[i]$1[/i]", true)
	var re_ul := RegEx.new()
	re_ul.compile("__(.+?)__")
	result = re_ul.sub(result, "[u]$1[/u]", true)
	return result

func _start_typewriter(text: String, word_shake: bool, is_narrator: bool = false, text_effect: String = "", char_effect: String = "") -> void:
	dialogue_label.bbcode_enabled = true
	_is_narrator_line = is_narrator
	var bbtext: String = _to_bbcode(text)

	if is_narrator:
		bbtext = "[i]%s[/i]" % bbtext

	var tb := _tb()
	var base_font_size: int = tb.font_size if tb else 22
	if text_effect == "big":
		bbtext = "[font_size=%d]%s[/font_size]" % [int(base_font_size * TEXT_EFFECT_BIG_SCALE) - 10, bbtext]
	elif text_effect == "small":
		bbtext = "[font_size=%d]%s[/font_size]" % [17, bbtext]

	if char_effect == "quiver":
		bbtext = "[shake rate=25 level=4]%s[/shake]" % bbtext

	_full_text = bbtext
	_typewriting = true

	if _typewriter_tween:
		_typewriter_tween.kill()

	dialogue_label.text = "[shake rate=20 level=3]%s[/shake]" % bbtext if word_shake else bbtext
	dialogue_label.visible_characters = 0

	var tw_res := _tw()
	var speed: float = tw_res.speed if tw_res else 0.04
	var punct: float = tw_res.punctuation_pause if tw_res else 0.15

	_typewriter_tween = create_tween()
	for i in text.length():
		var ch: String = text[i]
		var d: float = speed + (punct if ch in [".", ",", "!", "?", "…", ";"] else 0.0)
		_typewriter_tween.tween_callback(_reveal_char.bind(i + 1)).set_delay(d)
	_typewriter_tween.tween_callback(_on_typewriter_done)

func _reveal_char(visible_count: int, _is_last: bool = false) -> void:
	dialogue_label.visible_characters = visible_count
	if visible_count > 0 and visible_count <= _full_text.length():
		var c: String = _full_text[visible_count - 1]
		if c != " " and c != "\n" and c != "[" and c != "]":
			if _is_narrator_line:
				if _narrator_type_player and narrator_sfx:
					_narrator_type_player.play()
			elif _current_packet.get("is_stranger", false) or _current_packet.get("speaker", "").to_lower() == "stranger":
				if _stranger_type_player and _stranger_type_player.stream:
					_stranger_type_player.play()
			else:
				if _type_player and typewriter_sfx:
					_type_player.play()

func _on_typewriter_done() -> void:
	_typewriting = false
	dialogue_label.visible_characters = -1
	continue_arrow.show()

func _finish_typewriter_instant() -> void:
	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriting = false
	dialogue_label.visible_characters = -1
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
		btn.focus_mode   = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.custom_minimum_size = ch_res.button_min_size if ch_res else Vector2(420, 52)
		_style_btn(btn, ch_res)
		_fit_btn_font_size(btn, choices[i].get("label", "???"), ch_res)
		choice_container.add_child(btn)
		btn.pressed.connect(func(): _on_choice_pressed(idx))
	choice_container.show()

func _fit_btn_font_size(btn: Button, text: String, ch: Resource) -> void:
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

	var avail_w: float = btn.custom_minimum_size.x - BTN_H_PADDING * 2
	var avail_h: float = btn.custom_minimum_size.y - BTN_V_PADDING * 2
	var size: int = base_size
	while size >= BTN_FONT_SIZE_MIN:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= avail_w \
		and font.get_height(size) <= avail_h:
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
			tw.tween_property(textbox_panel, "modulate", Color(2,2,2,1),       dur * 0.15).set_ease(Tween.EASE_OUT)
			tw.tween_property(textbox_panel, "modulate", Color(1.4,1.4,1.4,1), dur * 0.2)
			tw.tween_property(textbox_panel, "modulate", Color.WHITE,           dur * 0.65).set_ease(Tween.EASE_IN)
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

# ══════════════════════════════════════════════════════════════
#  SCREEN FLASH
# ══════════════════════════════════════════════════════════════
func play_screen_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_overlay.color   = Color(SCREEN_FLASH_COLOR.r, SCREEN_FLASH_COLOR.g, SCREEN_FLASH_COLOR.b, 0.0)
	_flash_overlay.visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_overlay, "color",
		Color(SCREEN_FLASH_COLOR.r, SCREEN_FLASH_COLOR.g, SCREEN_FLASH_COLOR.b, SCREEN_FLASH_PEAK_ALPHA),
		SCREEN_FLASH_IN_DUR)
	_flash_tween.tween_property(_flash_overlay, "color",
		Color(SCREEN_FLASH_COLOR.r, SCREEN_FLASH_COLOR.g, SCREEN_FLASH_COLOR.b, 0.0),
		SCREEN_FLASH_OUT_DUR)
	_flash_tween.tween_callback(func(): _flash_overlay.visible = false)

# ══════════════════════════════════════════════════════════════
#  DAY SPLASH  (full-screen unskippable title card)
# ══════════════════════════════════════════════════════════════
# Called by VNLogic when a day_splash packet is received.
#   day_text — e.g. "Day 3"
#   is_end   — true = end-of-day card (black); false = start-of-day (bg image)
#   bg_path  — resource path to the background image (start-of-day only)
func play_day_splash(day_text: String, is_end: bool, bg_path: String) -> void:
	# Hide all normal UI and mark splash active so input is fully blocked.
	textbox_panel.hide()
	nameplate_panel.hide()
	choice_container.hide()
	continue_arrow.hide()
	_click_catcher.hide()   # mouse clicks can't advance
	_back_button.hide()
	_day_splash_active = true

	# Clear any leftover bg_rect children from a previous splash.
	for ch in _day_splash_overlay.get_children():
		if ch != _day_splash_label:
			ch.queue_free()

	# For day_start: load the background image as a TextureRect behind the label.
	var bg_rect: TextureRect = null
	if not is_end and bg_path != "" and ResourceLoader.exists(bg_path):
		bg_rect = TextureRect.new()
		bg_rect.texture      = load(bg_path)
		bg_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_rect.modulate.a = 0.0
		_day_splash_overlay.add_child(bg_rect)
		_day_splash_overlay.move_child(bg_rect, 0)  # keep below the label

	var ds := _ds()
	_day_splash_label.text    = day_text
	_day_splash_label.add_theme_font_size_override("font_size", ds.font_size if ds else DAY_SPLASH_FONT_SIZE)
	_day_splash_label.add_theme_color_override("font_color", ds.text_color if ds else DAY_SPLASH_TEXT_COLOR)
	if ds and ds.get("font") and ds.font:
		_day_splash_label.add_theme_font_override("font", ds.font)
	_day_splash_label.visible_characters = 0
	_day_splash_label.modulate.a = 0.0
	_day_splash_label.visible    = true
	_day_splash_overlay.visible  = true

	# Run the animation sequence as a coroutine.
	_run_day_splash_sequence.call_deferred(bg_rect, is_end)


func _run_day_splash_sequence(bg_rect: TextureRect, is_end: bool) -> void:
	# ── FADE IN black overlay (and bg image if provided) ─────────────────────
	var ds_run := _ds()
	var _fade_in:     float = ds_run.fade_in       if ds_run else DAY_SPLASH_FADE_IN
	var _fade_out:    float = ds_run.fade_out      if ds_run else DAY_SPLASH_FADE_OUT
	var _hold_dur:    float = ds_run.hold_duration if ds_run else DAY_SPLASH_HOLD_DUR
	var _overlay_col: Color = ds_run.overlay_color if ds_run else Color(0,0,0,1)
	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(_day_splash_overlay, "color", _overlay_col, _fade_in)
	if bg_rect and is_instance_valid(bg_rect):
		tw_in.tween_property(bg_rect, "modulate:a", 1.0, _fade_in)
	await tw_in.finished

	# Guard: if the node was freed mid-sequence (scene change etc.), bail out.
	if not is_instance_valid(self):
		return

	# ── Set up typewriter SFX for the splash ──────────────────────────────────
	# Priority 1: AudioStream on the VNThemeDaySplash sub-resource.
	# Priority 2: Fall back to the main typewriter SFX.
	var splash_player: AudioStreamPlayer = _day_splash_type_player
	if ds_run and ds_run.get("typewriter_sfx") and ds_run.typewriter_sfx:
		splash_player.stream    = ds_run.typewriter_sfx
		splash_player.volume_db = ds_run.typewriter_volume_db if ds_run.get("typewriter_volume_db") else -6.0
	elif typewriter_sfx:
		splash_player.stream    = typewriter_sfx
		splash_player.volume_db = -6.0
	else:
		splash_player = null   # no SFX available — will just be silent

	# ── TYPEWRITE the day text ────────────────────────────────────────────────
	_day_splash_label.modulate.a     = 1.0
	_day_splash_label.visible_characters = 0
	var full_text: String = _day_splash_label.text
	var tw_res := _tw()
	var speed: float = (tw_res.speed if tw_res else 0.04) * 1.5  # slightly slower for drama

	for i in full_text.length():
		await get_tree().create_timer(speed).timeout
		if not is_instance_valid(self):
			return
		_day_splash_label.visible_characters = i + 1
		var ch: String = full_text[i]
		if ch != " " and ch != "\n":
			if splash_player and splash_player.stream:
				splash_player.play()

	_day_splash_label.visible_characters = -1

	# ── HOLD ──────────────────────────────────────────────────────────────────
	await get_tree().create_timer(_hold_dur).timeout
	if not is_instance_valid(self):
		return

	# ── FADE OUT ──────────────────────────────────────────────────────────────
	if not is_end:
		var tw_out := create_tween().set_parallel(true)
		tw_out.tween_property(_day_splash_overlay, "color",      Color(0, 0, 0, 0), _fade_out)
		tw_out.tween_property(_day_splash_label,   "modulate:a", 0.0,               _fade_out)
		if bg_rect and is_instance_valid(bg_rect):
			tw_out.tween_property(bg_rect, "modulate:a", 0.0, _fade_out)
		await tw_out.finished
		if not is_instance_valid(self):
			return
		_day_splash_overlay.visible = false
		_day_splash_label.visible   = false
		if bg_rect and is_instance_valid(bg_rect):
			bg_rect.queue_free()
	else:
		var tw_label := create_tween()
		tw_label.tween_property(_day_splash_label, "modulate:a", 0.0, _fade_out * 0.5)
		await tw_label.finished
		if not is_instance_valid(self):
			return
		_day_splash_label.visible = false
		# Overlay stays solid black — VNController switches to days_menu,
		# which fades in from black for a seamless cut.
	_on_day_splash_done()


func hide_for_no_text() -> void:
	textbox_panel.hide()
	nameplate_panel.hide()
	choice_container.hide()
	continue_arrow.hide()
	_click_catcher.hide()
	_back_button.hide()

func _on_day_splash_done() -> void:
	_day_splash_active = false
	# Do NOT show the textbox here — _show_dialogue will reveal it together with
	# the nameplate when the first actual dialogue packet arrives. Showing it now
	# would leave an empty gray panel visible during the post-splash wait.
	SignalBus.dialogue_line_finished.emit()

# ══════════════════════════════════════════════════════════════
#  OVERLAY SPRITE  (hands etc.)
# ══════════════════════════════════════════════════════════════
func show_overlay_sprite(path: String) -> void:
	if path == "":
		return
	if not ResourceLoader.exists(path):
		push_warning("DialogueUI: overlay sprite not found at '%s'" % path)
		return
	var tex: Texture2D = load(path)
	if not tex:
		return
	_overlay_sprite.texture = tex
	_overlay_sprite.visible = true
	if _overlay_sprite_tween:
		_overlay_sprite_tween.kill()
	_overlay_sprite_tween = create_tween()
	_overlay_sprite_tween.tween_property(_overlay_sprite, "modulate:a", 1.0, 0.2)

func hide_overlay_sprite() -> void:
	if not _overlay_sprite.visible:
		return
	if _overlay_sprite_tween:
		_overlay_sprite_tween.kill()
	_overlay_sprite_tween = create_tween()
	_overlay_sprite_tween.tween_property(_overlay_sprite, "modulate:a", 0.0, 0.2)
	_overlay_sprite_tween.tween_callback(func(): _overlay_sprite.visible = false)
	
