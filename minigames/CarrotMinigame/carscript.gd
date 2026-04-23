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
	var move_down = Input.is_key_pressed(KEY_S)
	var move_up   = Input.is_key_pressed(KEY_W)

	if move_down and lane < max_lane and doneMoving:
		lane += 1
		doneMoving = false
	elif move_up and lane > min_lane and doneMoving:
		lane -= 1
		doneMoving = false

	if not (move_down or move_up):
		doneMoving = true

	var targetY = screen_height * 0.5 + (lane * LANE_WIDTH)
	var discrepancyY = targetY - global_position.y
	if (abs(discrepancyY) < 3):
		velocity.y = 0
		rotation = 0
		global_position.y = targetY
		doneMoving = true
	else:
		velocity.y = discrepancyY * SPEED
		rotation = discrepancyY * 0.002
	velocity.x = 0
	move_and_slide()
	position.y = clamp(position.y, 0, screen_height)
