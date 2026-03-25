extends Node
#Using JSON for now (subject to change)
class_name ScriptParser

# ── Parse entry point ─────────────────────────────────────────
static func parse(json_array: Array) -> Array:
	var packets: Array = []
	for raw in json_array:
		var p = _parse_entry(raw)
		if p != null:
			packets.append(p)
	return packets

# ── Internal dispatcher ───────────────────────────────────────
static func _parse_entry(raw: Dictionary) -> Dictionary:
	var t: String = raw.get("type", "")
	match t:
		"dialogue":
			return _parse_dialogue(raw)
		"choice":
			return _parse_choice(raw)
		"actor_show":
			return {
				"type": "actor_show",
				"actor_id": raw.get("actor_id", raw.get("actor", "")),
				"expression": raw.get("expression", "default"),
				"position": raw.get("position", "center"),
				"anim": raw.get("anim", "appear"),
			}
		"appear":
			return {
				"type": "appear",
				"actor_id": raw.get("actor_id", ""),
				"expression": raw.get("expression", "neutral"),
				"position": raw.get("position", "center"),
			}
		"actor_hide":
			return {
				"type": "actor_hide",
				"actor_id": raw.get("actor_id", raw.get("actor", "")),
				"anim": raw.get("anim", "fade"),
			}
		"actor_move":
			return {
				"type": "actor_move",
				"actor_id": raw.get("actor_id", raw.get("actor", "")),
				"position": raw.get("position", "center"),
				"anim": raw.get("anim", "slide"),
			}
		"actor_anim":
			return {
				"type": "actor_anim",
				"actor_id": raw.get("actor_id", raw.get("actor", "")),
				"anim": raw.get("anim", "shake"),
			}
		"actor_expression":
			return {
				"type": "actor_expression",
				"actor_id": raw.get("actor_id", raw.get("actor", "")),
				"expression": raw.get("expression", "default"),
			}
		"background":
			return {
				"type": "background",
				"path": raw.get("path", ""),
				"transition": raw.get("transition", "fade"),
			}
		"bgm":
			return {
				"type": "bgm",
				"action": raw.get("action", "play"),
				"path": raw.get("path", ""),
				"fade": float(raw.get("fade", 1.0)),
			}
		"sfx":
			return {"type": "sfx", "path": raw.get("path", "")}
		"wait":
			return {"type": "wait", "duration": float(raw.get("duration", 1.0))}
		"minigame":
			return {
				"type": "minigame",
				"id": raw.get("id", ""),
				"data": raw.get("data", {}),
			}
		"jump":
			return {"type": "jump", "label": raw.get("label", "")}
		"label":
			return {"type": "label", "name": raw.get("name", "")}
		"must_visit_hub":
			# Pass through as-is — handled by VNLogic, not normalised here.
			return raw.duplicate()
		_:
			push_warning("ScriptParser: unknown type '%s'" % t)
			return {}

static func _parse_dialogue(raw: Dictionary) -> Dictionary:
	return {
		"type": "dialogue",
		"speaker": raw.get("speaker", ""),
		"text": raw.get("text", ""),
		"expression": raw.get("expression", ""),   # auto-switch expression mid-line
		"voice": raw.get("voice", ""),
		"textbox_effect": raw.get("textbox_effect", "none"),
		"word_shake": bool(raw.get("word_shake", false)),
		"auto_advance": bool(raw.get("auto_advance", false)),
		"auto_delay": float(raw.get("auto_delay", 1.5)),
	}

static func _parse_choice(raw: Dictionary) -> Dictionary:
	return {
		"type": "choice",
		"prompt": raw.get("prompt", ""),
		"choices": raw.get("choices", []),
		"continuation": raw.get("continuation", ""),
	}
