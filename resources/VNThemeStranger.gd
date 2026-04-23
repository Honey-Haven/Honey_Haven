extends Resource
class_name VNThemeStranger

# ── Textbox colours ───────────────────────────────────────────
@export var bg_color:      Color = Color(0.05, 0.05, 0.07, 0.92)
@export var border_color:  Color = Color(0.3,  0.6,  0.4,  1.0)
@export var font_color:    Color = Color(0.7,  0.95, 0.75, 1.0)

# ── Nameplate colours ─────────────────────────────────────────
@export var np_bg_color:    Color = Color(0.07, 0.12, 0.08, 1.0)
@export var np_border_color: Color = Color(0.3, 0.6,  0.4,  1.0)
@export var np_font_color:  Color = Color(0.6,  0.9,  0.65, 1.0)

# ── Text ──────────────────────────────────────────────────────
@export var font:      Font = null
@export var font_size: int  = 0   # 0 = inherit from main textbox

# ── Typewriter SFX ────────────────────────────────────────────
# Assign an AudioStream here to give the Stranger their own blip sound.
# Leave null to fall back to the path set via TwineParser.register_stranger_sfx().
@export var typewriter_sfx:       AudioStream = null
@export var typewriter_volume_db: float       = -6.0
