extends Node2D

const TARGET_SIZE := Vector2(500, 500)
const BOB_IDLE_HEIGHT  := 7.0
const BOB_IDLE_SPEED   := 0.9
const BOB_TALK_HEIGHT  := 14.0
const BOB_TALK_SPEED   := 0.35

# Adjusted positions to fit standard 1280x720 and 1152x648 windows
const POSITIONS: Dictionary = {
	"left":         Vector2(280,  400),
	"center":       Vector2(640,  400),
	"right":        Vector2(1000, 400),
}

@export var vn_theme: Resource

# ── Expression synonyms ───────────────────────────────────────
# Map any alias → the real expression key on the actor.
# e.g. { "sneeze": "sad", "grin": "happy", "beam": "happy" }
const EXPRESSION_SYNONYMS: Dictionary = {
	"sneeze": "sad",   
	"startled" : "sad",
	"worried" : "sad"
	
	
}

var _actors: Dictionary = {}
var _current_speaker: String = ""
var _active_slots: Array = ["", ""] # [0]=Left, [1]=Right

func _ready() -> void:
	SignalBus.actor_show.connect(_on_actor_show)
	SignalBus.actor_hide.connect(_on_actor_hide)
	SignalBus.actor_move.connect(_on_actor_move)
	SignalBus.actor_expression.connect(_on_actor_expression)
	SignalBus.actor_animate.connect(_on_actor_animate)
	SignalBus.dialogue_line_started.connect(_on_dialogue_started)
	
	SignalBus.actor_appear.connect(_on_actor_appear)
	SignalBus.clear_visual_state.connect(_on_clear_visual_state)

func register_actor(actor_cfg: Dictionary) -> void:
	var actor_id: String = actor_cfg["id"]
	var sprite: Sprite2D = Sprite2D.new()
	sprite.modulate.a = 0.0
	sprite.visible    = false
	sprite.position   = POSITIONS["center"]
	add_child(sprite)

	_actors[actor_id] = {
		"node":        sprite,
		"expressions": actor_cfg.get("expressions", {}),
		"base_pos":    POSITIONS["center"],
		"bob_tween":   null,
		"talking":     false,
	}
	_apply_scale(sprite, _actors[actor_id]["expressions"])

func _on_clear_visual_state() -> void:
	_active_slots = ["", ""]
	for actor_id in _actors:
		var sprite = _actors[actor_id]["node"]
		sprite.visible = false
		sprite.modulate.a = 0.0
		_stop_bob(actor_id)

func _on_actor_appear(actor_id: String, expression: String, position: String, instant: bool = false) -> void:
	if not _actors.has(actor_id): return

	var final_pos = position
	if position == "center" or position == "":
		if _active_slots[0] == "" or _active_slots[0] == actor_id:
			_active_slots[0] = actor_id
			final_pos = "left"
		elif _active_slots[1] == "" or _active_slots[1] == actor_id:
			_active_slots[1] = actor_id
			final_pos = "right"
		else:
			if not instant:
				_on_actor_hide(_active_slots[0])
			_active_slots[0] = actor_id
			final_pos = "left"
	else:
		# Explicit position given — still track the slot
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id

	_do_appear_at(actor_id, expression, final_pos, instant)

func _do_appear_at(actor_id: String, expression: String, pos_key: String, instant: bool):
	var data = _actors[actor_id]
	var sprite = data["node"]
	var base = POSITIONS.get(pos_key, POSITIONS["center"])
	data["base_pos"] = base
	sprite.position = base
	sprite.visible = true
	_set_expression(data, expression)
	
	if instant:
		sprite.modulate.a = 1.0 # Jump to fully visible
		_start_bob(actor_id, false)
	else:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func(): _start_bob(actor_id, false))

func _on_actor_hide(actor_id: String) -> void:
	if not _actors.has(actor_id): return
	if _active_slots[0] == actor_id: _active_slots[0] = ""
	if _active_slots[1] == actor_id: _active_slots[1] = ""
	
	var data = _actors[actor_id]
	_stop_bob(actor_id)
	var tw = create_tween()
	tw.tween_property(data["node"], "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): data["node"].visible = false)

# ... (Rest of ActorManager helper functions: _on_actor_move, _start_bob, etc. remain the same)




# ── SHOW (already appeared, just swap expression/position) ────
func _on_actor_show(actor_id: String, expression: String, position: String) -> void:
	if not _actors.has(actor_id):
		push_warning("ActorManager: unknown actor '%s'" % actor_id)
		return
	var data: Dictionary  = _actors[actor_id]
	var sprite: Sprite2D  = data["node"]
	var base: Vector2     = POSITIONS.get(position, POSITIONS["center"])
	data["base_pos"]      = base
	sprite.visible        = true
	_set_expression(data, expression)
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _start_bob(actor_id, false))

# ── MOVE ──────────────────────────────────────────────────────
func _on_actor_move(actor_id: String, position: String, anim: String) -> void:
	if not _actors.has(actor_id):
		return
	var data: Dictionary = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var target: Vector2  = POSITIONS.get(position, POSITIONS["center"])
	data["base_pos"]     = target
	_stop_bob(actor_id)
	match anim:
		"slide":
			var dur: float = vn_theme.sprites.slide_duration if vn_theme and vn_theme.sprites else 0.4
			var tw: Tween  = create_tween()
			tw.tween_property(sprite, "position", target, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tw.tween_callback(func(): _start_bob(actor_id, data["talking"]))
		"hop":
			_hop_to(sprite, target, func(): _start_bob(actor_id, data["talking"]))
		_:
			sprite.position = target
			_start_bob(actor_id, data["talking"])

# ── EXPRESSION ────────────────────────────────────────────────
func _on_actor_expression(actor_id: String, expression: String) -> void:
	if not _actors.has(actor_id):
		return
	_set_expression(_actors[actor_id], expression)

# ── ANIMATE ───────────────────────────────────────────────────
func _on_actor_animate(actor_id: String, anim: String) -> void:
	if not _actors.has(actor_id):
		return
	var sprite: Sprite2D = _actors[actor_id]["node"]
	match anim:
		"shake":   _shake_sprite(sprite)
		"hop":     _hop_in_place(sprite)
		"bounce":  _bounce_sprite(sprite)
		"pulse":   _pulse_sprite(sprite)
		"spin":    _spin_sprite(sprite)
		_:         push_warning("ActorManager: unknown anim '%s'" % anim)

# ── DIALOGUE STARTED — update who is talking ──────────────────
func _on_dialogue_started(packet: Dictionary) -> void:
	var speaker: String = packet.get("speaker", "").strip_edges()
	if speaker == _current_speaker:
		return
	# Stop old speaker's talk bob, start idle bob
	if _current_speaker != "" and _actors.has(_current_speaker):
		_actors[_current_speaker]["talking"] = false
		_start_bob(_current_speaker, false)
	_current_speaker = speaker
	# Start new speaker's talk bob
	if speaker != "" and _actors.has(speaker):
		_actors[speaker]["talking"] = true
		_start_bob(speaker, true)

# ── BOB ───────────────────────────────────────────────────────
func _start_bob(actor_id: String, talking: bool) -> void:
	if not _actors.has(actor_id):
		return
	_stop_bob(actor_id)
	var data: Dictionary = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base: Vector2    = data["base_pos"]
	var height: float    = BOB_TALK_HEIGHT if talking else BOB_IDLE_HEIGHT
	var speed: float     = BOB_TALK_SPEED  if talking else BOB_IDLE_SPEED
	var tw: Tween = create_tween()
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sprite, "position", base + Vector2(0, -height), speed)
	tw.tween_property(sprite, "position", base,                        speed)
	data["bob_tween"] = tw

func _stop_bob(actor_id: String) -> void:
	var data: Dictionary = _actors[actor_id]
	if data["bob_tween"] != null:
		data["bob_tween"].kill()
		data["bob_tween"] = null
	# Snap back to base position
	data["node"].position = data["base_pos"]

# ── Expression swap (auto-resize on swap) ─────────────────────
func _set_expression(data: Dictionary, expression: String) -> void:
	# Resolve synonym first (e.g. "sneeze" → "sad")
	if EXPRESSION_SYNONYMS.has(expression):
		expression = EXPRESSION_SYNONYMS[expression]
	var exprs: Dictionary = data["expressions"]
	if expression == "" or not exprs.has(expression):
		expression = exprs.keys()[0] if not exprs.is_empty() else ""
	if expression == "" or not exprs.has(expression):
		return
	var tex: Texture2D   = exprs[expression]
	var sprite: Sprite2D = data["node"]
	sprite.texture = tex
	# Resize to TARGET_SIZE maintaining aspect ratio
	if tex and tex.get_width() > 0:
		var tex_size := Vector2(tex.get_width(), tex.get_height())
		var fit: float = minf(TARGET_SIZE.x / tex_size.x, TARGET_SIZE.y / tex_size.y)
		sprite.scale = Vector2.ONE * fit

# ── Movement helpers ──────────────────────────────────────────
func _hop_to(sprite: Sprite2D, target: Vector2, on_done: Callable) -> void:
	var hop_h: float = 30.0
	var dur: float   = 0.4
	var mid: Vector2 = sprite.position.lerp(target, 0.5) + Vector2(0, -hop_h)
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "position", mid,    dur * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", target, dur * 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(on_done)

func _shake_sprite(sprite: Sprite2D) -> void:
	var strength: float = 8.0
	var origin: Vector2 = sprite.position
	var tw: Tween = create_tween()
	for _i in 10:
		tw.tween_property(sprite, "position",
			origin + Vector2(randf_range(-strength, strength), randf_range(-strength * 0.5, strength * 0.5)), 0.05)
	tw.tween_property(sprite, "position", origin, 0.05)

func _hop_in_place(sprite: Sprite2D) -> void:
	var origin: Vector2 = sprite.position
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "position", origin + Vector2(0, -30), 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", origin,                   0.2).set_ease(Tween.EASE_IN)

func _bounce_sprite(sprite: Sprite2D) -> void:
	var s: Vector2 = sprite.scale
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "scale", s * 1.15, 0.1)
	tw.tween_property(sprite, "scale", s * 0.92, 0.1)
	tw.tween_property(sprite, "scale", s,         0.1)

func _pulse_sprite(sprite: Sprite2D) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1), 0.15)
	tw.tween_property(sprite, "modulate", Color.WHITE,              0.25)

func _spin_sprite(sprite: Sprite2D) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "rotation_degrees", 360, 0.5).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): sprite.rotation_degrees = 0)



# ── Auto-scale helper ─────────────────────────────────────────
# This function calculates the uniform scale needed to fit the sprite 
# within TARGET_SIZE (500x500) while maintaining aspect ratio. 
func _apply_scale(sprite: Sprite2D, expressions: Dictionary, custom_multiplier: float = 1.0) -> void:
	# 1. Safety check: If no expressions exist, we can't determine the texture size. 
	if expressions.is_empty():
		return
	
	# 2. Use the first available expression texture as the reference for size. 
	var first_tex: Texture2D = expressions[expressions.keys()[0]]
	
	if first_tex and first_tex.get_width() > 0:
		var tex_size := Vector2(first_tex.get_width(), first_tex.get_height())
		
		# 3. Calculate the scale factor required to fit inside the TARGET_SIZE. 
		# We use minf to ensure the largest dimension is what limits the scale.
		var fit: float = minf(TARGET_SIZE.x / tex_size.x, TARGET_SIZE.y / tex_size.y)
		
		# 4. Apply the calculated fit multiplied by any custom scale provided.
		# Note: We use Vector2.ONE * fit to keep the aspect ratio uniform. 
		sprite.scale = (Vector2.ONE * fit) * custom_multiplier
		
		# 5. Assign the texture so the sprite has immediate visual data. 
		sprite.texture = first_tex

func reset_all_actors() -> void:
	_active_slots = ["", ""] 
	_current_speaker = ""
	for actor_id in _actors:
		var data = _actors[actor_id]
		_stop_bob(actor_id)
		data["node"].visible = false
		data["node"].modulate.a = 0.0
		data["talking"] = false
