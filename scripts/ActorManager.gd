extends Node2D

const TARGET_SIZE := Vector2(500, 500)
const BOB_IDLE_HEIGHT  := 7.0
const BOB_IDLE_SPEED   := 0.9
const BOB_TALK_HEIGHT  := 14.0
const BOB_TALK_SPEED   := 0.35

# ── Pop-in tuning ─────────────────────────────────────────────
# The pop-in grows the sprite from POPIN_START_SCALE up to its base scale,
# overshooting slightly past the target (via TRANS_BACK + EASE_OUT) before
# settling — a classic snappy "pop in" feel. Keeping the start slightly below
# 1.0 avoids the old bug where starting ABOVE 1.0 and shrinking looked like the
# character was deflating on entry.
const POPIN_START_SCALE: float = 0.6   # ← ADJUST: starting scale (fraction of base)
const POPIN_DURATION:    float = 0.35  # ← ADJUST: seconds for pop-in animation

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

# ── Two-actor same-side positioning ──────────────────────────
# How far the existing actor slides inward when a second actor joins the same slot.
# "Inward" = toward screen center. Adjust this to taste.
const COOCCUPANT_INNER_OFFSET: float = 175.0

# Per-slot occupant tracking (used for two-actor spreading).
var _slot_cooccupants: Dictionary = {"left": [], "right": []}

const PAIRED_ACTORS: Dictionary = {
	"Scotch": "Scotch",
	"Tofu":   "Scotch",
}
const PAIRED_LAYOUT: Dictionary = {
	"Scotch": ["Scotch", "Tofu"],
}

const PREFER_LEFT_ACTORS: Array = ["Marty"]

# Actors flipped when on the LEFT (their art faces right by default).
const MIRROR_LEFT_ACTORS: Array = ["Buttons"]

# Actors flipped when on the RIGHT (their art faces left by default).
const MIRROR_RIGHT_ACTORS: Array = ["Marty"]

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

# Per-actor hide tween tracking — lets a new appear kill a stale fade-out tween.
# Keyed by actor_id so co-occupants (two actors sharing a slot) never clobber
# each other's hide animation.
var _actor_hide_tweens: Dictionary = {}  # actor_id (String) → Tween

# Global hide counter + appear queue — ensures no actor enters while any is still leaving.
var _hide_count: int = 0
var _pending_appears: Array = []  # Array[Callable]

# Per-actor pop-in tween tracking — lets talk-scale kill a running pop-in so
# they don't fight over sprite.scale simultaneously.
var _popin_tweens: Dictionary = {}  # actor_id (String) → Tween
# Untracked talk/restore scale tweens were fighting each other; track them so
# each new one kills the previous before starting.
var _scale_tweens: Dictionary = {}  # actor_id (String) → Tween
# Animations queued to play once a pop-in finishes (enter + anim same passage).
var _pending_anims: Dictionary = {}  # actor_id (String) → anim name (String)

# Emoticon sprites — one per actor
var _emoticon_sprites: Dictionary = {}   # actor_id → Sprite2D

# Preloaded emoticon textures (loaded on first use)
var _emoticon_textures: Dictionary = {}  # emotion_name → Texture2D

# Emoticon run tracking — only show for first 2 consecutive identical emotions
var _emoticon_last_emotion: Dictionary = {}   # actor_id → last emotion shown
var _emoticon_run_count: Dictionary    = {}   # actor_id → consecutive count

# Enter SFX player
var _enter_sfx_player: AudioStreamPlayer = null

func _flush_pending_appears() -> void:
	var pending := _pending_appears.duplicate()
	_pending_appears.clear()
	for fn in pending:
		fn.call()

func _ready() -> void:
	z_index = 10  # always above background cross-fade (BG sprites use z_index 0–1)
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
		# Use absolute value so a mirrored (negative scale.x) sprite doesn't flip
		# the emoticon position or scale.
		var live_ratio: float = abs(char_sprite.scale.x) / base_scale_x
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
	_hide_count = 0
	_pending_appears.clear()
	# Kill ALL pending tweens so their callbacks never fire after this clear.
	for aid in _actor_hide_tweens:
		_actor_hide_tweens[aid].kill()
	_actor_hide_tweens.clear()
	for pid in _popin_tweens:
		_popin_tweens[pid].kill()
	_popin_tweens.clear()
	for sid in _scale_tweens:
		_scale_tweens[sid].kill()
	_scale_tweens.clear()
	_pending_anims.clear()
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
	if instant:
		if PAIRED_ACTORS.has(actor_id):
			call_deferred("_on_paired_appear", actor_id, expression, position, true)
			return
		var data = _actors[actor_id]
		var sprite: Sprite2D = data["node"]

		# Update slot ownership — clear any stale entry first so actor is never in two slots.
		for i in 2:
			if _active_slots[i] == actor_id:
				_active_slots[i] = ""
		if position == "left":
			_active_slots[0] = actor_id
		elif position == "right":
			_active_slots[1] = actor_id

		# Rebuild co-occupant list and compute spread positions — same logic as
		# the animated path so two actors on the same side end up correctly spaced.
		var anchor: Vector2 = POSITIONS.get(position, POSITIONS["center"])
		if position in _slot_cooccupants:
			var occ: Array = _slot_cooccupants[position]
			if not occ.has(actor_id):
				occ.append(actor_id)
			while occ.size() > 2:
				occ.pop_front()

		var target: Vector2 = anchor
		if position in _slot_cooccupants:
			var occ: Array = _slot_cooccupants[position]
			if occ.size() == 2:
				var inward_x: float = COOCCUPANT_INNER_OFFSET if position == "left" else -COOCCUPANT_INNER_OFFSET
				var inner: Vector2  = anchor + Vector2(inward_x, 0.0)
				if occ[occ.size() - 1] == actor_id:
					# Latest arrival → outer anchor; push the existing occupant inward.
					target = anchor
					var other_id: String = occ[0]
					if _actors.has(other_id) and _actors[other_id]["node"].visible:
						_actors[other_id]["base_pos"]    = inner
						_actors[other_id]["node"].position = inner
				else:
					target = inner

		data["base_pos"]  = target
		data["talking"]   = false
		sprite.position   = target
		sprite.visible    = true
		sprite.modulate.a = 1.0
		_set_expression(data, expression)
		_apply_mirror(actor_id, position)
		_stop_bob(actor_id)
		_refresh_cooccupant_zorder(position)
		return

	# ── ANIMATED PATH ────────────────────────────────────────────────────────────
	if PAIRED_ACTORS.has(actor_id):
		# Defer so the signal stack fully unwinds before we touch sprite state.
		call_deferred("_on_paired_appear", actor_id, expression, position, false)
		return

	var pos_key: String = position
	if pos_key == "" or pos_key == "center":
		if _active_slots[0] == "" or _active_slots[0] == actor_id:
			pos_key = "left"
		elif _active_slots[1] == "" or _active_slots[1] == actor_id:
			pos_key = "right"
		else:
			pos_key = "right"

	# Slot ownership is claimed inside _do_appear_at AFTER the hide-count gate,
	# so a queued appear doesn't pre-empt a still-departing actor's slot.
	_do_appear_at(actor_id, expression, pos_key, false)


# ── Paired-actor appear ───────────────────────────────────────
var _pair_slots: Dictionary = {}
var _pair_expressions: Dictionary = {}

func _on_paired_appear(actor_id: String, expression: String, position: String, instant: bool) -> void:
	var pair_id: String = PAIRED_ACTORS[actor_id]

	# Resolve slot key.
	var slot_key: String = _pair_slots.get(pair_id, "")
	if slot_key == "" or position != "":
		if position != "" and position != "center":
			slot_key = position
		else:
			slot_key = "right"   # Scotch/Tofu default to right
		_pair_slots[pair_id] = slot_key

	# Record this member's expression before the gate so both expressions are
	# available when _do_paired_appear_now eventually runs.
	if not _pair_expressions.has(pair_id):
		_pair_expressions[pair_id] = {}
	_pair_expressions[pair_id][actor_id] = expression

	# Gate: wait for any departing actors to finish before entering.
	if _hide_count > 0 and not instant:
		var cid := actor_id; var cex := expression; var cslot := slot_key; var cinst := instant
		_pending_appears.append(func(): _do_paired_appear_now(cid, cex, cslot, cinst))
		return

	_do_paired_appear_now(actor_id, expression, slot_key, instant)

# ── Inner paired-appear (runs after hides drain) ──────────────
func _do_paired_appear_now(actor_id: String, expression: String, slot_key: String, instant: bool) -> void:
	var pair_id: String = PAIRED_ACTORS[actor_id]
	# PAIRED_LAYOUT["Scotch"] = ["Scotch", "Tofu"]
	# layout[0] = Scotch (left of pair), layout[1] = Tofu (right of pair = outermost when on right side)
	var layout: Array   = PAIRED_LAYOUT.get(pair_id, [pair_id, actor_id])

	# Claim slot ownership now that hides are done.
	if slot_key == "left":
		_active_slots[0] = pair_id
	else:
		_active_slots[1] = pair_id

	if not _pair_expressions.has(pair_id):
		_pair_expressions[pair_id] = {}

	var base_pos: Vector2  = POSITIONS.get(slot_key, POSITIONS["right"])
	var left_member:  String = layout[0]   # Scotch — left of the pair
	var right_member: String = layout[1]   # Tofu   — right of the pair (outermost on right side)

	for member_id in [left_member, right_member]:
		if not _actors.has(member_id):
			continue
		var is_left_of_pair: bool = (member_id == left_member)
		var offset: Vector2 = -PAIRED_OFFSET * 0.5 if is_left_of_pair else PAIRED_OFFSET * 0.5
		var member_pos: Vector2 = base_pos + offset
		var data = _actors[member_id]

		if member_id == actor_id:
			# New arrival — full enter.
			var member_expr: String = _pair_expressions[pair_id].get(member_id, expression)
			data["base_pos"]      = member_pos
			data["node"].position = member_pos
			data["node"].visible  = true
			_stop_bob(member_id)
			_set_expression(data, member_expr)
			_apply_mirror(member_id, slot_key)
			if instant:
				data["node"].modulate.a = 1.0
				_start_bob(member_id, false)
			else:
				_play_enter_sfx()
				_do_popin(member_id)
		elif data["node"].visible:
			# Partner already on stage: update base_pos and slide if needed.
			var prev_pos: Vector2 = data["base_pos"]
			data["base_pos"] = member_pos
			if prev_pos.distance_to(member_pos) > 1.0:
				_stop_bob(member_id)
				if _popin_tweens.has(member_id):
					# Still entering — snap position so pop-in lands correctly.
					data["node"].position = member_pos
				else:
					var sid: String = member_id
					var stw: Tween = create_tween()
					stw.tween_property(data["node"], "position", member_pos, 0.25) 						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					stw.tween_callback(func():
						if _actors.has(sid) and _actors[sid]["node"].visible:
							_start_bob(sid, _actors[sid].get("talking", false)))
		# else: partner not yet on stage — positions itself on its own appear call.

	# Refresh bob state for visible members.
	for member_id in [left_member, right_member]:
		if not _actors.has(member_id) or not _actors[member_id]["node"].visible:
			continue
		var is_speaker: bool = (member_id == actor_id)
		_actors[member_id]["talking"] = is_speaker
		if not _popin_tweens.has(member_id):
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
			_hide_count += 1
			var tw = create_tween()
			tw.set_parallel(true)
			tw.tween_property(sprite, "position", slide_target, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
			tw.chain().tween_callback(func():
				sprite.visible = false
				sprite.position = home_pos
				_hide_count = max(0, _hide_count - 1)
				if _hide_count == 0:
					call_deferred("_flush_pending_appears")
			)
	_pair_slots.erase(pair_id)
	_pair_expressions.erase(pair_id)
	if _active_slots[0] == pair_id: _active_slots[0] = ""
	if _active_slots[1] == pair_id: _active_slots[1] = ""

# When a co-occupant actor is speaking, bring them visually in front of their
# slot-mate so they're never hidden behind the other character.
func _elevate_speaker_zorder(actor_id: String) -> void:
	for slot in ["left", "right"]:
		var occ: Array = _slot_cooccupants.get(slot, [])
		if occ.has(actor_id) and occ.size() >= 2:
			if _actors.has(actor_id):
				_actors[actor_id]["node"].z_index = 2
				if _emoticon_sprites.has(actor_id):
					_emoticon_sprites[actor_id].z_index = 12
			return
	# Solo actor or center — leave z_index at its current value

func _refresh_cooccupant_zorder(slot: String) -> void:
	var occ: Array = _slot_cooccupants.get(slot, [])
	if occ.size() == 1:
		var id: String = occ[0]
		if _actors.has(id):
			_actors[id]["node"].z_index = 0
		if _emoticon_sprites.has(id):
			_emoticon_sprites[id].z_index = 10
	elif occ.size() == 2:
		# occ[0] = earlier arrival = inner (pushed toward center, behind)
		# occ[1] = later arrival  = outer (at anchor, in front)
		var inner_id: String = occ[0]
		var outer_id: String = occ[1]
		if _actors.has(inner_id):
			_actors[inner_id]["node"].z_index = 0
			if _emoticon_sprites.has(inner_id):
				# z=0 puts inner emoticon behind outer sprite (z=1)
				_emoticon_sprites[inner_id].z_index = 0
		if _actors.has(outer_id):
			_actors[outer_id]["node"].z_index = 1
			if _emoticon_sprites.has(outer_id):
				_emoticon_sprites[outer_id].z_index = 11

func _do_appear_at(actor_id: String, expression: String, pos_key: String, instant: bool):
	# ── Gate: queue immediately if any actor is still leaving. ───────────────
	# MUST be before slot/cooccupant mutation so departing actors are not evicted
	# prematurely, and so the new actor's slot is claimed with a clean slate.
	if _hide_count > 0 and not instant:
		var cid := actor_id; var cex := expression; var cpos := pos_key
		_pending_appears.append(func(): _do_appear_at(cid, cex, cpos, false))
		return

	# Claim _active_slots now (hides are done / instant).
	for i in 2:
		if _active_slots[i] == actor_id:
			_active_slots[i] = ""
	if pos_key == "left":
		_active_slots[0] = actor_id
	elif pos_key == "right":
		_active_slots[1] = actor_id

	var anchor: Vector2 = POSITIONS.get(pos_key, POSITIONS["center"])

	# ── Two-actor same-side positioning ──────────────────────────────────────
	for other_side in ["left", "right"]:
		if other_side != pos_key:
			_slot_cooccupants[other_side].erase(actor_id)
	if pos_key in _slot_cooccupants:
		var occ: Array = _slot_cooccupants[pos_key]
		if not occ.has(actor_id):
			occ.append(actor_id)
		while occ.size() > 2:
			occ.pop_front()
	_refresh_cooccupant_zorder(pos_key)

	var my_base: Vector2 = anchor
	if pos_key in _slot_cooccupants:
		var occ: Array = _slot_cooccupants[pos_key]
		if occ.size() == 2:
			var inward_x: float = COOCCUPANT_INNER_OFFSET if pos_key == "left" else -COOCCUPANT_INNER_OFFSET
			var inner: Vector2  = anchor + Vector2(inward_x, 0.0)
			for i in occ.size():
				var oid: String = occ[i]
				if oid == actor_id:
					my_base = anchor
				elif _actors.has(oid) and _actors[oid]["node"].visible:
					var slide_oid: String = oid
					var odata = _actors[oid]
					odata["base_pos"] = inner
					_stop_bob(oid)
					var slide_tw: Tween = create_tween()
					slide_tw.tween_property(odata["node"], "position", inner, 0.35) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					slide_tw.tween_callback(func():
						if _actors.has(slide_oid) and _actors[slide_oid]["node"].visible:
							_start_bob(slide_oid, _actors[slide_oid].get("talking", false))
					)

	_do_appear_at_immediate(actor_id, expression, pos_key, my_base, instant)

func _do_appear_at_immediate(actor_id: String, expression: String, pos_key: String, base: Vector2, instant: bool):
	# Kill any stale hide tween so its alpha callback can't fade this actor out after appearing.
	if _actor_hide_tweens.has(actor_id):
		_actor_hide_tweens[actor_id].kill()
		_actor_hide_tweens.erase(actor_id)
		# The killed tween's decrement callback will never fire, so compensate here.
		_hide_count = max(0, _hide_count - 1)
		if _hide_count == 0:
			call_deferred("_flush_pending_appears")
	# Kill any running pop-in or scale tween so they don't conflict with the new appearance.
	if _popin_tweens.has(actor_id):
		_popin_tweens[actor_id].kill()
		_popin_tweens.erase(actor_id)
	if _scale_tweens.has(actor_id):
		_scale_tweens[actor_id].kill()
		_scale_tweens.erase(actor_id)
	var data = _actors[actor_id]
	var sprite = data["node"]
	sprite.modulate.a = 1.0
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
# MIRROR_LEFT_ACTORS: art faces right by default → flip when on left.
# MIRROR_RIGHT_ACTORS: art faces left by default → flip when on right.
# base_scale is always stored as positive magnitude.
func _apply_mirror(actor_id: String, pos_key: String) -> void:
	if not _actors.has(actor_id):
		return
	var mirror: float
	if MIRROR_LEFT_ACTORS.has(actor_id):
		mirror = -1.0 if pos_key == "left" else 1.0
	elif MIRROR_RIGHT_ACTORS.has(actor_id):
		mirror = -1.0 if pos_key == "right" else 1.0
	else:
		return
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	sprite.scale = Vector2(base_scale.x * mirror, base_scale.y)


# ── Pop-in animation ─────────────────────────────────────────
func _do_popin(actor_id: String) -> void:
	# Kill any in-flight pop-in for this actor so we don't fight an earlier one
	# (e.g. two actors entering on the same frame in a paired arrangement).
	if _popin_tweens.has(actor_id):
		_popin_tweens[actor_id].kill()
		_popin_tweens.erase(actor_id)

	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	data["base_scale"] = base_scale

	var mirror_x: float = sign(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0
	var target_scale: Vector2 = Vector2(base_scale.x * mirror_x, base_scale.y)

	sprite.modulate.a = 1.0
	# Start smaller than base and grow up to target — TRANS_BACK + EASE_OUT
	# overshoots slightly past the target for a snappy "pop" feel.
	sprite.scale = target_scale * POPIN_START_SCALE

	var tw: Tween = create_tween()
	_popin_tweens[actor_id] = tw
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", target_scale, POPIN_DURATION)
	var cap_id: String = actor_id
	tw.tween_callback(func():
		_popin_tweens.erase(cap_id)
		if not _actors.has(cap_id):
			return
		var is_talking: bool = _actors[cap_id].get("talking", false)
		_start_bob(cap_id, is_talking)
		# If dialogue arrived while this actor was still queued/popping-in,
		# apply all speaker visuals now that they are actually on screen.
		if _current_speaker == cap_id:
			_actors[cap_id]["node"].modulate.a = 1.0
			_elevate_speaker_zorder(cap_id)
			_apply_talk_scale(cap_id)
		if _pending_anims.has(cap_id):
			var queued: String = _pending_anims[cap_id]
			_pending_anims.erase(cap_id)
			_on_actor_animate(cap_id, queued)
	)

func _on_actor_hide(actor_id: String) -> void:
	if not _actors.has(actor_id):
		if PAIRED_LAYOUT.has(actor_id):
			_on_paired_hide(actor_id)
		return

	# No-op if actor is already off screen (e.g. redundant hide at a convergent passage).
	if not _actors[actor_id]["node"].visible:
		return

	# Kill any previous hide tween for this actor so its alpha callback can't fire later.
	# Compensate _hide_count since the killed tween's decrement callback won't fire.
	if _actor_hide_tweens.has(actor_id):
		_actor_hide_tweens[actor_id].kill()
		_actor_hide_tweens.erase(actor_id)
		_hide_count = max(0, _hide_count - 1)

	# Determine slot from the actor's actual base position — more reliable than
	# _active_slots which can hold stale entries when tweens were killed early.
	var data = _actors[actor_id]
	var slot_index: int = -1
	var base_x: float = data["base_pos"].x
	if base_x < 640.0:
		slot_index = 0
	elif base_x > 640.0:
		slot_index = 1
	# Don't clear the slot yet — keep it blocked until the slide-out finishes.

	_stop_bob(actor_id)
	_hide_emoticon(actor_id, false)

	# Paired actors are registered individually, so they take this non-paired hide
	# path. Clean up pair bookkeeping so a later re-entry doesn't inherit stale slot
	# or expression data.
	if PAIRED_ACTORS.has(actor_id):
		var pair_id: String = PAIRED_ACTORS[actor_id]
		if _pair_expressions.has(pair_id):
			_pair_expressions[pair_id].erase(actor_id)
			if _pair_expressions[pair_id].is_empty():
				_pair_expressions.erase(pair_id)
				_pair_slots.erase(pair_id)

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

	_hide_count += 1
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "position", slide_target, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)

	# ── Remove from co-occupant tracking; slide remaining solo back to anchor ─
	for side in ["left", "right"]:
		if _slot_cooccupants[side].has(actor_id):
			_slot_cooccupants[side].erase(actor_id)
			_refresh_cooccupant_zorder(side)
			if _slot_cooccupants[side].size() == 1:
				var solo_id: String = _slot_cooccupants[side][0]
				if _actors.has(solo_id) and _actors[solo_id]["node"].visible:
					var solo_anchor: Vector2 = POSITIONS.get(side, POSITIONS["center"])
					var solo_data = _actors[solo_id]
					solo_data["base_pos"] = solo_anchor
					_stop_bob(solo_id)
					var slide_solo_id: String = solo_id
					var solo_tw: Tween = create_tween()
					solo_tw.tween_property(solo_data["node"], "position", solo_anchor, 0.35) \
						.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
					solo_tw.tween_callback(func():
						if _actors.has(slide_solo_id) and _actors[slide_solo_id]["node"].visible:
							_start_bob(slide_solo_id, solo_data.get("talking", false))
					)
			break

	var hide_actor_id: String = actor_id  # capture for lambda
	tw.chain().tween_callback(func():
		sprite.visible = false
		sprite.position = home_pos
		# Only clear the slot if it still belongs to this actor.
		# (A new actor may have already claimed it while the slide-out ran.)
		if slot_index >= 0 and _active_slots[slot_index] == hide_actor_id:
			_active_slots[slot_index] = ""
		_actor_hide_tweens.erase(hide_actor_id)
		_hide_count = max(0, _hide_count - 1)
		if _hide_count == 0:
			call_deferred("_flush_pending_appears")
	)

	_actor_hide_tweens[actor_id] = tw


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
	_apply_mirror(actor_id, position)
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
	# If the actor is still entering (pop-in running), queue the animation so
	# it plays immediately after the entry finishes rather than fighting it.
	if _popin_tweens.has(actor_id):
		_pending_anims[actor_id] = anim
		return
	var sprite: Sprite2D = _actors[actor_id]["node"]
	match anim:
		"shake":   _shake_sprite(sprite)
		"hop":     _hop_in_place(sprite)
		"bounce":  _bounce_sprite(sprite)
		"pulse":   _pulse_sprite(sprite)
		"spin":    _spin_sprite(sprite)
		"excite":  _excite_sprite(actor_id)
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
		# Restore previous speaker's slot z-order now that they stopped talking.
		for slot in ["left", "right"]:
			if _slot_cooccupants.get(slot, []).has(_current_speaker):
				_refresh_cooccupant_zorder(slot)
				break

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
		# Only apply visual talk effects if the speaker is actually on screen.
		# If they are still queued in _pending_appears (hidden, waiting for a
		# departing actor to finish), touching modulate.a here causes the
		# ghost-at-center bug. Effects are applied in _do_popin's callback instead.
		if _actors[speaker]["node"].visible:
			_actors[speaker]["node"].modulate.a = 1.0
			_start_bob(speaker, true)
			_elevate_speaker_zorder(speaker)
			_apply_talk_scale(speaker)

# ── Talking scale helpers ─────────────────────────────────────
func _apply_talk_scale(actor_id: String) -> void:
	if not _actors.has(actor_id): return
	if _popin_tweens.has(actor_id):
		_popin_tweens[actor_id].kill()
		_popin_tweens.erase(actor_id)
		var snap_data = _actors[actor_id]
		var snap_sprite: Sprite2D = snap_data["node"]
		snap_sprite.modulate.a = 1.0
		var snap_base: Vector2 = snap_data["base_scale"]
		var snap_mirror: float = sign(snap_sprite.scale.x) if snap_sprite.scale.x != 0.0 else 1.0
		snap_sprite.scale = Vector2(snap_base.x * snap_mirror, snap_base.y)
	if _scale_tweens.has(actor_id):
		_scale_tweens[actor_id].kill()
		_scale_tweens.erase(actor_id)
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	sprite.modulate.a = 1.0
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	var mirror_x: float = sign(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0
	var target: Vector2 = base_scale * TALK_SCALE_MULTIPLIER
	target.x *= mirror_x
	var tw: Tween = create_tween()
	_scale_tweens[actor_id] = tw
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", target, 0.12)
	tw.tween_callback(func(): _scale_tweens.erase(actor_id))

func _restore_base_scale(actor_id: String) -> void:
	if not _actors.has(actor_id): return
	if _popin_tweens.has(actor_id):
		_popin_tweens[actor_id].kill()
		_popin_tweens.erase(actor_id)
		_actors[actor_id]["node"].modulate.a = 1.0
	if _scale_tweens.has(actor_id):
		_scale_tweens[actor_id].kill()
		_scale_tweens.erase(actor_id)
	var data = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	sprite.modulate.a = 1.0
	var base_scale: Vector2 = data.get("base_scale", sprite.scale.abs())
	var mirror_x: float = sign(sprite.scale.x) if sprite.scale.x != 0.0 else 1.0
	var target: Vector2 = base_scale
	target.x *= mirror_x
	var tw: Tween = create_tween()
	_scale_tweens[actor_id] = tw
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", target, 0.12)
	tw.tween_callback(func(): _scale_tweens.erase(actor_id))

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
	# abs() keeps the ratio positive even when the sprite is horizontally mirrored.
	var live_ratio: float     = abs(char_sprite.scale.x) / base_scale_x if base_scale_x > 0.0 else 1.0
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

func _excite_sprite(actor_id: String) -> void:
	if not _actors.has(actor_id): return
	var data   = _actors[actor_id]
	var sprite: Sprite2D = data["node"]
	var origin: Vector2  = data["base_pos"]
	var h: float = 14.0   # bounce height in pixels
	var d: float = 0.10   # duration of each up/down segment
	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "position", origin + Vector2(0, -h),        d).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", origin,                          d).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "position", origin + Vector2(0, -h * 0.7),  d).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", origin,                          d).set_ease(Tween.EASE_IN)

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
	_hide_count = 0
	_pending_appears.clear()
	for aid in _actor_hide_tweens:
		_actor_hide_tweens[aid].kill()
	_actor_hide_tweens.clear()
	for pid in _popin_tweens:
		_popin_tweens[pid].kill()
	_popin_tweens.clear()
	for actor_id in _actors:
		var data = _actors[actor_id]
		_stop_bob(actor_id)
		_hide_emoticon(actor_id, true)
		data["node"].visible = false
		data["node"].modulate.a = 0.0
		data["talking"] = false
