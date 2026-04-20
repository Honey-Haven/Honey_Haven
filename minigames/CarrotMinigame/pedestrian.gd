extends Area2D

var SCROLL_SPEED := 400.0
var shaky = false
var targY = 0.0
var targX = 0.0
var screen_height: float
const SPEED = 5.0
var audiostream
var delaytime = 0.0

func play_sound(filename: String):
	var stream = load(filename)
	audiostream.stream = stream
	audiostream.play()

func _ready():
	screen_height = get_viewport_rect().size.y
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	var ray = $ShapeCast2D
	ray.enabled = true
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	ray.target_position = Vector2(0, 1) * 1000
	ray.force_shapecast_update()
	if ray.is_colliding():
		print("delay, mailbox below me")
		delaytime = 0.5
	else:
		ray.target_position = Vector2(0, -1) * 1000
		ray.force_shapecast_update()
		if ray.is_colliding():
			print("delay, mailbox above me")
			delaytime = 0.5
	
func _on_area_entered(area):
	if shaky:
		return
	if area.is_in_group("carrot"):
		# Scored! Signal main to increment counter
		$Sprite2D.texture = preload("res://minigames/CarrotMinigame/sprites/sheep2.webp")
		get_tree().get_root().get_node("Main").lose_point(false)
		shaky = true
		targX = global_position.x
		targY = global_position.y
		print("we going to (" + str(targX) + ", " + str(targY) + ")")

func _on_body_entered(body):
	if shaky:
		return
	$Sprite2D.texture = preload("res://minigames/CarrotMinigame/sprites/sheep2.webp")
	get_tree().get_root().get_node("Main").lose_point(true)
	targX = global_position.x
	if global_position.y > (screen_height / 2):
		targY = global_position.y - 120.0
	else:
		targY = global_position.y + 120.0
	print("we going to (" + str(targX) + ", " + str(targY) + ")")
	shaky = true
	play_sound("res://sounds/BWAUGH.wav")

func _process(delta):
	if (delaytime != 0):
		delaytime = max(0.0, delaytime - delta)
		return
	var ray = $ShapeCast2D
	ray.target_position = Vector2(0, 1) * 1000
	ray.force_shapecast_update()
	if ray.is_colliding():
		print("delay, mailbox below me")
		delaytime = 0.5
		return
	else:
		ray.target_position = Vector2(0, -1) * 1000
		ray.force_shapecast_update()
		if ray.is_colliding():
			print("delay, mailbox above me")
			delaytime = 0.5
			return
	
	if shaky:
		targX -= SCROLL_SPEED * delta
		position.x += (SPEED*(targX - position.x) + randf_range(-10.0,10.0)) * delta
		position.y += (SPEED*(targY - position.y) + randf_range(-10.0,10.0)) * delta
	else:
		position.x -= SCROLL_SPEED * delta
	if position.x < -200:   # offscreen left
		queue_free()

func set_speed(newspeed):
	print("Updated speed to " + str(newspeed))
	SCROLL_SPEED = newspeed
