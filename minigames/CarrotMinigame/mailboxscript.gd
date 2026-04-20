extends Area2D

var SCROLL_SPEED := 400.0

func _ready():
	var screen_height = get_viewport_rect().size.y
	if (global_position.y > screen_height / 2):
		rotation = PI
		
	#if (randi_range(0,1) == 1):
	#	$Sprite2D.texture = preload("res://sprites/mailboxBempty.webp")

func _process(delta):
	position.x -= SCROLL_SPEED * delta
	if position.x < -200:   # offscreen left
		queue_free()

func set_speed(newspeed):
	print("Updated speed to " + str(newspeed))
	SCROLL_SPEED = newspeed
