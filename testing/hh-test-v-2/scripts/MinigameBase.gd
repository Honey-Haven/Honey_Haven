extends Node
# ============================================================
#  MinigameBase.gd
# ============================================================
#  Inherit from this in every minigame scene's root script.
#
#  Usage in your minigame:
#    extends MinigameBase
#    func _on_game_complete():
#        finish({"score": 100, "won": true})
# ============================================================

class_name MinigameBase

var _data: Dictionary = {}

# Override this if you need to receive data from VNController
func setup(data: Dictionary) -> void:
	_data = data
	_on_setup(data)

# Override in child to react to setup data
func _on_setup(_data: Dictionary) -> void:
	pass

# Call this when the minigame is done
func finish(result: Dictionary = {}) -> void:
	# Remove self from tree first, then signal
	queue_free()
	SignalBus.minigame_end.emit(result)
