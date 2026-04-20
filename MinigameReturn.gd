extends Node
# ============================================================
#  MinigameReturn.gd  — Autoload singleton
#  Add this as an Autoload in Project > Project Settings > Autoload
#  Name it exactly:  MinigameReturn
# ============================================================

# The VN scene to go back to after a minigame finishes
var vn_scene_path: String = ""
var script_path: String = ""

# The result the minigame wants to pass back
var pending_result: Dictionary = {}

# Set to true by the minigame when it's done.
# VNController checks this in _ready() and fires minigame_end if true.
var returning_from_minigame: bool = false
