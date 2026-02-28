extends Node2D

@onready var bg_a: Sprite2D = $BG_A
@onready var bg_b: Sprite2D = $BG_B

@export var vn_theme: Resource   # VNTheme

var _active: Sprite2D
var _inactive: Sprite2D

func _ready() -> void:
	_active = bg_a
	_inactive = bg_b
	bg_b.modulate.a = 0.0
	SignalBus.background_change.connect(_on_background_change)

func _on_background_change(path: String, transition: String) -> void:
	if path == "":
		return

	var tex: Texture2D = load(path)
	if tex == null:
		push_error("BackgroundManager: could not load '%s'" % path)
		return

	var theme: Resource = vn_theme
	var dur: float = theme.transition_duration if theme else 0.5

	_inactive.texture = tex
	_inactive.modulate.a = 0.0

	match transition:
		"cut":
			_active.texture = tex
			_active.modulate.a = 1.0
		"fade":
			var tween: Tween = create_tween()
			tween.tween_property(_inactive, "modulate:a", 1.0, dur)
			tween.parallel().tween_property(_active, "modulate:a", 0.0, dur)
			tween.tween_callback(_swap_buffers)
		"slide_left":
			_slide_transition(Vector2(-1280, 0), dur)
		"slide_right":
			_slide_transition(Vector2(1280, 0), dur)
		_:
			# Default to fade
			var tween: Tween = create_tween()
			tween.tween_property(_inactive, "modulate:a", 1.0, dur)
			tween.parallel().tween_property(_active, "modulate:a", 0.0, dur)
			tween.tween_callback(_swap_buffers)

func _slide_transition(from_offset: Vector2, dur: float) -> void:
	_inactive.position = from_offset
	_inactive.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(_inactive, "position", Vector2.ZERO, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(_active, "position", -from_offset, dur).set_ease(Tween.EASE_IN)
	tween.tween_callback(_swap_buffers)

func _swap_buffers() -> void:
	var tmp: Sprite2D = _active
	_active = _inactive
	_inactive = tmp
	_active.modulate.a = 1.0
	_active.position = Vector2.ZERO
	_inactive.modulate.a = 0.0
	_inactive.position = Vector2.ZERO
