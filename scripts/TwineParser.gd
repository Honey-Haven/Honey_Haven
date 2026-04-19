extends Node
class_name TwineParser

# ══════════════════════════════════════════════════════════════════════════════
#  TwineParser
#  Converts a Twine-to-JSON export into the packet array consumed by VNLogic.
#
#  TAG CONVENTIONS (space-separated in the passage "tags" field)
#  ─────────────────────────────────────────────────────────────
#  <n>-enter             → actor enters on their default side
#  <n>-enter-left        → actor enters on the left
#  <n>-enter-right       → actor enters on the right
#  <n>-enter-middle      → actor enters at centre
#  <n>-leave             → actor leaves the scene
#  <n>-<expression>      → sets that actor's sprite/expression
#                             (e.g. marty-angry, wolf-happy)
#  <n>-speaker           → this actor is the speaker for this passage
#  Narrator                 → no name-tag shown (maps to speaker "")
#  Demon                    → name tag shows "Demon", no sprite on screen
#  must_visit               → this passage-name is added to the must-visit set
#  minigame_start           → emits a minigame_start packet
#  minigame_end             → emits a minigame_end packet (no-op marker)
#  flash                    → flashes the screen black before this passage's dialogue
#
#  DEFAULT POSITIONS
#  ─────────────────
#  Marty always defaults to LEFT (see ActorManager.PREFER_LEFT_ACTORS).
#  All other actors default to RIGHT unless -left / -right / -middle is given.
#
#  EXPRESSION MAP
#  ──────────────
#  Keys are the raw expression words used after the hyphen in tags.
#  Values are the expression IDs registered in ActorManager / VNController.
# ══════════════════════════════════════════════════════════════════════════════

const EXPRESSION_MAP: Dictionary = {
	"neutral":   "neutral",
	"happy":     "happy",
	"sad":       "sad",
	"worried":   "worried",
	"startled":  "startled",
	"angry":     "angry",
	"surprised": "surprised",
	"sneezing":  "sneezing",
	"scared":    "scared",
	"smile":     "smile",
	"frown":     "frown",
	"baby":      "baby",
}

# Known actor names (lower-case). Extend as you add characters.
const KNOWN_ACTORS: Array = [
	"marty", "matthew", "buttons", "peaches", "mochi", "chester",
	"scotch", "tofu", "barnaby", "jane", "muffins", "demon",
	"narrator", "peanut", "smith", "wolf", "stranger",
]

# Actor aliases: map tag name → canonical actor_id.
const ACTOR_ALIASES: Dictionary = {}

# Tags that carry structural meaning and should never be mistaken for actors
# or expressions.
const STRUCTURAL_TAGS: Array = [
	"must_visit", "minigame_start", "minigame_end", "flash",
	"hand-outstretched-sprite",
]

# Populated at runtime via register_background() in VNController.
static var BACKGROUND_MAP: Dictionary = {}
static var SFX_MAP: Dictionary = {}
static var BGM_MAP := {}
# Maps overlay-sprite tag names → resource paths (set from VNController).
static var OVERLAY_SPRITE_MAP: Dictionary = {}

static func register_overlay_sprite(tag: String, path: String) -> void:
	OVERLAY_SPRITE_MAP[tag.to_lower().replace("-", "_")] = path

static func register_bgm(tag: String, path: String, volume: float = 0.0) -> void:
	BGM_MAP[tag.to_lower().replace("-", "_")] = {
		"path": path,
		"volume": volume
		}

static func register_sfx(tag: String, path: String) -> void:
	SFX_MAP[tag.to_lower().replace("-", "_")] = path

static func register_background(tag: String, path: String) -> void:
	BACKGROUND_MAP[tag.to_lower()] = path


# ── Public entry point ────────────────────────────────────────────────────────
static func parse(twine_json: Dictionary) -> Array:
	var passages: Array = twine_json.get("passages", [])

	var passage_map: Dictionary = {}
	for p in passages:
		passage_map[p["name"].strip_edges()] = p

	var start_name: String = _find_start(passages, passage_map)

	var ctx := _ParseContext.new()
	ctx.passage_map = passage_map
	_walk(start_name, ctx)

	return ctx.packets


# ══════════════════════════════════════════════════════════════════════════════
#  Internal walk
# ══════════════════════════════════════════════════════════════════════════════

class _ParseContext:
	var passage_map:     Dictionary = {}
	var packets:         Array      = []
	var visited:         Dictionary = {}
	var on_stage:        Dictionary = {}
	var current_bg:      String     = ""
	var must_visit_sets: Dictionary = {}
	var current_hub:     String     = ""
	var _last_had_overlay: bool     = false


static func _walk(name: String, ctx: _ParseContext) -> void:
	var clean_name: String = name.strip_edges()

	if ctx.visited.has(clean_name):
		ctx.packets.append({"type": "jump", "label": _label_for(clean_name)})
		return

	if not ctx.passage_map.has(clean_name):
		push_error("TwineParser: passage '%s' not found." % clean_name)
		return

	ctx.visited[clean_name] = true

	var passage: Dictionary = ctx.passage_map[clean_name]
	var raw_tags: Array     = _split_tags(passage.get("tags", ""))
	var links: Array        = passage.get("links", [])
	var text: String        = passage.get("cleanText", "").strip_edges()

	ctx.packets.append({"type": "label", "name": _label_for(clean_name)})

	var parsed := _parse_actor_tags(raw_tags)

	var speaker:    String     = parsed["speaker"]
	var enters:     Array      = parsed["enters"]
	var leaves:     Array      = parsed["leaves"]
	var expression: String     = parsed["expressions"].get(speaker.to_lower(), "")

	# ── Background tag ────────────────────────────────────────────────────────
	var bg_tag: String = _get_background_tag(raw_tags)
	if bg_tag != "" and bg_tag != ctx.current_bg:
		ctx.current_bg = bg_tag
		ctx.packets.append({
			"type":       "background",
			"path":       BACKGROUND_MAP[bg_tag],
			"transition": "fade",
		})

	# ── Flash tag — screen flash BEFORE dialogue ──────────────────────────────
	if raw_tags.has("flash"):
		ctx.packets.append({"type": "screen_flash"})

	# ── Overlay sprite tag (e.g. hand-outstretched-sprite) ────────────────────
	var overlay_tag: String = _get_overlay_sprite_tag(raw_tags)
	if overlay_tag != "":
		var sprite_path: String = OVERLAY_SPRITE_MAP.get(overlay_tag, "")
		ctx.packets.append({
			"type": "overlay_sprite",
			"show": true,
			"path": sprite_path,
		})
	elif ctx._last_had_overlay:
		# Previous passage had an overlay — hide it now
		ctx.packets.append({"type": "overlay_sprite", "show": false})
	ctx._last_had_overlay = (overlay_tag != "")

	# ── Audio Tags ────────────────────────────────────────────────────────────
	for t in raw_tags:
		var clean_t = t.replace("-", "_")

		if BGM_MAP.has(clean_t):
			var bgm_data = BGM_MAP[clean_t]
			ctx.packets.append({
				"type":   "bgm",
				"action": "play",
				"path":   bgm_data["path"],
				"volume": bgm_data["volume"],
				"fade":   0.1
			})
		elif clean_t == "stop_bgm":
			ctx.packets.append({
				"type":   "bgm",
				"action": "stop",
				"fade":   1.0
			})

		if SFX_MAP.has(clean_t):
			ctx.packets.append({
				"type": "sfx",
				"path": SFX_MAP[clean_t]
			})

	# ── Actor leaves ──────────────────────────────────────────────────────────
	for actor_id in leaves:
		if ctx.on_stage.has(actor_id):
			ctx.packets.append({"type": "actor_hide", "actor_id": actor_id})
			ctx.on_stage.erase(actor_id)

	# ── Actor enters ──────────────────────────────────────────────────────────
	for enter_info in enters:
		var actor_id:   String = enter_info["actor_id"]
		var position:   String = enter_info["position"]
		var enter_expr: String = enter_info["expression"]
		if enter_expr == "":
			enter_expr = "neutral"
		if not ctx.on_stage.has(actor_id):
			ctx.packets.append({
				"type":       "appear",
				"actor_id":   actor_id,
				"expression": enter_expr,
				"position":   position,
			})
			ctx.on_stage[actor_id] = true

	# ── Expression update for actors already on stage ─────────────────────────
	for actor_lower in parsed["expressions"]:
		var actor_id: String
		if ACTOR_ALIASES.has(actor_lower):
			actor_id = ACTOR_ALIASES[actor_lower]
		else:
			actor_id = actor_lower.substr(0, 1).to_upper() + actor_lower.substr(1)

		if ctx.on_stage.has(actor_id):
			var just_entered: bool = false
			for e in enters:
				if e["actor_id"] == actor_id:
					just_entered = true
					break
			if not just_entered:
				var new_expr: String = parsed["expressions"][actor_lower]
				if new_expr != "":
					ctx.packets.append({
						"type":       "actor_expression",
						"actor_id":   actor_id,
						"expression": new_expr,
					})

	# ── Dialogue / narrator line ──────────────────────────────────────────────
	if text != "" and not _is_structural_only(raw_tags, text):
		ctx.packets.append({
			"type":       "dialogue",
			"speaker":    _display_speaker(speaker, raw_tags),
			"text":       text,
			"expression": expression,
			"word_shake": false,
		})

	# ── minigame_start tag ────────────────────────────────────────────────────
	if raw_tags.has("minigame_start"):
		ctx.packets.append({
			"type": "minigame",
			"id":   clean_name,
			"data": {},
		})

	# ── Route children ────────────────────────────────────────────────────────
	_route_children(clean_name, links, raw_tags, ctx)


# ── Routing logic ─────────────────────────────────────────────────────────────

static func _route_children(
		parent_name: String,
		links: Array,
		raw_tags: Array,
		ctx: _ParseContext) -> void:

	if links.is_empty():
		return

	var mv_children: Array   = []
	var free_children: Array = []
	for lnk in links:
		var target: String  = lnk.get("passageName", "").strip_edges()
		var child_p         = ctx.passage_map.get(target, {})
		var child_tags: Array = _split_tags(child_p.get("tags", ""))
		if child_tags.has("must_visit"):
			mv_children.append(target)
		else:
			free_children.append(target)

	if not mv_children.is_empty():
		var set_dict: Dictionary = {}
		for c in mv_children:
			set_dict[c] = false
		ctx.must_visit_sets[parent_name] = set_dict

		ctx.packets.append({
			"type":     "must_visit_hub",
			"hub":      _label_for(parent_name),
			"children": mv_children.map(func(n): return _label_for(n)),
		})

		var stage_before_mv: Dictionary = ctx.on_stage.duplicate()
		for child in mv_children:
			ctx.on_stage = stage_before_mv.duplicate()
			_walk(child, ctx)

		if not free_children.is_empty():
			ctx.on_stage = stage_before_mv.duplicate()
			_walk(free_children[0], ctx)

		return

	# ── Choice ────────────────────────────────────────────────────────────────
	var is_choice: bool = _links_are_choices(links)

	if is_choice and links.size() > 1:
		var choice_entries: Array    = []
		var silent_continuation: String = ""
		for lnk in links:
			var label_text: String = lnk.get("linkText", "").strip_edges()
			var target:     String = lnk.get("passageName", "").strip_edges()
			if label_text == target:
				silent_continuation = target
				continue
			label_text = label_text.trim_prefix("\"").trim_suffix("\"")
			choice_entries.append({
				"label": label_text,
				"goto":  _label_for(target),
			})
		ctx.packets.append({
			"type":         "choice",
			"prompt":       "",
			"choices":      choice_entries,
			"continuation": _label_for(silent_continuation),
		})
		var stage_before_choice: Dictionary = ctx.on_stage.duplicate()
		for lnk in links:
			var target: String = lnk.get("passageName", "").strip_edges()
			ctx.on_stage = stage_before_choice.duplicate()
			if not ctx.visited.has(target):
				_walk(target, ctx)
		return

	# ── Linear ───────────────────────────────────────────────────────────────
	for lnk in links:
		var target: String = lnk.get("passageName", "").strip_edges()
		if ctx.visited.has(target):
			ctx.packets.append({"type": "jump", "label": _label_for(target)})
		else:
			_walk(target, ctx)
		break


# ══════════════════════════════════════════════════════════════════════════════
#  Tag parsing
# ══════════════════════════════════════════════════════════════════════════════

static func _split_tags(tags_str: String) -> Array:
	var result: Array = []
	for t in tags_str.split(" "):
		var cleaned: String = t.strip_edges().to_lower()
		if cleaned != "":
			result.append(cleaned)
	return result


static func _parse_actor_tags(tags: Array) -> Dictionary:
	var speaker:     String     = ""
	var enters:      Array      = []
	var leaves:      Array      = []
	var expressions: Dictionary = {}

	for t in tags:
		if STRUCTURAL_TAGS.has(t):
			continue
		if BACKGROUND_MAP.has(t.replace("-", "_")):
			continue
		if t == "narrator":
			continue

		if not "-" in t:
			continue

		var hyphen_pos:  int    = t.find("-")
		var actor_part:  String = t.substr(0, hyphen_pos)
		var suffix:      String = t.substr(hyphen_pos + 1)

		if not KNOWN_ACTORS.has(actor_part):
			continue

		var actor_id: String
		if ACTOR_ALIASES.has(actor_part):
			actor_id = ACTOR_ALIASES[actor_part]
		else:
			actor_id = actor_part.substr(0, 1).to_upper() + actor_part.substr(1)

		if suffix == "speaker":
			speaker = actor_id
			continue

		if suffix == "leave":
			if not leaves.has(actor_id):
				leaves.append(actor_id)
			continue

		if suffix == "enter" or suffix.begins_with("enter-"):
			var position: String = ""
			if   suffix == "enter-left":                              position = "left"
			elif suffix == "enter-right":                             position = "right"
			elif suffix == "enter-middle" or suffix == "enter-center": position = "center"

			var already: bool = false
			for e in enters:
				if e["actor_id"] == actor_id:
					already = true
					if position != "":
						e["position"] = position
					break
			if not already:
				enters.append({
					"actor_id":   actor_id,
					"position":   position,
					"expression": "",
				})
			continue

		if EXPRESSION_MAP.has(suffix):
			expressions[actor_part] = EXPRESSION_MAP[suffix]
			continue

	for enter_info in enters:
		if enter_info["expression"] == "":
			var key: String = enter_info["actor_id"].to_lower()
			enter_info["expression"] = expressions.get(key, "neutral")

	return {
		"speaker":     speaker,
		"enters":      enters,
		"leaves":      leaves,
		"expressions": expressions,
	}


static func _display_speaker(speaker: String, _tags: Array) -> String:
	return speaker


static func _get_background_tag(tags: Array) -> String:
	for t in tags:
		var normalized: String = t.replace("-", "_")
		if BACKGROUND_MAP.has(normalized):
			return normalized
	return ""


static func _get_overlay_sprite_tag(tags: Array) -> String:
	for t in tags:
		var normalized: String = t.replace("-", "_")
		if OVERLAY_SPRITE_MAP.has(normalized):
			return normalized
	return ""


static func _links_are_choices(links: Array) -> bool:
	if links.size() <= 1:
		return false
	for lnk in links:
		var lt: String = lnk.get("linkText", "").strip_edges()
		var pn: String = lnk.get("passageName", "").strip_edges()
		if lt != pn and lt != "":
			return true
	return false


static func _is_structural_only(tags: Array, text: String) -> bool:
	if tags.has("minigame_start") or tags.has("minigame_end"):
		return true
	if text.begins_with("[[") and text.ends_with("]]"):
		return true
	return false


static func _label_for(passage_name: String) -> String:
	return passage_name.strip_edges().replace(" ", "_").replace(".", "_")


static func _find_start(passages: Array, passage_map: Dictionary) -> String:
	for candidate in ["1.0", "Start", "start"]:
		if passage_map.has(candidate):
			return candidate
	if not passages.is_empty():
		return passages[0]["name"].strip_edges()
	return ""
