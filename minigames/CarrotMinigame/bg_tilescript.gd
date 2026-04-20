extends Node2D

const SCROLL_SPEED = 200.0  # match mailbox speed
var tile_width: float = 0.0

func init(width: float):
	tile_width = width

#func _process(delta):
	#position.x -= SCROLL_SPEED * delta
