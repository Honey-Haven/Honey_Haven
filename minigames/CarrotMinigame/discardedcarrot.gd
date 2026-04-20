extends Sprite2D
const XSPEED = 1200.0
const RSPEED = 15.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position.x -= XSPEED * delta
	rotation += RSPEED * delta
	if position.x < -200:   # offscreen left
		queue_free()
