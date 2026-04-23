extends Node2D

const TARGET_SIZE := Vector2(500, 500)
const BOB_IDLE_HEIGHT  := 7.0
const BOB_IDLE_SPEED   := 0.9
const BOB_TALK_HEIGHT  := 14.0
const BOB_TALK_SPEED   := 0.35

# ── Pop-in tuning ─────────────────────────────────────────────
# How much bigger the character starts on entry (1.0 = normal size, 1.2 = 20% bigger)
const POPIN_OVERSHOOT_SCALE: float = 1.20  # ← ADJUST: entry overshoot scale multiplier
const POPIN_DURATION:        float = 0.7  # ← ADJUST: seconds for pop-in animation
const POPIN_SETTLE_DURATION: float = 0.10  # ← ADJUST: seconds for settle to normal

# ── Talking scale tuning ──────────────────────────────────────
const TALK_SCALE_MULTIPLIER: float = 1.2  # ← ADJUST: how much bigger the speaker gets (e.g. 1.07 = 7% bigger)

# ── Bobbing toggle ────────────────────────────────────────────
var BOBBING_ENABLED: bool = false           # ← ADJUST: set false to disable all bobbing

# ── Emoticon config ───────────────────────────────────────────
# Folder where your 800x800 emoticons live. Filenames must be: <emotion>.png
# e.g. res://emoticons/sad.png, res://emoticons/happy.png, etc.
const EMOTICON_PATH_PREFIX: String = "res://emoticons/"
const EMOTICON_DISPLAY_SIZE: float = 80.0   # ← ADJUST: rendered size of the emoticon bubble

# Per-character emoticon offsets at BASE (non-talking) scale.
# Offset is in pixels from the character's base_pos (screen anchor point).
# x = horizontal (positive = right), y = vertical (negative = up).
# If a character isn't listed here, EMOTICON_OFFSET_DEFAULT is used.
const EMOTICON_OFFSET_DEFAULT: Vector2 = Vector2(80, -230)
const EMOTICON_OFFSETS: Dictionary = {
	"Marty":    Vector2(80,  -260),
	"Matthew":  Vector2(80,  -220),
	"Chester":  Vector2(80,  -220),
	"Barnaby":  Vector2(80,  -220),
	"Peanut":   Vector2(80,  -220),
	"Peaches":  Vector2(80,  -220),
	"Buttons":  Vector2(80,  -220),
	"Scotch":   Vector2(80,  -220),
	"Tofu":     Vector2(80,  -220),
	"Jane":     Vector2(80,  -220),
	"Smith":    Vector2(80,  -220),
	"Wolf":     Vector2(80,  -260),
}

const EMOTICON_FADE_DUR:  float    = 0.25   # ← ADJUST: fade-out duration when hiding emoticon

# Supported emotion names (must match filenames in EMOTICON_PATH_PREFIX folder)
const EMOTICON_EMOTIONS: Array = ["angry", "sad", "scared", "happy"]

# ── Enter SFX ─────────────────────────────────────────────────
# Path to the sound played when any character enters the scene.
const ENTER_SFX_PATH: String = "res://audio/sfx/actor_enter.wav"  # ← SET THIS to your SFX file path

# Adjusted positions to fit standard 1280x720 and 1152x648 windows
const POSITIONS: Dictionary = {
	"left":         Vector2(280,  400),
	"center":       Vector2(640,  400),
	"right":        Vector2(1000, 400),
}

# ── Paired-actor config ───────────────────────────────────────
const PAIRED_OFFSET := Vector2(200, 0)  # used by the named pair (Scotch/Tofu)
# How far each of two same-side actors is pushed from the slot anchor.
# Increase this to widen the gap between co-occupants.
const COOCCUPANT_HALF_OFFSET: float = 130.0

# Per-slot secondary occupant tracking.
# _slot_cooccupants[slot_key] = Array of up to 2 actor IDs on that side.
var _slot_cooccupants: Dictionary = {"left": [], "right": []}

const PAIRED_ACTORS: Dictionary = {
	"Scotch": "Scotch",
	"Tofu":   "Scotch",
}
const PAIRED_LAYOUT: Dictionary = {
	"Scotch": ["Scotch", "Tofu"],
}

const PREFER_LEFT_ACTORS: Array = ["Marty"]

# Actors whose sprite is flipped horizontally when they stand on the LEFT side.
# Add any actor name here whose art faces right by default.
const MIRROR_LEFT_ACTORS: Array = ["Buttons"]

@export var vn_theme: Resource

# ── Expression synonyms ───────────────────────────────────────
const EXPRESSION_SYNONYMS: Dictionary = {
	"sneeze":    "sad",
	"startled":  "sad",
	"worried":   "sad"
}

var _actors: Dictionary = {}
var _current_speaker: String = ""
var _active_slots: Array = ["", ""]

# Tracks any in-progress hide tween per slot (0=left, 1=right) so enter can wait for it.
var _hide_tweens: Dictionary = {}  # slot_index (int) → Tween

# Emoticon sprites — one per actor
var _emoticon_sprites: Dictionary = {}   # actor_id → Sprite2D

# Preloaded emoticon textures (loaded on first use)
var _emoticon_textures: Dictionary = {}  # emotion_name → Texture2D

# Emoticon run tracking — only show for first 2 consecutive identical emotions
var _emoticon_last_emotion: Dictionary = {}   # actor_id → last emotion shown
var _emoticon_run_count: Dictionary    = {}   # actor_id → consecutive count

# Enter SFX player
var _enter_sfx_player: AudioStreamPlayer = null

func _ready() -> void:
	SignalBus.actor_show.connect(_on_actor_show)
	SignalBus.actor_hide.connect(_on_actor_hide)
	SignalBus.actor_move.connect(_on_actor_move)
	SignalBus.actor_expression.connect(_on_actor_expression)
	SignalBus.actor_animate.connect(_on_actor_animate)
	SignalBus.dialogue_line_started.connect(_on_dialogue_started)
	SignalBus.actor_appear.connect(_on_actor_appear)
	SignalBus.clear_visual_state.connect(_on_clear_visual_state)

	# ── Set up enter SFX player ───────────────────────────────
	_enter_sfx_player = AudioStreamPlayer.new()
	_enter_sfx_player.name = "EnterSFXPlayer"
	add_child(_enter_sfx_player)
	if ResourceLoader.exists(ENTER_SFX_PATH):
		_enter_sfx_player.stream = load(ENTER_SFX_PATH)
	else:
		push_warning("ActorManager: Enter SFX not found at '%s' — set ENTER_SFX_PATH" % ENTER_SFX_PATH)

	# ── Preload emoticon textures ─────────────────────────────
	for emo in EMOTICON_EMOTIONS:
		var path: String = EMOTICON_PATH_PREFIX + emo + ".png"
		if ResourceLoader.exists(path):
			_emoticon_textures[emo] = load(path)
		else:
			# Also try .webp
			var alt: String = EMOTICON_PATH_PREFIX + emo + ".webp"
			if ResourceLoader.exists(alt):
				_emoticon_textures[emo] = load(alt)
			else:
				push_warning("ActorManager: emoticon not found for '%s' (tried %s and %s)" % [emo, path, alt])

# ── Per-frame emoticon tracking ───────────────────────────────
# Keeps each visible emoticon glued to its character at the correct
# scaled position, even while talk-scale tweens are running.
func _process(_delta: float) -> void:
	for actor_id in _emoticon_sprites:
		var emo_sprite: Sprite2D = _emoticon_sprites[actor_id]
		if not emo_sprite.visible:
			continue
		if not _actors.has(actor_id):
			continue
		var data          = _actors[actor_id]
		var char_sprite: Sprite2D = data["node"]
		var base_scale_x: float   = data.get("base_scale", char_sprite.scale).x
		if base_scale_x <= 0.0:
			continue
		# How much is the character scaled right now vs its resting size?
		var live_ratio: float = char_sprite.scale.x / base_scale_x
		# Base offset for this specific character (at rest scale = 1.0)
		var base_offset: Vector2 = EMOTICON_OFFSETS.get(actor_id, EMOTICON_OFFSET_DEFAULT)
		# Scale the offset proportionally so the emoticon stays at the same
		# visual spot on the character regardless of the current scale.
		emo_sprite.position = data["base_pos"] + base_offset * live_ratio
		# Also rescale the emoticon itself to match.
		var tex: Texture2D = emo_sprite.texture
		if tex and tex.get_width() > 0:
			var base_emo_scale: float = EMOTICON_DISPLAY_SIZE / float(tex.get_width())
			emo_sprite.scale = Vector2.ONE * base_emo_scale * live_ratio

func register_actor(actor_cfg: Dictionary) -> void:
	var actor_id: String = actor_cfg["id"]
	var sprite: Sprite2D = Sprite2D.new()
	sprite.modulate.a = 0.0
	sprite.visible    = false
	sprite.position   = POSITIONS["center"]
	add_child(sprite)

	var custom_scale: float = actor_cfg.get("scale", 1.0)

	_actors[actor_id] = {
		"node":         sprite,
		"expressions":  actor_cfg.get("expressions", {}),
		"base_pos":     POSITIONS["center"],
		"bob_tween":    null,
		"talking":      false,
		"custom_scale": custom_scale,
		"base_scale":   Vector2.ONE,   # set properly after first _set_expression
	}
	_apply_scale(sprite, _actors[actor_id]["expressions"], custom_scale)

	# ── Create the emoticon sprite for this actor ─────────────
	var emo_sprite: Sprite2D = Sprite2D.new()
	emo_sprite.visible = false
	emo_sprite.modulate.a = 0.0
	emo_sprite.z_index = 10
	add_child(emo_sprite)
	_emoticon_sprites[actor_id] = emo_sprite

func _on_clear_visual_state() -> void:
	_active_slots = ["", ""]
	_slot_cooccupants = {"left": [], "right": []}
	_current_speaker = ""
	_pair_slots.clear()
	_pair_expressions.clear()
	_emoticon_last_emotion.clear()
	_emoticon_run_count.clear()
	# Kill ALL pending hide tweens so their callbacks never fire after this clear.
	for slot_i in _hide_tweens:
		_hide_tweens[slot_i].kill()
	_hide_tweens.clear()
	for actor_id in _actors:
		var data   = _actors[actor_id]
		var sprite = data["node"]
		# Hide FIRST so _stop_bob's visibility guard skips the position snap.
		sprite.visible    = false
		sprite.modulate.a = 0.0
		data["talking"]   = false
		# Kill bob tween directly without the position snap.
		if data["bob_tween"] != null:
			data["bob_tween"].kill()
			data["bob_tween"] = null
		_hide_emoticon(actor_id, true)

func _on_actor_appear(actor_id: String, expression: String, position: String, instant: bool = false) -> void:
	if not _actors.has(actor_id): return

	# ── INSTANT PATH (go_back restore) ───────────────────────────────────────────
	# Bypass ALL slot / co-occupant logic. The caller (VNLogic.go_back) has already
	# computed the exact position from the saved stage snapshot, so we must honour
	# it exactly — no co-occupant shifting, no call_deferred races, no slide tweens.
	if instant:
		if PAIRED_ACTORS.has(actor_id):
			call_deferred("_on_paired_appear", actor_id, expression, position, true)
			return
		var data = _actors[actor_id]
		var sprite: Sprite2D = data["node"]
		var target: Vector2  = POSITIONS.get(position, POSITIONS["center"])
		data["base_pos"]     = target
		data["talking"]      = false
		sprite.position      = target
		sprite.visible       = true
		sprite.modulate.a    = 1.0
		_set_expression(data, expression)
		_apply_mirror(actor_id, position)  # restore correct mirror for saved side
		_stop_bob(actor_id)
		# Update active_slots so subsequent logic knows who is where.
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id
		# Keep co-occupant list in sync so any later real enters are positioned correctly.
		for side in ["left", "right"]:
			if not _slot_cooccupants[side].has(actor_id) and position == side:
				_slot_cooccupants[side].append(actor_id)
		return

	# ── ANIMATED PATH (normal forward play) ──────────────────────────────────────
	if not PREFER_LEFT_ACTORS.has(actor_id) and not PAIRED_ACTORS.has(actor_id):
		call_deferred("_on_actor_appear_deferred", actor_id, expression, position, false)
		return
	if PAIRED_ACTORS.has(actor_id):
		call_deferred("_on_paired_appear", actor_id, expression, position, false)
		return

	var final_pos = position
	if position == "center" or position == "":
		if _active_slots[0] == "" or _active_slots[0] == actor_id:
			_active_slots[0] = actor_id
			final_pos = "left"
		elif _active_slots[1] == "" or _active_slots[1] == actor_id:
			_active_slots[1] = actor_id
			final_pos = "right"
		else:
			_on_actor_hide(_active_slots[1])
			_active_slots[0] = actor_id
			final_pos = "left"
	else:
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id

	_do_appear_at(actor_id, expression, final_pos, false)


func _on_actor_appear_deferred(actor_id: String, expression: String, position: String, instant: bool) -> void:
	if not _actors.has(actor_id): return

	var final_pos = position
	if position == "center" or position == "":
		if _active_slots[1] == "" or _active_slots[1] == actor_id:
			_active_slots[1] = actor_id
			final_pos = "right"
		elif _active_slots[0] == "" or _active_slots[0] == actor_id:
			_active_slots[0] = actor_id
			final_pos = "left"
		else:
			_on_actor_hide(_active_slots[1])
			_active_slots[1] = actor_id
			final_pos = "right"
	else:
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id

	_do_appear_at(actor_id, expression, final_pos, false)


# ── Paired-actor appear ───────────────────────────────────────
var _pair_slots: Dictionary = {}
var _pair_expressions: Dictionary = {}

func _on_paired_appear(actor_id: String, expression: String, position: String, instant: bool) -> void:
	var pair_id: String = PAIRED_ACTORS[actor_id]
	var layout: Array   = PAIRED_LAYOUT.get(pair_id, [pair_id, actor_id])

	var slot_key: String = _pair_slots.get(pair_id, "")
	if slot_key == "" or position != "":
		if position != "" and position != "center":
			slot_key = position
		else:
			if _active_slots[1] == "" or _active_slots[1] == pair_id:
				slot_key = "right"
			elif _active_slots[0] == "" or _active_slots[0] == pair_id:
				slot_key = "left"
			else:
				slot_key = "right"
		_pair_slots[pair_id] = slot_key

	if slot_key == "left":
		_active_slots[0] = pair_id
	else:
		_active_slots[1] = pair_id

	if not _pair_expressions.has(pair_id):
		_pair_expressions[pair_id] = {}
	_pair_expressions[pair_id][actor_id] = expression

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
			_play_enter_sfx()
			_do_popin(member_id)

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
			_hide_emoticon(member_id, false)
			var sprite: Sprite2D = _actors[member_id]["node"]
			var home_pos: Vector2 = _actors[member_id]["base_pos"]
			var cur_x: float = sprite.position.x
			var slide_offset: float = 380.0
			var slide_target: Vector2
			if cur_x <= 640.0:
				slide_target = sprite.position + Vector2(-slide_offset, 0)
			else:
				slide_target = sprite.position + Vector2(slide_offset, 0)
			var tw = create_tween()
			tw.set_parallel(true)
			tw.tween_property(sprite, "position", slide_target, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
			tw.chain().tween_callback(func():
				sprite.visible = false
				sprite.position = home_pos
			)
	_pair_slots.erase(pair_id)
	_pair_expressions.erase(pair_id)
	if _active_slots[0] == pair_id: _active_slots[0] = ""
	if _active_slots[1] == pair_id: _active_slots[1] = ""

func _do_appear_at(actor_id: String, expression: String, pos_key: String, instant: bool):
	var slot_index: int = 0 if pos_key == "left" else (1 if pos_key == "right" else -1)
	var anchor: Vector2 = POSITIONS.get(pos_key, POSITIONS["center"])

	# ── Update per-slot co-occupant list ─────────────────────────────────────
	if pos_key in _slot_cooccupants:
		var occ: Array = _slot_cooccupants[pos_key]
		if not occ.has(actor_id):
			occ.append(actor_id)
		while occ.size() > 2:
			occ.pop_front()

	# ── Compute this actor's base position ───────────────────────────────────
	# 1 occupant  → normal slot anchor.
	# 2 occupants → spread symmetrically; first-arrived gets inner spot,
	#               new arrival gets outer spot.
	var my_base: Vector2 = anchor
	if pos_key in _slot_cooccupants:
		var occ: Array = _slot_cooccupants[pos_key]
		if occ.size() == 2:
			# inner = closer to screen center, outer = closer to screen edge
			var inner_pos: Vector2 = anchor + Vector2( COOCCUPANT_HALF_OFFSET, 0.0)
			var outer_pos: Vector2 = anchor + Vector2(-COOCCUPANT_HALF_OFFSET, 0.0)
			if pos_key == "right":
				inner_pos = anchor + Vector2(-COOCCUPANT_HALF_OFFSET, 0.0)
				outer_pos = anchor + Vector2( COOCCUPANT_HALF_OFFSET, 0.0)
			# occ[0] = first to arrive (inner), occ[1] = new arrival (outer)
			var positions_for_occ: Array = [inner_pos, outer_pos]
			for i in occ.size():
				var oid: String = occ[i]
				if oid == actor_id:
					my_base = positions_for_occ[i]
				elif _actors.has(oid) and _actors[oid]["node"].visible:
					# Slide the existing occupant to their adjusted spot.
					# Capture oid in a local so the lambda closes over the right value.
					var slide_oid: String = oid
					var odata = _actors[oid]
					odata["base_pos"] = positions_for_occ[i]
					_stop_bob(oid)
					var slide_tw: Tween = create_tween()
					slide_tw.tween_property(odata["node"], "position", positions_for_occ[i], 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					slide_tw.tween_callback(func():
						# Only restart bob if the actor is still visible (not cleared mid-tween).
						if _actors.has(slide_oid) and _actors[slide_oid]["node"].visible:
							_start_bob(slide_oid, _actors[slide_oid].get("talking", false))
					)

	# If a hide tween is still running for this slot, chain our appear after it.
	if slot_index >= 0 and _hide_tweens.has(slot_index) and not instant:
		_hide_tweens[slot_index].tween_callback(func():
			_do_appear_at_immediate(actor_id, expression, pos_key, my_base, false)
		)
		return

	_do_appear_at_immediate(actor_id, expression, pos_key, my_base, instant)

func _do_appear_at_immediate(actor_id: String, expression: String, pos_key: String, base: Vector2, instant: bool):
	var data = _actors[actor_id]
	var sprite = data["node"]
	data["base_pos"] = base
	_stop_bob(actor_id)
	sprite.position = base
	sprite.visible = true
	_set_expression(data, expression)
	_apply_mirror(actor_id, pos_key)  # mirror if needed for this side

	if instant:
		sprite.modulate.a = 1.0
		_start_bob(actor_id, false)
	else:
		_play_enter_sfx()
		_do_popin(actor_id)

# ── Horizontal mirror helper ──────────────────────────────────
# Flips the sprite scale.x sign for actors in MIRROR_LEFT_ACTORS when they
# are on the left side (they face right by default, so they should face
# inward/right when on left, and face left — their natural direction — when
# on right).  base_scale is always stored as positive magnitude.
func _apply_mirror(actor_id: String, pos_key: String) -> void:
	if not MIRROR_LEFT_ACTORS.has(actor_id):
		return
	if not _actors.has(actor_id):
		return
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	# On the left side, flip so the character faces right (toward center).
	# On any other side, use the natural (positive) orientation.
	var mirror: float = -1.0 if pos_key == "left" else 1.0
	sprite.scale = Vector2(base_scale.x * mirror, base_scale.y)


# ── Pop-in animation ─────────────────────────────────────────
func _do_popin(actor_id: String) -> void:
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base_scale: Vector2 = data.get("base_scale", sprite.scale)
	data["base_scale"] = base_scale

	sprite.modulate.a = 1.0
	sprite.scale = base_scale * POPIN_OVERSHOOT_SCALE

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", base_scale, POPIN_DURATION)
	tw.tween_callback(func():
		_start_bob(actor_id, false)
		# If this actor is already the current speaker (entered on the same line
		# they speak), apply the talk scale now that popin has settled.
		if _current_speaker == actor_id:
			_apply_talk_scale(actor_id)
	)

func _on_actor_hide(actor_id: String) -> void:
	if not _actors.has(actor_id):
		if PAIRED_LAYOUT.has(actor_id):
			_on_paired_hide(actor_id)
		return

	# Determine which slot this actor occupies so we can key the tween by slot.
	var slot_index: int = -1
	if _active_slots[0] == actor_id:
		slot_index = 0
	elif _active_slots[1] == actor_id:
		slot_index = 1
	# Don't clear the slot yet — keep it blocked until the slide-out finishes.

	var data = _actors[actor_id]
	_stop_bob(actor_id)
	_hide_emoticon(actor_id, false)

	# Slide off toward the edge the actor is closest to.
	var sprite: Sprite2D = data["node"]
	var cur_x: float = sprite.position.x
	var slide_offset: float = 380.0
	var slide_target: Vector2
	if cur_x <= 640.0:
		slide_target = sprite.position + Vector2(-slide_offset, 0)
	else:
		slide_target = sprite.position + Vector2(slide_offset, 0)

	var home_pos: Vector2 = data["base_pos"]

	# Kill any previous hide tween on this slot.
	if slot_index >= 0 and _hide_tweens.has(slot_index):
		_hide_tweens[slot_index].kill()

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "position", slide_target, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	# ── Remove from co-occupant tracking and re-centre the remaining solo ───
	var leaving_side: String = ""
	for side in ["left", "right"]:
		if _slot_cooccupants[side].has(actor_id):
			leaving_side = side
			_slot_cooccupants[side].erase(actor_id)
			if _slot_cooccupants[side].size() == 1:
				var solo_id: String = _slot_cooccupants[side][0]
				if _actors.has(solo_id) and _actors[solo_id]["node"].visible:
					var solo_data = _actors[solo_id]
					var solo_anchor: Vector2 = POSITIONS.get(side, POSITIONS["center"])
					solo_data["base_pos"] = solo_anchor
					_stop_bob(solo_id)
					var solo_tw: Tween = create_tween()
					solo_tw.tween_property(solo_data["node"], "position", solo_anchor, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					solo_tw.tween_callback(func():
						if _actors.has(solo_id) and _actors[solo_id]["node"].visible:
							_start_bob(solo_id, solo_data.get("talking", false))
					)
			break

	tw.chain().tween_callback(func():
		sprite.visible = false
		sprite.position = home_pos
		# Only clear the slot if it still belongs to this actor.
		# (A new actor may have already claimed it while the slide-out ran.)
		if slot_index >= 0:
			if _active_slots[slot_index] == actor_id:
				_active_slots[slot_index] = ""
			_hide_tweens.erase(slot_index)
	)

	if slot_index >= 0:
		_hide_tweens[slot_index] = tw


# ── SHOW ──────────────────────────────────────────────────────
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
	_apply_mirror(actor_id, position)  # update mirror for the new side
	# Update emoticon position too — _process will correct it next frame anyway,
	# but snap it here immediately so there's no one-frame lag on slide moves.
	if _emoticon_sprites.has(actor_id) and _emoticon_sprites[actor_id].visible:
		var base_offset: Vector2 = EMOTICON_OFFSETS.get(actor_id, EMOTICON_OFFSET_DEFAULT)
		_emoticon_sprites[actor_id].position = target + base_offset
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
	# Show emoticon if the expression is one of the emotion types
	_update_emoticon_for_expression(actor_id, expression)

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

	if _current_speaker != "" and _current_speaker != speaker:
		if PAIRED_ACTORS.has(_current_speaker):
			var old_pair_id: String = PAIRED_ACTORS[_current_speaker]
			for member_id in PAIRED_LAYOUT.get(old_pair_id, []):
				if _actors.has(member_id):
					_actors[member_id]["talking"] = false
					_start_bob(member_id, false)
					_restore_base_scale(member_id)
		elif _actors.has(_current_speaker):
			_actors[_current_speaker]["talking"] = false
			_start_bob(_current_speaker, false)
			_restore_base_scale(_current_speaker)

	_current_speaker = speaker

	if speaker == "":
		return
	if PAIRED_ACTORS.has(speaker):
		var pair_id: String = PAIRED_ACTORS[speaker]
		for member_id in PAIRED_LAYOUT.get(pair_id, []):
			if _actors.has(member_id):
				var is_speaker: bool = (member_id == speaker)
				_actors[member_id]["talking"] = is_speaker
				_start_bob(member_id, is_speaker)
				if is_speaker:
					_apply_talk_scale(member_id)
				else:
					_restore_base_scale(member_id)
	elif _actors.has(speaker):
		_actors[speaker]["talking"] = true
		_start_bob(speaker, true)
		_apply_talk_scale(speaker)

# ── Talking scale helpers ─────────────────────────────────────
func _apply_talk_scale(actor_id: String) -> void:
	if not _actors.has(actor_id): return
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	# Preserve mirror: scale.x sign tells us if we're mirrored right now.
	var mirror_x: float = sign(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0
	var target: Vector2 = base_scale * TALK_SCALE_MULTIPLIER
	target.x *= mirror_x
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", target, 0.12)

func _restore_base_scale(actor_id: String) -> void:
	if not _actors.has(actor_id): return
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	var mirror_x: float = sign(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0
	var target: Vector2 = base_scale
	target.x *= mirror_x
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", target, 0.12)

# ── BOB ───────────────────────────────────────────────────────
func _start_bob(actor_id: String, talking: bool) -> void:
	if not _actors.has(actor_id):
		return
	_stop_bob(actor_id)
	if not BOBBING_ENABLED:
		return
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
	# Only snap position when the sprite is actually on screen — avoids snapping
	# invisible/cleared sprites to center (which was the ghost-at-center bug).
	if data["node"].visible:
		data["node"].position = data["base_pos"]

# ── Expression swap ───────────────────────────────────────────
func _set_expression(data: Dictionary, expression: String) -> void:
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
	if tex and tex.get_width() > 0:
		var tex_size := Vector2(tex.get_width(), tex.get_height())
		var fit: float = minf(TARGET_SIZE.x / tex_size.x, TARGET_SIZE.y / tex_size.y)
		var custom_scale: float = data.get("custom_scale", 1.0)
		var new_scale: Vector2 = (Vector2.ONE * fit) * custom_scale
		# Preserve any horizontal mirror that was already applied.
		# base_scale always stores the positive (unmirrored) magnitude.
		var mirror_sign: float = sign(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0
		new_scale.x *= mirror_sign
		sprite.scale = new_scale
		data["base_scale"] = new_scale.abs()   # base_scale is always positive magnitude

# ── Emoticon system ───────────────────────────────────────────
# expression → emoticon emotion mapping
const EXPRESSION_TO_EMOTICON: Dictionary = {
	"angry":    "angry",
	"sad":      "sad",
	"scared":   "scared",
	"happy":    "happy",
	"worried":  "sad",
	"startled": "scared",
	"sneeze":   "sad",
}

func _update_emoticon_for_expression(actor_id: String, expression: String) -> void:
	# Resolve synonym first
	var resolved: String = EXPRESSION_SYNONYMS.get(expression, expression)
	var emo_name: String = EXPRESSION_TO_EMOTICON.get(resolved, "")
	if emo_name == "" or not _emoticon_textures.has(emo_name):
		# No emoticon for this expression — reset run tracking
		_emoticon_last_emotion.erase(actor_id)
		_emoticon_run_count.erase(actor_id)
		_hide_emoticon(actor_id, false)
		return

	# Run-length tracking: count consecutive identical emotions
	var last: String = _emoticon_last_emotion.get(actor_id, "")
	var run: int     = _emoticon_run_count.get(actor_id, 0)

	if emo_name == last:
		run += 1
	else:
		run = 1
		_emoticon_last_emotion[actor_id] = emo_name

	_emoticon_run_count[actor_id] = run

	if run <= 2:
		_show_emoticon(actor_id, emo_name)
	else:
		# More than 2 in a row — hide if it was showing
		_hide_emoticon(actor_id, false)

func _show_emoticon(actor_id: String, emo_name: String) -> void:
	if not _emoticon_sprites.has(actor_id): return
	if not _emoticon_textures.has(emo_name): return
	if not _actors.has(actor_id): return

	var emo_sprite: Sprite2D  = _emoticon_sprites[actor_id]
	var actor_data            = _actors[actor_id]
	var char_sprite: Sprite2D = actor_data["node"]
	var base_scale_x: float   = actor_data.get("base_scale", char_sprite.scale).x
	var live_ratio: float     = char_sprite.scale.x / base_scale_x if base_scale_x > 0.0 else 1.0
	var base_offset: Vector2  = EMOTICON_OFFSETS.get(actor_id, EMOTICON_OFFSET_DEFAULT)

	emo_sprite.texture = _emoticon_textures[emo_name]
	var tex: Texture2D = _emoticon_textures[emo_name]
	if tex and tex.get_width() > 0:
		var base_emo_scale: float = EMOTICON_DISPLAY_SIZE / float(tex.get_width())
		emo_sprite.scale = Vector2.ONE * base_emo_scale * live_ratio

	emo_sprite.position  = actor_data["base_pos"] + base_offset * live_ratio
	emo_sprite.modulate.a = 1.0
	emo_sprite.visible   = true
	# _process() will keep position/scale updated every frame from here on.

func _hide_emoticon(actor_id: String, instant: bool) -> void:
	if not _emoticon_sprites.has(actor_id): return
	var emo_sprite: Sprite2D = _emoticon_sprites[actor_id]
	if not emo_sprite.visible: return
	if instant:
		emo_sprite.visible = false
		emo_sprite.modulate.a = 0.0
	else:
		var tw: Tween = create_tween()
		tw.tween_property(emo_sprite, "modulate:a", 0.0, EMOTICON_FADE_DUR)
		tw.tween_callback(func(): emo_sprite.visible = false)

# ── Enter SFX ─────────────────────────────────────────────────
func _play_enter_sfx() -> void:
	if _enter_sfx_player and _enter_sfx_player.stream:
		_enter_sfx_player.play()

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
func _apply_scale(sprite: Sprite2D, expressions: Dictionary, custom_multiplier: float = 1.0) -> void:
	if expressions.is_empty():
		return
	var first_tex: Texture2D = expressions[expressions.keys()[0]]
	if first_tex and first_tex.get_width() > 0:
		var tex_size := Vector2(first_tex.get_width(), first_tex.get_height())
		var fit: float = minf(TARGET_SIZE.x / tex_size.x, TARGET_SIZE.y / tex_size.y)
		sprite.scale = (Vector2.ONE * fit) * custom_multiplier
		sprite.texture = first_tex

func reset_all_actors() -> void:
	_active_slots = ["", ""]
	_slot_cooccupants = {"left": [], "right": []}
	_current_speaker = ""
	_emoticon_last_emotion.clear()
	_emoticon_run_count.clear()
	for slot_i in _hide_tweens:
		_hide_tweens[slot_i].kill()
	_hide_tweens.clear()
	for actor_id in _actors:
		var data = _actors[actor_id]
		_stop_bob(actor_id)
		_hide_emoticon(actor_id, true)
		data["node"].visible = false
		data["node"].modulate.a = 0.0
		data["talking"] = false
