extends Resource
class_name VNTheme
# ============================================================
#  VNTheme.gd — Master theme, references sub-themes
#  Create a .tres of this in res://resources/
#  Each sub-theme is its own .tres you can swap independently
# ============================================================

# ── Sub-themes (each is its own .tres resource) ───────────────
@export var textbox:    Resource   # VNThemeTextbox
@export var nameplate:  Resource   # VNThemeNameplate
@export var choices:    Resource   # VNThemeChoices
@export var typewriter: Resource   # VNThemeTypewriter
@export var effects:    Resource   # VNThemeEffects
@export var sprites:    Resource   # VNThemeSprites
@export var transitions: Resource  # VNThemeTransitions

# ── Added sub-themes ──────────────────────────────────────────
# Drop VNThemeStranger.gd and VNThemeDaySplash.gd into res://resources/,
# then in the Inspector assign a new .tres of each type here.
@export var stranger:   Resource   # VNThemeStranger  — Stranger textbox colours + SFX
@export var day_splash: Resource   # VNThemeDaySplash — day/end card timing, font, SFX
