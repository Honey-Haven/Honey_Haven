extends CharacterBody2D

const SPEED = 8.0
const LANE_WIDTH = 120
var doneMoving = true
var lane = 0
var min_lane = -1
var max_lane = 1
var screen_height: float

func _ready():
	screen_height = get_viewport_rect().size.y

func _physics_process(delta):
	var direction = 0
	if Input.is_action_pressed("move_down") and lane < max_lane and doneMoving:   # S key — map this in Project Settings
		#direction = 1
		lane += 1
		doneMoving = false
	elif Input.is_action_pressed("move_up") and lane > min_lane and doneMoving:   # W key
		#direction = -1
		lane -= 1
		doneMoving = false
	if not (Input.is_action_pressed("move_down") or Input.is_action_pressed("move_up")):
		doneMoving = true

	var targetY = screen_height * 0.5 + (lane * LANE_WIDTH)
	var discrepancyY = targetY - global_position.y
	if (abs(discrepancyY) < 3):
		velocity.y = 0
		rotation = 0
		global_position.y = targetY
		doneMoving = true
	else:
		velocity.y = (discrepancyY) * SPEED
		rotation = discrepancyY * 0.002
	velocity.x = 0
	move_and_slide()

	# Clamp to screen
	position.y = clamp(position.y, 0, screen_height)
