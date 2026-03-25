extends Node
class_name TwineParser

# ══════════════════════════════════════════════════════════════════════════════
#  TwineParser
#  Converts a Twine-to-JSON export into the packet array consumed by VNLogic.
#
#  TAG CONVENTIONS (space-separated in the passage "tags" field)
#  ─────────────────────────────────────────────────────────────
#  <actor>              → that actor is the speaker for this passage
#  <actor>_enter        → show that actor's sprite before the line
#  <actor>_leave        → hide that actor's sprite after the line
#  <expression>         → emotion tag; resolved to "<speaker>_<expression>"
#                         using EXPRESSION_MAP (see below).  Only applied
#                         when the expression belongs to the current speaker.
#  Narrator             → no name-tag shown  (maps to speaker "")
#  Demon                → name tag shows "Demon", no sprite on screen
#  must_visit           → this passage-name is added to the must-visit set;
#                         the hub passage that links to it is blocked until
#                         every must_visit sibling has been seen.
#  minigame_start       → emits a minigame_start packet (id = passage name)
#  minigame_end         → emits a minigame_end packet (currently a no-op marker)
#
#  EXPRESSION MAP
#  ──────────────
#  Keys are the raw tag words that represent emotions.
#  Values are the expression IDs registered in ActorManager / VNController.
#  Add or rename entries freely; the parser never hard-codes actor names.
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
	"buttons":   "",   # ← actor name, not an expression; ignored here
	# Add more as you create sprites:
	# "shocked":  "shocked",
	# "smug":     "smug",
}

# Tags that are actor names (or special roles) – never treated as expressions.
# Extend this as you add characters.
const KNOWN_ACTORS: Array = [
	"marty", "matthew", "buttons", "peaches", "mochi", "chester",
	"scotch", "tofu", "barnaby", "jane", "muffins", "demon",
	"narrator", "peanut", "smith",
]

# Actor aliases: multiple tag names that share one sprite / actor slot.
# Map alias → canonical_id. The canonical_id must be registered in VNController.
const ACTOR_ALIASES: Dictionary = {
	"tofu":  "Scotch_Tofu",
	"scotch": "Scotch_Tofu",
}

# Tags that carry structural meaning and should never be mistaken for actors
# or expressions.
const STRUCTURAL_TAGS: Array = [
	"must_visit", "minigame_start", "minigame_end",
]

# Populated at runtime via register_background() in VNController —
# same pattern as registering actors. No need to edit TwineParser for new backgrounds.
static var BACKGROUND_MAP: Dictionary = {}

## Register a background tag → texture path. Call from VNController before loading any script.
static func register_background(tag: String, path: String) -> void:
	BACKGROUND_MAP[tag.to_lower()] = path


# ── Public entry point ────────────────────────────────────────────────────────
#
#  twine_json  : the parsed Dictionary from the Twine-to-JSON export
#                (the top-level object that contains a "passages" array).
#
#  Returns the flat packet Array ready for  VNLogic.load_script().
#
static func parse(twine_json: Dictionary) -> Array:
	var passages: Array = twine_json.get("passages", [])

	# ── 1. Build a name→passage lookup ───────────────────────────────────────
	var passage_map: Dictionary = {}
	for p in passages:
		passage_map[p["name"].strip_edges()] = p

	# ── 2. Identify the start passage ────────────────────────────────────────
	#  Twine's first passage is "1.0" in this project, but fall back to
	#  whatever comes first in the array if not found.
	var start_name: String = _find_start(passages, passage_map)

	# ── 3. Walk the graph and emit packets ───────────────────────────────────
	var ctx := _ParseContext.new()
	ctx.passage_map = passage_map
	_walk(start_name, ctx)

	return ctx.packets


# ══════════════════════════════════════════════════════════════════════════════
#  Internal walk
# ══════════════════════════════════════════════════════════════════════════════

class _ParseContext:
	var passage_map:    Dictionary = {}
	var packets:        Array      = []
	var visited:        Dictionary = {}   # passage_name → true
	var on_stage:       Dictionary = {}   # actor_id → true (parse-time stage tracking)
	var current_bg:     String     = ""   # last background tag emitted
	# must_visit tracking: hub_passage_name → { child_name: bool }
	var must_visit_sets: Dictionary = {}
	# Which hub we're currently serving (set when we enter a must_visit branch)
	var current_hub:   String      = ""


static func _walk(name: String, ctx: _ParseContext) -> void:
	var clean_name: String = name.strip_edges()

	if ctx.visited.has(clean_name):
		# Already emitted – emit a jump instead so VNLogic can land here.
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

	# ── Emit a label so jumps can land here ──────────────────────────────────
	ctx.packets.append({"type": "label", "name": _label_for(clean_name)})

	# ── Decode who is on stage ────────────────────────────────────────────────
	var speaker:    String = _get_speaker(raw_tags)
	var expression: String = _get_expression(raw_tags, speaker)
	var enters:     Array  = _get_enters(raw_tags)
	var leaves:     Array  = _get_leaves(raw_tags)

	# ── Background tag ────────────────────────────────────────────────────────
	# If a tag matches a key in BACKGROUND_MAP and it differs from the current
	# background, emit a background_change packet (fade transition by default).
	var bg_tag: String = _get_background_tag(raw_tags)
	if bg_tag != "" and bg_tag != ctx.current_bg:
		ctx.current_bg = bg_tag
		ctx.packets.append({
			"type":       "background",
			"path":       BACKGROUND_MAP[bg_tag],
			"transition": "fade",
		})

	# ── Actor leaves — fire BEFORE this passage's dialogue ───────────────────
	# A _leave tag on a passage means "this character exits before this line
	# is spoken." Only hide if the actor is actually on stage.
	for actor_id in leaves:
		if ctx.on_stage.has(actor_id):
			ctx.packets.append({"type": "actor_hide", "actor_id": actor_id})
			ctx.on_stage.erase(actor_id)

	# ── Actor enters ──────────────────────────────────────────────────────────
	# Guard: only appear if not already on stage.
	for actor_id in enters:
		if not ctx.on_stage.has(actor_id):
			var expr: String = "neutral"
			if actor_id.to_lower() == speaker.to_lower() and expression != "":
				expr = expression
			ctx.packets.append({
				"type":      "appear",
				"actor_id":  actor_id,
				"expression": expr,
				"position":  "",
			})
			ctx.on_stage[actor_id] = true

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
		return   # end of branch

	# ── must_visit hub detection ──────────────────────────────────────────────
	#  A passage is a "hub" if ANY of its direct children has must_visit.
	var must_visit_children: Array = []
	var free_children: Array       = []

	var must_visit_labels: Dictionary = {}  # passage_name → display label
	for lnk in links:
		var child_name: String = lnk.get("passageName", "").strip_edges()
		if not ctx.passage_map.has(child_name):
			continue
		var child_tags: Array = _split_tags(
				ctx.passage_map[child_name].get("tags", ""))
		if child_tags.has("must_visit"):
			must_visit_children.append(child_name)
			# Use link text as display label if it differs from the passage name
			var link_text: String = lnk.get("linkText", "").strip_edges()
			must_visit_labels[child_name] = link_text if link_text != child_name else child_name
		else:
			free_children.append(child_name)

	if not must_visit_children.is_empty():
		# Register the must-visit set keyed to this hub.
		if not ctx.must_visit_sets.has(parent_name):
			var mv_dict: Dictionary = {}
			for cn in must_visit_children:
				mv_dict[cn] = false
			ctx.must_visit_sets[parent_name] = mv_dict

		# Emit a special "must_visit_hub" packet that VNLogic will expand into
		# a repeated choice menu until all children are visited.
		ctx.packets.append({
			"type":           "must_visit_hub",
			"hub_id":         parent_name,
			"must_visit":     must_visit_children.duplicate(),
			"label_map":      must_visit_labels.duplicate(),
			"continuation":   free_children[0] if not free_children.is_empty() else "",
		})

		# Pre-walk every must-visit branch so labels exist.
		# Snapshot on_stage so each branch starts from the same state.
		var stage_before_mv: Dictionary = ctx.on_stage.duplicate()
		for cn in must_visit_children:
			ctx.on_stage = stage_before_mv.duplicate()
			if not ctx.visited.has(cn):
				_walk(cn, ctx)

		# Walk the free continuation after the hub.
		if not free_children.is_empty():
			ctx.on_stage = stage_before_mv.duplicate()
			_walk(free_children[0], ctx)

		return

	# ── Choice (multiple non-must_visit children, with link text) ────────────
	#  Twine creates a choice when the link text differs from the passage name.
	var is_choice: bool = _links_are_choices(links)

	if is_choice and links.size() > 1:
		var choice_entries: Array = []
		var silent_continuation: String = ""
		for lnk in links:
			var label_text: String = lnk.get("linkText", "").strip_edges()
			var target:     String = lnk.get("passageName", "").strip_edges()
			# [[PassageName]] with no arrow → linkText == passageName.
			# Treat as a silent fallthrough, not a visible button.
			if label_text == target:
				silent_continuation = target
				continue
			# Strip surrounding quotes Twine wraps around player-facing text.
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
		# Walk every branch, snapshotting on_stage so branches don't
		# bleed into each other's enter/leave guards.
		var stage_before_choice: Dictionary = ctx.on_stage.duplicate()
		for lnk in links:
			var target: String = lnk.get("passageName", "").strip_edges()
			ctx.on_stage = stage_before_choice.duplicate()
			if not ctx.visited.has(target):
				_walk(target, ctx)
		return

	# ── Linear (single next passage, or link text == passage name) ───────────
	for lnk in links:
		var target: String = lnk.get("passageName", "").strip_edges()
		if ctx.visited.has(target):
			ctx.packets.append({"type": "jump", "label": _label_for(target)})
		else:
			_walk(target, ctx)
		break   # only ever one linear successor


# ══════════════════════════════════════════════════════════════════════════════
#  Tag helpers
# ══════════════════════════════════════════════════════════════════════════════

static func _split_tags(tags_str: String) -> Array:
	var result: Array = []
	for t in tags_str.split(" "):
		var cleaned: String = t.strip_edges().to_lower()
		# Normalise "tofu/scotch_enter" compound tags — split on slash,
		# giving each name its own _enter/_leave suffix.
		if "/" in cleaned:
			var suffix := ""
			if cleaned.ends_with("_enter"): suffix = "_enter"
			elif cleaned.ends_with("_leave"): suffix = "_leave"
			for part in cleaned.split("/"):
				var base := part.replace("_enter","").replace("_leave","")
				if base != "":
					result.append(base + suffix)
			continue
		if cleaned != "":
			result.append(cleaned)
	return result


## Return the actor id who is speaking (empty string = Narrator).
static func _get_speaker(tags: Array) -> String:
	# Special roles first
	if tags.has("demon"):
		return "Demon"
	if tags.has("narrator"):
		return ""
	# Look for a known actor that is NOT an _enter / _leave tag and NOT a
	# structural tag.
	for t in tags:
		if t.ends_with("_enter") or t.ends_with("_leave"):
			continue
		if STRUCTURAL_TAGS.has(t):
			continue
		if ACTOR_ALIASES.has(t):
			return ACTOR_ALIASES[t]
		if KNOWN_ACTORS.has(t):
			return t.substr(0, 1).to_upper() + t.substr(1)
	return ""   # narrator


## Returns the display name for the dialogue name-tag.
## Demon shows "Demon" but has no sprite.  Narrator shows nothing.
static func _display_speaker(speaker: String, _tags: Array) -> String:
	return speaker   # "" → Narrator box hidden by DialogueUI


## Find an expression tag that belongs to the current speaker.
## Expression tags are words that exist in EXPRESSION_MAP and are NOT
## an actor name or structural tag.
static func _get_expression(tags: Array, speaker: String) -> String:
	for t in tags:
		if t.ends_with("_enter") or t.ends_with("_leave"):
			continue
		if STRUCTURAL_TAGS.has(t):
			continue
		if KNOWN_ACTORS.has(t):
			continue
		if EXPRESSION_MAP.has(t) and EXPRESSION_MAP[t] != "":
			return EXPRESSION_MAP[t]
	return ""


## Returns a list of actor ids that should appear (from *_enter tags).
static func _get_enters(tags: Array) -> Array:
	var result: Array = []
	for t in tags:
		if t.ends_with("_enter"):
			var actor: String = t.substr(0, t.length() - 6)
			if ACTOR_ALIASES.has(actor):
				actor = ACTOR_ALIASES[actor]
			else:
				actor = actor.substr(0, 1).to_upper() + actor.substr(1)
			if not result.has(actor):
				result.append(actor)
	return result


## Returns a list of actor ids that should leave (from *_leave tags).
static func _get_leaves(tags: Array) -> Array:
	var result: Array = []
	for t in tags:
		if t.ends_with("_leave"):
			var actor: String = t.substr(0, t.length() - 6)
			if ACTOR_ALIASES.has(actor):
				actor = ACTOR_ALIASES[actor]
			else:
				actor = actor.substr(0, 1).to_upper() + actor.substr(1)
			if not result.has(actor):
				result.append(actor)
	return result


## Returns the background tag from this passage's tags, or "" if none.
static func _get_background_tag(tags: Array) -> String:
	for t in tags:
		if BACKGROUND_MAP.has(t):
			return t
	return ""


## True if the passage's links represent player choices rather than a
## simple linear continuation (i.e. the link text is not just the passage name).
static func _links_are_choices(links: Array) -> bool:
	if links.size() <= 1:
		return false
	for lnk in links:
		var lt: String = lnk.get("linkText", "").strip_edges()
		var pn: String = lnk.get("passageName", "").strip_edges()
		# If the link text is meaningfully different from the target name,
		# it's player-facing choice text.
		if lt != pn and lt != "":
			return true
	return false


## True when the passage text is a dev note (e.g. "minigame starts") that
## should not be spoken aloud.
static func _is_structural_only(tags: Array, text: String) -> bool:
	if tags.has("minigame_start") or tags.has("minigame_end"):
		return true
	# Passages whose cleanText is just a passage name (Twine auto-link) are
	# also silent.
	if text.begins_with("[[") and text.ends_with("]]"):
		return true
	return false


## Converts a passage name into a safe label string (no spaces / dots).
static func _label_for(passage_name: String) -> String:
	return passage_name.strip_edges().replace(" ", "_").replace(".", "_")


## Find the starting passage.  Prefer "1.0", then "Start", then first entry.
static func _find_start(passages: Array, passage_map: Dictionary) -> String:
	for candidate in ["1.0", "Start", "start"]:
		if passage_map.has(candidate):
			return candidate
	if not passages.is_empty():
		return passages[0]["name"].strip_edges()
	return ""
