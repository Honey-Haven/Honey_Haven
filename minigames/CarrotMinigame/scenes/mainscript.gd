extends Node2D

const CarrotScene     = preload("res://minigames/CarrotMinigame/scenes/carrot.tscn")
const MailboxScene    = preload("res://minigames/CarrotMinigame/scenes/mailbox.tscn")
const BGTileScene     = preload("res://minigames/CarrotMinigame/scenes/bg_tile.tscn")
const PedestrianScene = preload("res://minigames/CarrotMinigame/scenes/pedestrian.tscn")
const DumpCarrotScene = preload("res://minigames/CarrotMinigame/scenes/discardedcarrot.tscn")

# How many background sprites loop
const BG_COUNT = 4
var BG_SPEED = 800
const ORIGINAL_BGSPEED = 800
const CARROT_XSPEED = 800.0
const CARROT_YSPEED = 1200.0

var score := 0
var screen_size: Vector2
var bg_tiles: Array = []
var bg_tile_width := 0.0

# Spawn timing
var mailbox_timer := 0.0
var mailbox_interval_min := 0.5
var mailbox_interval_max := 2.0
var mailbox_interval := randf_range(mailbox_interval_min, mailbox_interval_max)
var mailbox_y := 0.0
var combo = false
var pedestrian_interval := 3.0
var pedestrian_timer := 0.0
var reset_speed_timer := 0.0
var cooldown_speed_timer := 0.0
const carrot_base_size = 0.085
const carrot_icon_anim_duration = 0.5
const carrot_icon_anim_amplitude = 0.02
var carrot_icon_anim_timer = 0.0

var w = false
var s = false
var WStutorial = false
var udtimer = 0.0
var u = false
var d = false
var UDtutorial = false

var fadeintimer = 1.0
const fadeinduration = 1.0
var fadeouttimer = 0.0
const fadeoutduration = 2.0

var instructions = 0.0

var countdown = 50.1
var carrot_cooldown = 0.0
var carrot_throws = 0
var accuracy = 0

# Manual "just pressed" tracking — replaces is_action_just_pressed without InputMap
var _up_just_pressed   := false
var _down_just_pressed := false
var _up_held           := false
var _down_held         := false

@onready var car = $Car
@onready var score_label = $ScoreLabel
@onready var targettop = $Car/targettop
@onready var targetbottom = $Car/targetbottom
@onready var cicon = $CarrotIcon
@onready var time_label = $TimeLabel

func _ready():
	screen_size = get_viewport_rect().size
	_spawn_backgrounds()
	$ScoreLabel.pivot_offset = $ScoreLabel.size / 2.0
	$TimeLabel.pivot_offset = $TimeLabel.size / 2.0
	$AccuracyLabel.pivot_offset = $AccuracyLabel.size / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_UP:
			if event.pressed and not _up_held:
				_up_just_pressed = true
			_up_held = event.pressed
		if event.keycode == KEY_DOWN:
			if event.pressed and not _down_held:
				_down_just_pressed = true
			_down_held = event.pressed

func _process(delta):
	if (countdown == 0.0):
		CarrotsResults.score = score
		CarrotsResults.accuracy = accuracy
		get_tree().change_scene_to_file("res://minigames/CarrotMinigame/scenes/summary_screen.tscn")
	if (WStutorial and UDtutorial):
		countdown = max(0.0, countdown - delta)
	update_timer()
	if fadeintimer > 0.0:
		$FADE.visible = true
		$FADE.modulate.a = fadeintimer / fadeinduration
		fadeintimer = max(0.0, fadeintimer - delta)
	elif countdown < fadeoutduration:
		fadeouttimer = fadeoutduration - countdown
		$FADE.visible = true
		$FADE.modulate.a = fadeouttimer / fadeoutduration
	else:
		$FADE.visible = false

	if carrot_icon_anim_timer != 0.0:
		var size = carrot_base_size + carrot_icon_anim_amplitude * sin(carrot_icon_anim_timer * PI / carrot_icon_anim_duration)
		cicon.global_scale = Vector2(size, size)
		if carrot_icon_anim_timer < 0.0:
			carrot_icon_anim_timer = min(0.0, carrot_icon_anim_timer + delta)
		else:
			carrot_icon_anim_timer = max(0.0, carrot_icon_anim_timer - delta)

	_scroll_backgrounds(delta)
	carrot_cooldown = max(0.0, carrot_cooldown - delta)
	_handle_carrot_fire()

	var y1 = 70
	var y2 = screen_size.y - 70
	var dy1 = abs(y1 - car.global_position.y)
	var dy2 = abs(y2 - car.global_position.y)
	var x1 = car.global_position.x + (dy1 * (CARROT_XSPEED - BG_SPEED) / CARROT_YSPEED)
	var x2 = car.global_position.x + (dy2 * (CARROT_XSPEED - BG_SPEED) / CARROT_YSPEED)
	targettop.global_position = Vector2(x1, y1)
	targetbottom.global_position = Vector2(x2, y2)

	if (not WStutorial):
		$w_indicator.visible = true
		$s_indicator.visible = true
		$w_indicator.global_position = car.global_position + Vector2(0, -90)
		$s_indicator.global_position = car.global_position + Vector2(0, 90)
		if Input.is_key_pressed(KEY_W):
			w = true
		if Input.is_key_pressed(KEY_S):
			s = true
		if w and s:
			WStutorial = true
			$w_indicator.visible = false
			$s_indicator.visible = false
	elif (not UDtutorial):
		$up_indicator.visible = true
		$down_indicator.visible = true
		$up_indicator.global_position = car.global_position + Vector2(0, -(90 + 20 * sin(udtimer * 3)))
		$down_indicator.global_position = car.global_position + Vector2(0, (90 + 20 * sin(udtimer * 3)))
		udtimer += delta
		if Input.is_key_pressed(KEY_UP):
			u = true
		if Input.is_key_pressed(KEY_DOWN):
			d = true
		if u and d:
			UDtutorial = true
			$up_indicator.visible = false
			$down_indicator.visible = false
			udtimer = 2.0
			instructions = 1.0
	elif (udtimer > 0.0):
		udtimer -= delta
		$CarLabel.visible = true
		$CarLabel.position.y = car.position.y - 40
	else:
		if (instructions > 0.0):
			instructions = max(0.0, instructions - delta)
			$CarLabel.visible = true
			$CarLabel.position.y = car.position.y - 40
		else:
			$CarLabel.visible = false
		# Mailbox spawning
		if BG_SPEED != 0:
			mailbox_timer += delta
			pedestrian_timer += delta

		if mailbox_timer >= mailbox_interval and BG_SPEED != 0:
			if randi_range(0, 3) == 3:
				mailbox_timer = 0.0
				_spawn_mailbox()
				combo = true
				mailbox_interval = 0.2
			else:
				mailbox_timer = 0.0
				_spawn_mailbox()
				combo = false
				mailbox_interval = randf_range(mailbox_interval_min, mailbox_interval_max)
		if pedestrian_timer >= pedestrian_interval and BG_SPEED != 0:
			_spawn_pedestrian()
			pedestrian_timer = 0.0

	# Clear just-pressed flags at end of frame
	_up_just_pressed = false
	_down_just_pressed = false


# ── Carrot Firing ───────────────────────────────────────────
func _handle_carrot_fire():
	if _up_just_pressed and carrot_cooldown == 0.0:
		_spawn_carrot(-1)
		carrot_cooldown = 0.15
		if UDtutorial:
			carrot_throws += 1
	if _down_just_pressed and carrot_cooldown == 0.0:
		_spawn_carrot(1)
		carrot_cooldown = 0.15
		if UDtutorial:
			carrot_throws += 1

func _spawn_carrot(dir: int):
	var c = CarrotScene.instantiate()
	c.BG_SPEED = BG_SPEED
	c.direction = dir
	c.position = car.position
	c.audiostream = $AudioStreamPlayer2D
	add_child(c)


# ── Mailbox Spawning ────────────────────────────────────────
func _spawn_mailbox():
	var m = MailboxScene.instantiate()
	m.SCROLL_SPEED = BG_SPEED
	if not combo:
		if randi_range(0, 1) == 1:
			mailbox_y = randf_range(40, 100)
		else:
			mailbox_y = screen_size.y - randf_range(40, 100)
	m.position = Vector2(screen_size.x + 80, mailbox_y)
	add_child(m)

func _spawn_pedestrian():
	var p = PedestrianScene.instantiate()
	p.SCROLL_SPEED = BG_SPEED
	p.position = Vector2(screen_size.x + 80, (screen_size.y / 2) + 120 * randi_range(-1, 1))
	p.audiostream = $AudioStreamPlayer2D
	add_child(p)


# ── Background Looping ──────────────────────────────────────
func _spawn_backgrounds():
	var probe = BGTileScene.instantiate()
	add_child(probe)
	bg_tile_width = probe.get_node("Sprite2D").texture.get_width() * probe.scale.x
	probe.queue_free()
	bg_tile_width *= 0.75

	for i in BG_COUNT:
		var tile = BGTileScene.instantiate()
		var tex_path = "res://minigames/CarrotMinigame/sprites/newroad%d.webp" % ((i % 2) + 1)
		tile.get_node("Sprite2D").texture = load(tex_path)
		tile.position = Vector2(i * bg_tile_width, screen_size.y / 2.0)
		add_child(tile)
		bg_tiles.append(tile)

func _scroll_backgrounds(delta):
	for tile in bg_tiles:
		tile.position.x -= BG_SPEED * delta
		if tile.position.x + bg_tile_width / 2.0 < 0:
			var max_x = _get_rightmost_bg_x()
			tile.position.x = max_x + bg_tile_width

func _get_rightmost_bg_x() -> float:
	var max_x = -INF
	for tile in bg_tiles:
		if tile.position.x > max_x:
			max_x = tile.position.x
	return max_x


# ── Scoring ──────────────────────────────────────────────────
func score_point():
	score += 1
	score_label.text = "%d" % score
	accuracy = round((float(max(0, score)) / carrot_throws) * 100)
	$AccuracyLabel.text = "Accuracy: %d%%" % accuracy
	carrot_icon_anim_timer = 0.5

func update_timer():
	time_label.text = "%d" % floor(countdown)
	var size = 1.0 + 0.2 * fmod(countdown, 1.0)
	time_label.scale = Vector2(size, size)

func lose_point(dumpcarrot: bool):
	score -= 1
	score_label.text = "%d" % score
	accuracy = round((float(max(0, score)) / carrot_throws) * 100)
	$AccuracyLabel.text = "Accuracy: %d%%" % accuracy
	carrot_icon_anim_timer = -0.5
	if (dumpcarrot):
		var dc = DumpCarrotScene.instantiate()
		dc.position = Vector2(car.global_position.x - 50, car.global_position.y)
		add_child(dc)

func update_bgspeed(newspeed: int):
	var oldspeed = BG_SPEED
	var changespeed = newspeed - oldspeed
	BG_SPEED = newspeed
	get_tree().call_group("carrot",  "change_speed", changespeed)
	get_tree().call_group("mailbox", "set_speed",    newspeed)
