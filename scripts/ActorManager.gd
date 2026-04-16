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

# ── Paired-actor config ───────────────────────────────────────
# Actors in a pair always appear together on one side, standing next to each other.
#
# PAIRED_OFFSET controls how far apart the two characters stand.
# The pair's anchor point is the slot position (e.g. POSITIONS["right"] = x:1000).
# Left-of-pair lands at anchor - PAIRED_OFFSET/2, right-of-pair at anchor + PAIRED_OFFSET/2.
# So with offset 160: left member is at x=920, right member at x=1080.
# Increase this number to spread them further apart.
const PAIRED_OFFSET := Vector2(160, 0)   # ← ADJUST THIS to tune spacing between pair members

# How far the second (and subsequent) character on the same side is offset
# inward from the first.  Positive X = toward screen centre.
# e.g. 90 means the second actor on the right appears 90px to the left of slot.
const SAME_SIDE_STAGGER := 90.0          # ← ADJUST THIS to tune same-side stacking distance

# Map: any actor_id in a pair → the canonical "pair id" (first member's id).
# Both members share the same slot. The pair_id is also the actor registered
# in VNController for the shared sprite (or you can register both individually).
const PAIRED_ACTORS: Dictionary = {
	"Scotch": "Scotch",   # canonical id — registered in VNController
	"Tofu":   "Scotch",   # alias that resolves to the same pair slot
}
# For each pair, which actor sits left vs right within the pair.
# Format: pair_id → [left_member_id, right_member_id]
const PAIRED_LAYOUT: Dictionary = {
	"Scotch": ["Scotch", "Tofu"],
}

# Actor IDs that should always go to the LEFT slot when no explicit position given.
const PREFER_LEFT_ACTORS: Array = ["Marty"]

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

	var custom_scale: float = actor_cfg.get("scale", 1.0) # Grab the scale from the config

	_actors[actor_id] = {
		"node":        sprite,
		"expressions": actor_cfg.get("expressions", {}),
		"base_pos":    POSITIONS["center"],
		"bob_tween":   null,
		"talking":     false,
		"custom_scale": custom_scale # Store it so we can use it later
	}
	# Pass the custom scale into the initial setup
	_apply_scale(sprite, _actors[actor_id]["expressions"], custom_scale)

func _on_clear_visual_state() -> void:
	_active_slots = ["", ""]
	_pair_slots.clear()
	_pair_expressions.clear()
	for actor_id in _actors:
		var sprite = _actors[actor_id]["node"]
		sprite.visible = false
		sprite.modulate.a = 0.0
		_stop_bob(actor_id)

func _on_actor_appear(actor_id: String, expression: String, position: String, instant: bool = false) -> void:
	if not _actors.has(actor_id): return

	# ── Marty gets a one-frame head start so he always claims left first ──────
	# All other actors (including pairs) are deferred by one frame. This means
	# even when Marty and another character enter on the same passage, Marty's
	# slot assignment runs first regardless of tag order.
	if not PREFER_LEFT_ACTORS.has(actor_id) and not PAIRED_ACTORS.has(actor_id):
		call_deferred("_on_actor_appear_deferred", actor_id, expression, position, instant)
		return
	if PAIRED_ACTORS.has(actor_id):
		call_deferred("_on_paired_appear", actor_id, expression, position, instant)
		return

	# ── Marty (or any PREFER_LEFT actor) — runs immediately ──────────────────
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
				_on_actor_hide(_active_slots[1])
			_active_slots[0] = actor_id
			final_pos = "left"
	else:
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id

	_do_appear_at(actor_id, expression, final_pos, instant)


func _on_actor_appear_deferred(actor_id: String, expression: String, position: String, instant: bool) -> void:
	if not _actors.has(actor_id): return

	# All non-Marty, non-paired actors prefer RIGHT slot.
	var final_pos = position
	if position == "center" or position == "":
		if _active_slots[1] == "" or _active_slots[1] == actor_id:
			_active_slots[1] = actor_id
			final_pos = "right"
		elif _active_slots[0] == "" or _active_slots[0] == actor_id:
			_active_slots[0] = actor_id
			final_pos = "left"
		else:
			if not instant:
				_on_actor_hide(_active_slots[1])
			_active_slots[1] = actor_id
			final_pos = "right"
	else:
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id

	_do_appear_at(actor_id, expression, final_pos, instant)


# ── Paired-actor appear ───────────────────────────────────────
# Both members of a pair are placed on the same side, offset from each other.
# _pair_slot tracks which screen-side the pair occupies ("left" or "right").
var _pair_slots: Dictionary = {}          # pair_id → slot key ("left"/"right")
var _pair_expressions: Dictionary = {}    # pair_id → { member_id: expression }

func _on_paired_appear(actor_id: String, expression: String, position: String, instant: bool) -> void:
	var pair_id: String = PAIRED_ACTORS[actor_id]
	var layout: Array   = PAIRED_LAYOUT.get(pair_id, [pair_id, actor_id])

	# Decide which slot the pair uses
	var slot_key: String = _pair_slots.get(pair_id, "")
	if slot_key == "" or position != "":
		if position != "" and position != "center":
			slot_key = position
		else:
			# Pairs prefer the RIGHT slot so they don't clash with Marty (who prefers left).
			# Only fall back to left if right is already taken by someone else.
			if _active_slots[1] == "" or _active_slots[1] == pair_id:
				slot_key = "right"
			elif _active_slots[0] == "" or _active_slots[0] == pair_id:
				slot_key = "left"
			else:
				slot_key = "right"   # fallback
		_pair_slots[pair_id] = slot_key

	# Reserve the slot
	if slot_key == "left":
		_active_slots[0] = pair_id
	else:
		_active_slots[1] = pair_id

	# Store this member's expression
	if not _pair_expressions.has(pair_id):
		_pair_expressions[pair_id] = {}
	_pair_expressions[pair_id][actor_id] = expression

	# Place both members (if both are registered) side by side
	var base_pos: Vector2 = POSITIONS.get(slot_key, POSITIONS["right"])
	var left_member:  String = layout[0]
	var right_member: String = layout[1]

	for member_id in [left_member, right_member]:
		if not _actors.has(member_id):
			continue
		var is_left_of_pair: bool = (member_id == left_member)
		var offset: Vector2 = -PAIRED_OFFSET * 0.5 if is_left_of_pair else PAIRED_OFFSET * 0.5
		var member_pos: Vector2 = base_pos + offset
		var member_expr: String = _pair_expressions[pair_id].get(member_id, "neutral")
		var data = _actors[member_id]
		data["base_pos"] = member_pos
		_stop_bob(member_id)
		data["node"].visible = true
		_set_expression(data, member_expr)
		if instant:
			data["node"].modulate.a = 1.0
			data["node"].position = member_pos
		else:
			data["node"].position = member_pos
			data["node"].modulate.a = 0.0
			var tw = create_tween()
			tw.tween_property(data["node"], "modulate:a", 1.0, 0.4)

	# Bob only the active speaker; the other idles
	for member_id in [left_member, right_member]:
		if not _actors.has(member_id):
			continue
		var is_speaker: bool = (member_id == actor_id)
		_actors[member_id]["talking"] = is_speaker
		_start_bob(member_id, is_speaker)


func _on_paired_hide(pair_id: String) -> void:
	var layout: Array = PAIRED_LAYOUT.get(pair_id, [])
	for member_id in layout:
		if _actors.has(member_id):
			_stop_bob(member_id)
			var tw = create_tween()
			tw.tween_property(_actors[member_id]["node"], "modulate:a", 0.0, 0.3)
			tw.tween_callback(func(): _actors[member_id]["node"].visible = false)
	_pair_slots.erase(pair_id)
	_pair_expressions.erase(pair_id)
	if _active_slots[0] == pair_id: _active_slots[0] = ""
	if _active_slots[1] == pair_id: _active_slots[1] = ""

func _do_appear_at(actor_id: String, expression: String, pos_key: String, instant: bool):
	var data = _actors[actor_id]
	var sprite = data["node"]
	var base = POSITIONS.get(pos_key, POSITIONS["center"])

	# ── Same-side stagger: if another actor already owns this slot, push this
	# actor inward by SAME_SIDE_STAGGER so they don't perfectly overlap.
	var slot_index: int = 0 if pos_key == "left" else (1 if pos_key == "right" else -1)
	if slot_index >= 0 and _active_slots[slot_index] != "" and _active_slots[slot_index] != actor_id:
		# Direction toward screen centre: right-side actors shift left, left-side shift right
		var inward: float = -1.0 if pos_key == "right" else 1.0
		base = base + Vector2(inward * SAME_SIDE_STAGGER, 0.0)

	data["base_pos"] = base
	# Stop any running bob/move tween so it can't fight the new position
	_stop_bob(actor_id)
	sprite.position = base
	sprite.visible = true
	_set_expression(data, expression)

	if instant:
		sprite.modulate.a = 1.0
		_start_bob(actor_id, false)
	else:
		sprite.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 1.0, 0.4)
		tw.tween_callback(func(): _start_bob(actor_id, false))

func _on_actor_hide(actor_id: String) -> void:
	if not _actors.has(actor_id):
		# Check if it's a pair_id
		if PAIRED_LAYOUT.has(actor_id):
			_on_paired_hide(actor_id)
		return
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

	# ── Stop old speaker if it changed ───────────────────────────
	if _current_speaker != "" and _current_speaker != speaker:
		if PAIRED_ACTORS.has(_current_speaker):
			var old_pair_id: String = PAIRED_ACTORS[_current_speaker]
			for member_id in PAIRED_LAYOUT.get(old_pair_id, []):
				if _actors.has(member_id):
					_actors[member_id]["talking"] = false
					_start_bob(member_id, false)
		elif _actors.has(_current_speaker):
			_actors[_current_speaker]["talking"] = false
			_start_bob(_current_speaker, false)

	_current_speaker = speaker

	# ── Always (re)start bob for the new/current speaker ─────────
	# This handles consecutive lines from the same actor correctly.
	if speaker == "":
		return
	if PAIRED_ACTORS.has(speaker):
		var pair_id: String = PAIRED_ACTORS[speaker]
		for member_id in PAIRED_LAYOUT.get(pair_id, []):
			if _actors.has(member_id):
				var is_speaker: bool = (member_id == speaker)
				_actors[member_id]["talking"] = is_speaker
				_start_bob(member_id, is_speaker)
	elif _actors.has(speaker):
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
		
		# Grab the stored scale and apply it to the final calculation
		var custom_scale: float = data.get("custom_scale", 1.0)
		sprite.scale = (Vector2.ONE * fit) * custom_scale
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
