extends Node

# Autoload singleton — must be named "CarrotsResults" in Project Settings.
# Carries score and accuracy from the minigame into the summary screen.

var score    : int = 0
var accuracy : int = 0  # 0–100 integer percentage

func reset() -> void:
	score    = 0
	accuracy = 0
