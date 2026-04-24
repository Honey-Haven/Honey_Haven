extends Node2D

@onready var bg_a: Sprite2D = $BG_A
@onready var bg_b: Sprite2D = $BG_B

@export var vn_theme: Resource   # VNTheme

var _active: Sprite2D
var _inactive: Sprite2D
var _current_tween: Tween = null   # track so we can kill mid-transition

func _ready() -> void:
	_active = bg_a
	_inactive = bg_b
	bg_a.modulate.a = 0.0
	bg_b.modulate.a = 0.0
	var centre := get_viewport_rect().size / 2.0
	bg_a.position = centre
	bg_b.position = centre
	SignalBus.background_change.connect(_on_background_change)

func _scale_sprite_to_viewport(sprite: Sprite2D) -> void:
	var tex := sprite.texture
	if tex == null or tex.get_width() == 0:
		return
	var vp := get_viewport_rect().size
	var tex_size := Vector2(tex.get_width(), tex.get_height())
	# Cover: scale so the texture fills the viewport completely
	var scale_factor := maxf(vp.x / tex_size.x, vp.y / tex_size.y)
	sprite.scale = Vector2.ONE * scale_factor

func _on_background_change(path: String, transition: String) -> void:
	if path == "":
		return

	var tex: Texture2D = load(path)
	if tex == null:
		push_error("BackgroundManager: could not load '%s'" % path)
		return

	# Kill any in-progress transition and snap to clean state first
	if _current_tween != null:
		_current_tween.kill()
		_current_tween = null
		_swap_buffers()

	var dur: float = vn_theme.transitions.duration if vn_theme and vn_theme.transitions else 0.5

	_inactive.texture = tex
	_scale_sprite_to_viewport(_inactive)
	_inactive.modulate.a = 0.0

	match transition:
		"cut":
			_active.modulate.a = 0.0
			_inactive.modulate.a = 1.0
			_swap_buffers()
		"slide_left":
			_slide_transition(Vector2(-1280, 0), dur)
		"slide_right":
			_slide_transition(Vector2(1280, 0), dur)
		_:
			# "fade" and default
			# Bring the incoming bg on top so it fades in OVER the old one.
			# Only after the new bg is fully opaque do we hide the old one — no dark flash.
			_inactive.z_index = 1
			_active.z_index   = 0
			var tween: Tween = create_tween()
			_current_tween = tween
			tween.tween_property(_inactive, "modulate:a", 1.0, dur)
			tween.tween_callback(_on_fade_done)

func _slide_transition(from_offset: Vector2, dur: float) -> void:
	var centre := get_viewport_rect().size / 2.0
	_inactive.position = centre + from_offset
	_inactive.modulate.a = 1.0
	var tween: Tween = create_tween()
	_current_tween = tween
	tween.tween_property(_inactive, "position", centre, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_active, "position", centre - from_offset, dur).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_fade_done)

func _on_fade_done() -> void:
	_current_tween = null
	_swap_buffers()

func _swap_buffers() -> void:
	var tmp: Sprite2D = _active
	_active = _inactive
	_inactive = tmp
	var centre := get_viewport_rect().size / 2.0
	_active.modulate.a  = 1.0
	_active.z_index     = 0
	_active.position    = centre
	_scale_sprite_to_viewport(_active)
	_inactive.modulate.a = 0.0
	_inactive.z_index    = 0
	_inactive.position   = centre
