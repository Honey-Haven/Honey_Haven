extends Resource
class_name VNThemeTextbox
# ── Textbox panel ─────────────────────────────────────────────
@export var bg_color: Color         = Color(0.604, 0.216, 0.443, 0.725)
@export var border_color: Color     = Color(0.98, 0.716, 0.791, 1.0)
@export var border_width: int       = 4
@export var corner_radius: int      = 45
@export var padding: Vector4        = Vector4(30, 30, 20, 30)  # left top right bottom
# ── Dialogue text ─────────────────────────────────────────────
@export var font: Font
@export var font_size: int          = 22
@export var font_color: Color       = Color.WHITE

# --- Narrator ------------
@export var narrator_bg_color: Color    = Color(0.05, 0.05, 0.05, 0.88)
@export var narrator_border_color: Color = Color(0.4, 0.4, 0.4, 1.0)
@export var narrator_font_color: Color  = Color(0.85, 0.85, 0.85, 1.0)

# ---- Demon _-----------
@export var demon_bg_color:     Color = Color(0.04, 0.0, 0.06, 0.93)
@export var demon_border_color: Color = Color(0.45, 0.0, 0.55, 1.0)
@export var demon_font_color:   Color = Color(0.85, 0.6, 1.0, 1.0)
@export var demon_font: Font
@export var demon_font_size: int = 22
