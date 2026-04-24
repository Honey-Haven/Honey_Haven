extends CharacterBody2D
const SPEED           = 340.0
const STUCK_THRESHOLD = 1.0
const STUCK_DISTANCE  = 20.0
const SHAKE_DURATION  = 0.75
const SHAKE_INTENSITY = 5.0
const JUMP_DURATION   = 0.75
var last_position: Vector2
var stuck_timer: float = 0.0
var is_shaking: bool   = false
var shake_timer: float = 0.0
var is_jumping: bool   = false
var jump_timer: float  = 0.0
var jump_start: Vector2
var jump_target: Vector2
func _ready() -> void:
	last_position = global_position
	$"../LandingShadow".visible = false
func _physics_process(delta: float) -> void:
	var target: Node2D = $"../Marty"
	if is_jumping:
		jump_timer += delta
		var t: float = clamp(jump_timer / JUMP_DURATION, 0.0, 1.0)
		global_position = jump_start.lerp(jump_target, t)
		var shadow: Node2D = $"../LandingShadow"
		shadow.scale = Vector2.ONE * (1.0 - t)
		if t >= 1.0:
			is_jumping    = false
			jump_timer    = 0.0
			stuck_timer   = 0.0
			last_position = global_position
			$"../LandingShadow".visible = false
			shadow.scale = Vector2.ONE
		return
	if is_shaking:
		shake_timer += delta
		$Sprite2D.position.x = sin(shake_timer * 40.0) * SHAKE_INTENSITY
		if shake_timer >= SHAKE_DURATION:
			$Sprite2D.position.x = 0.0
			jump_start  = global_position
			jump_target = global_position + (target.global_position - global_position).normalized() * 300.0
			is_jumping  = true
			is_shaking  = false
			shake_timer = 0.0
		return
	var direction: Vector2 = (target.global_position - global_position).normalized()
	velocity = direction * SPEED
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider() == target:
			game_over()
	if global_position.distance_to(last_position) < STUCK_DISTANCE:
		stuck_timer += delta
		if stuck_timer >= 1.0:
			$Sprite2D.texture = preload("res://minigames/ChesterChase/sprites/chesterAngry.webp")
			var predicted_target: Vector2 = global_position + (target.global_position - global_position).normalized() * 400.0
			$"../LandingShadow".global_position = predicted_target
			$"../LandingShadow".visible = true
		if stuck_timer >= STUCK_THRESHOLD and not is_shaking:
			is_shaking  = true
			shake_timer = 0.0
	else:
		stuck_timer   = 0.0
		last_position = global_position
		$"../LandingShadow".visible = false
		$Sprite2D.texture = preload("res://minigames/ChesterChase/sprites/chesterNeutral.webp")
func game_over() -> void:
	get_tree().change_scene_to_file.call_deferred("res://minigames/ChesterChase/scenes/cc_game_over.tscn")
