extends Area2D

const Y_SPEED = 1200.0
const BASE_SCALE = 0.2
const FLY_AMOUNT = 3.0
const FLY_AMOUNT2 = 10.0
const DISAPPEAR_SPIN = 3.0
var X_SPEED := 800.0
var BG_SPEED := 800.0
var direction: int = 1   # 1 = down, -1 = up, set before adding to scene
var squished := false
var screen_rect: Rect2
var audiostream
var dist = 800.0
var vertdist = 800.0
var speed = sqrt(Y_SPEED * Y_SPEED + X_SPEED * X_SPEED)
var time = dist / speed
var timer = 0.0
var disappeartimer = -1.0

func play_sound(filename: String):
	var stream = load(filename)
	audiostream.stream = stream
	audiostream.play()

func get_distance_to_mailbox() -> float:
	var ray = $ShapeCast2D
	ray.force_shapecast_update()
	if ray.is_colliding():
		return global_position.distance_to(ray.get_collision_point(0))
	return -1.0  # no mailbox in sight

func _ready():
	screen_rect = get_viewport_rect()
	# Connect collision signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var ray = $ShapeCast2D
	ray.enabled = true
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	ray.target_position = Vector2(X_SPEED+BG_SPEED, Y_SPEED * direction).normalized() * 1000
	dist = get_distance_to_mailbox()
	vertdist = dist * (Y_SPEED / sqrt((X_SPEED+BG_SPEED)*(X_SPEED+BG_SPEED) + Y_SPEED * Y_SPEED))
	time = vertdist / speed
	#print("vertical distance " + str(vertdist) + " time " + str(time))
	timer = 0

func _process(delta):
	timer += delta
	if squished:
		position.x -= BG_SPEED * delta
		return
	#position.x += 0  # carrots fly vertically relative to car lane
	if (disappeartimer < 0):
		position.x += (X_SPEED - BG_SPEED) * delta
		position.y += direction * Y_SPEED * delta
		if (dist != -1):
			var size = BASE_SCALE * max((1 + FLY_AMOUNT * (timer/time) * (1 - timer/time)), 1.0)
			$Sprite2D.scale = Vector2(size,size)
			var rot = FLY_AMOUNT2 * (timer/time) * (1 - timer/time)
			$Sprite2D.rotation = rot
	else:
		position.x += -BG_SPEED * delta 
		position.y += direction * Y_SPEED * delta * disappeartimer * disappeartimer
		var size = BASE_SCALE * disappeartimer * 4
		$Sprite2D.scale = Vector2(size,size)
		$Sprite2D.rotation += DISAPPEAR_SPIN * delta
		disappeartimer = max(disappeartimer - delta, 0)
		if disappeartimer == 0:
			queue_free()

	# Hit screen border
	if position.y < 0 or position.y > screen_rect.size.y:
		squish()

func _on_body_entered(body):
	# Hit something solid (not a mailbox)
	squish()

func _on_area_entered(area):
	if (disappeartimer < 0):
		if area.is_in_group("mailbox"):
			# Scored! Signal main to increment counter
			play_sound("res://sounds/good.mp3")
			var prevtexture = area.get_node("Sprite2D").texture
			if (prevtexture == preload("res://minigames/CarrotMinigame/sprites/mailboxAempty.webp")):
				area.get_node("Sprite2D").texture = preload("res://minigames/CarrotMinigame/sprites/mailboxAfull.webp")
				get_tree().get_root().get_node("Main").score_point()
				disappeartimer = 0.25
			elif (prevtexture == preload("res://minigames/CarrotMinigame/sprites/mailboxBempty.webp")):
				area.get_node("Sprite2D").texture = preload("res://minigames/CarrotMinigame/sprites/mailboxBfull.webp")
				get_tree().get_root().get_node("Main").score_point()
				disappeartimer = 0.25
			#queue_free()
		else:
			squish()

func squish():
	if squished:
		return
	squished = true
	play_sound("res://sounds/fail.mp3")
	$Sprite2D.texture = preload("res://minigames/CarrotMinigame/sprites/damagedcarrots.webp")
	# Stop movement, auto-delete after a moment
	await get_tree().create_timer(1.0).timeout
	queue_free()

func change_speed(speedchange):
	print("changed speed by " + str(speedchange))
	X_SPEED += speedchange
