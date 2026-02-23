extends Node2D

const POSITIONS: Dictionary = {
	"left":        Vector2(320, 540),
	"center_left": Vector2(540, 540),
	"center":      Vector2(760, 540),
	"center_right":Vector2(980, 540),
	"right":       Vector2(1200, 540),
}

@export var vn_theme: Resource   # VNTheme

# actor_id → { "node": Sprite2D, "expressions": {name:Texture} }
var _actors: Dictionary = {}

# ── Lifecycle ─────────────────────────────────────────────────
func _ready() -> void:
	SignalBus.actor_show.connect(_on_actor_show)
	SignalBus.actor_hide.connect(_on_actor_hide)
	SignalBus.actor_move.connect(_on_actor_move)
	SignalBus.actor_expression.connect(_on_actor_expression)
	SignalBus.actor_animate.connect(_on_actor_animate)

# ── Register actors from script ───────────────────────────────
# Call this before starting the VN to register actor configs.
# actor_cfg = { "id":"aria", "expressions":{ "happy":Texture2D, ... }, "scale": 1.0 }
func register_actor(actor_cfg: Dictionary) -> void:
	var actor_id: String = actor_cfg["id"]
	var sprite: Sprite2D = Sprite2D.new()
	sprite.modulate.a = 0.0
	sprite.scale = Vector2.ONE * actor_cfg.get("scale", 1.0)
	sprite.position = POSITIONS["center"]
	add_child(sprite)

	_actors[actor_id] = {
		"node": sprite,
		"expressions": actor_cfg.get("expressions", {}),
	}

# ── Signal handlers ───────────────────────────────────────────
func _on_actor_show(actor_id: String, expression: String, position: String) -> void:
	if not _actors.has(actor_id):
		push_warning("ActorManager: unknown actor '%s'" % actor_id)
		return
	var data: Dictionary = _actors[actor_id]
	var sprite: Sprite2D = data["node"]

	_set_expression(data, expression)
	sprite.position = POSITIONS.get(position, POSITIONS["center"])

	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.3)

func _on_actor_hide(actor_id: String) -> void:
	if not _actors.has(actor_id):
		return
	var sprite: Sprite2D = _actors[actor_id]["node"]
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)

func _on_actor_move(actor_id: String, position: String, anim: String) -> void:
	if not _actors.has(actor_id):
		return
	var sprite: Sprite2D = _actors[actor_id]["node"]
	var target: Vector2 = POSITIONS.get(position, POSITIONS["center"])
	match anim:
		"slide":
			var tween: Tween = create_tween()
			tween.tween_property(sprite, "position", target, vn_theme.sprite_slide_duration if vn_theme else 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		"hop":
			_hop_to(sprite, target)
		_:
			sprite.position = target

func _on_actor_expression(actor_id: String, expression: String) -> void:
	if not _actors.has(actor_id):
		return
	_set_expression(_actors[actor_id], expression)

func _on_actor_animate(actor_id: String, anim: String) -> void:
	if not _actors.has(actor_id):
		return
	var sprite: Sprite2D = _actors[actor_id]["node"]
	match anim:
		"shake":
			_shake_sprite(sprite)
		"hop":
			_hop_in_place(sprite)
		"bounce":
			_bounce_sprite(sprite)
		"pulse":
			_pulse_sprite(sprite)
		"spin":
			_spin_sprite(sprite)
		_:
			push_warning("ActorManager: unknown anim '%s'" % anim)

# ── Expression swap ───────────────────────────────────────────
func _set_expression(data: Dictionary, expression: String) -> void:
	var exprs: Dictionary = data["expressions"]
	if expression == "" or not exprs.has(expression):
		expression = exprs.keys()[0] if not exprs.is_empty() else ""
	if expression != "" and exprs.has(expression):
		data["node"].texture = exprs[expression]

# ── Movement animations ───────────────────────────────────────
func _hop_to(sprite: Sprite2D, target: Vector2) -> void:
	var theme: Resource = vn_theme
	var hop_h: float = theme.sprite_hop_height if theme else 30.0
	var dur: float = theme.sprite_slide_duration if theme else 0.4
	var mid: Vector2 = sprite.position.lerp(target, 0.5) + Vector2(0, -hop_h)
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position", mid, dur * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", target, dur * 0.5).set_ease(Tween.EASE_IN)

# ── In-place animations ───────────────────────────────────────
func _shake_sprite(sprite: Sprite2D) -> void:
	var theme: Resource = vn_theme
	var strength: float = theme.sprite_shake_strength if theme else 8.0
	var origin: Vector2 = sprite.position
	var tween: Tween = create_tween()
	for _i in 10:
		tween.tween_property(sprite, "position",
			origin + Vector2(randf_range(-strength, strength), randf_range(-strength * 0.5, strength * 0.5)),
			0.05)
	tween.tween_property(sprite, "position", origin, 0.05)

func _hop_in_place(sprite: Sprite2D) -> void:
	var theme: Resource = vn_theme
	var hop_h: float = theme.sprite_hop_height if theme else 30.0
	var origin: Vector2 = sprite.position
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "position", origin + Vector2(0, -hop_h), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", origin, 0.2).set_ease(Tween.EASE_IN)

func _bounce_sprite(sprite: Sprite2D) -> void:
	var origin_scale: Vector2 = sprite.scale
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", origin_scale * 1.15, 0.1)
	tween.tween_property(sprite, "scale", origin_scale * 0.92, 0.1)
	tween.tween_property(sprite, "scale", origin_scale, 0.1)

func _pulse_sprite(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1), 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

func _spin_sprite(sprite: Sprite2D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "rotation_degrees", 360, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): sprite.rotation_degrees = 0)
