extends Resource
class_name VNThemeTextbox
# ── Textbox panel ─────────────────────────────────────────────
@export var bg_color: Color         = Color(0.604, 0.216, 0.443, 0.725)
@export var border_color: Color     = Color(0.98, 0.716, 0.791, 1.0)
@export var border_width: int       = 2
@export var corner_radius: int      = 30
@export var padding: Vector4        = Vector4(20, 12, 20, 12)  # left top right bottom
# ── Dialogue text ─────────────────────────────────────────────
@export var font: Font
@export var font_size: int          = 22
@export var font_color: Color       = Color.WHITE
