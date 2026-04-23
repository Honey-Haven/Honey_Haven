extends Resource
class_name VNThemeDaySplash

# ── Overlay ───────────────────────────────────────────────────
@export var overlay_color: Color = Color(0, 0, 0, 1)   # background fill during the card

# ── Text ──────────────────────────────────────────────────────
@export var font:       Font  = null
@export var font_size:  int   = 72
@export var text_color: Color = Color(1, 1, 1, 1)

# ── Timing ────────────────────────────────────────────────────
@export var fade_in:       float = 0.6   # seconds for overlay to fade in
@export var fade_out:      float = 0.6   # seconds for overlay to fade out
@export var hold_duration: float = 1.8   # seconds card stays fully visible after typing

# ── Typewriter SFX ────────────────────────────────────────────
# Assign an AudioStream here to give the day splash its own typing sound.
# Leave null to fall back to the main typewriter SFX.
@export var typewriter_sfx:       AudioStream = null
@export var typewriter_volume_db: float       = -6.0
