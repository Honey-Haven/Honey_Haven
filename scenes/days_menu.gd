extends Node2D

var bobbletimer = 0.0
var bobblespeed = 1.0
var titlebasex = 0
var titlebasey = 0
var titlebasescale = 1.0
const xbobbleamp = 10.0
const ybobbleamp = 10.0
const scaleamp = 0.1
const rotationamp = 0.10
const shakespeed = 40.0
const shakeamp = 2.0
var b7xb = 0
var b7yb = 0

@onready var button1 = $day1/Button
@onready var button2 = $day2/Button2
@onready var button3 = $day3/Button3
@onready var button4 = $day4/Button4
@onready var button5 = $day5/Button5
@onready var button6 = $day6/Button6
@onready var backbutton = $back/backbutton
@onready var button7 = $day7/Button7

var b1scaletarget = 1.0
var b2scaletarget = 1.0
var b3scaletarget = 1.0
var b4scaletarget = 1.0
var b5scaletarget = 1.0
var b6scaletarget = 1.0
var bbrottarget = 0.0
var b1v = 0.0
var b2v = 0.0
var b3v = 0.0
var b4v = 0.0
var b5v = 0.0
var b6v = 0.0
var bbrv = 0.0
var buttonjerk = 20.0
var buttondamp = 2.0
var clicking = 0
var bbjerk = 20.0
var bbdamp = 2.0

var fadetimer = -1.0
var fadeduration = 0.5
var fadeToTransition = false
var jumpToScene = 0

func ishovered(button):
	return button.get_global_rect().has_point(get_global_mouse_position())

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if clicking == 1:
				print("day 1")
				#print("clicked play")
				#fadetimer = fadeduration
				#fadeToTransition = true
			elif clicking == 2:
				print("day 2")
			elif clicking == 3:
				print("day 3")
			elif clicking == 4:
				print("day 4")
			elif clicking == 5:
				print("day 5")
			elif clicking == 6:
				print("day 6")
			if clicking > 0 and clicking < 8:
				fadetimer = fadeduration
				fadeToTransition = true
				jumpToScene = clicking
			if clicking == -1:
				fadetimer = fadeduration
				fadeToTransition = true
				jumpToScene = -1

func ribbons() -> void:
	$day1/ribbon.visible = false
	$day2/ribbon.visible = false
	$day3/ribbon.visible = false
	$day4/ribbon.visible = false
	$day5/ribbon.visible = false
	$day6/ribbon.visible = false
	var mrd = menucontrolflow.mostRecentDay
	if mrd > 0 and mrd < 7:
		get_node("day%d/ribbon" % mrd).visible = true
	if mrd == 6 or mrd == 7:
		$day7.visible = true
		$day7/Button7.disabled = false
	else:
		$day7.visible = false
		$day7/Button7.disabled = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	jumpToScene = 0
	fadetimer = 0.5
	$FADE.visible = true
	ribbons()
	b7xb = $day7.global_position.x
	b7yb = $day7.global_position.y
	menucontrolflow.playsound()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (fadetimer >= 0.0):
		fadetimer = max(0.0, fadetimer - delta)
		$FADE.visible = true
		if fadeToTransition:
			$FADE.modulate.a = 1 - (fadetimer / fadeduration)
			if fadetimer == 0.0:
				#print("switchy scene... %d" % jumpToScene)
				if jumpToScene > 0 and jumpToScene < 8:
					menucontrolflow.mostRecentDay = jumpToScene
					menucontrolflow.dayStart.emit(jumpToScene)
					menucontrolflow.stopsound()
					var day_scripts := {
						1: "res://scripts/day1.json",
						2: "res://scripts/day2.json",
						3: "res://scripts/day3.json",
						4: "res://scripts/day4.json",
						5: "res://scripts/day5.json",
						6: "res://scripts/day6.json",
						7: "res://scripts/epilogue.json",
					}
					menucontrolflow.selected_script = day_scripts[jumpToScene]
					get_tree().change_scene_to_file("res://resources/VNScene.tscn")
				elif jumpToScene == -1:
					get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		else:
			$FADE.modulate.a = fadetimer / fadeduration
			if fadetimer == 0.0:
				fadetimer = -1.0
	else:
		$FADE.visible = false
	
	#bobbletimer += delta
	#$title.global_position.x = titlebasex + xbobbleamp * sin(bobbletimer * bobblespeed)
	#$title.global_position.y = titlebasey + ybobbleamp * sin(bobbletimer * bobblespeed * 2)
	#var size = titlebasescale + scaleamp * sin(bobbletimer * bobblespeed * 2)
	#$title.scale = Vector2(size,size)
	#$title.rotation = rotationamp * -sin(bobbletimer * bobblespeed)
	
	clicking = 0
	if (ishovered(button1)):
		b1scaletarget = 1.15
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			b1scaletarget = 1.10
			clicking = 1
	else:
		b1scaletarget = 1.0
	if (ishovered(button2)):
		b2scaletarget = 1.15
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			b2scaletarget = 1.10
			clicking = 2
	else:
		b2scaletarget = 1.0
	if (ishovered(button3)):
		b3scaletarget = 1.15
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			b3scaletarget = 1.10
			clicking = 3
	else:
		b3scaletarget = 1.0
	if (ishovered(button4)):
		b4scaletarget = 1.15
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			b4scaletarget = 1.10
			clicking = 4
	else:
		b4scaletarget = 1.0
	if (ishovered(button5)):
		b5scaletarget = 1.15
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			b5scaletarget = 1.10
			clicking = 5
	else:
		b5scaletarget = 1.0
	if (ishovered(button6)):
		b6scaletarget = 1.15
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			b6scaletarget = 1.10
			clicking = 6
	else:
		b6scaletarget = 1.0
	if (ishovered(backbutton)):
		bbrottarget = -0.1
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			clicking = -1
	else:
		bbrottarget = 0.0
	if (ishovered(button7) and not button7.disabled):
		bobbletimer += delta
		$day7.global_position = Vector2(b7xb,b7yb) + shakeamp * Vector2(sin(bobbletimer*shakespeed), cos(bobbletimer * (shakespeed * 1.2)))
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			clicking = 7
	
	var b1s = $day1.scale.x
	var b2s = $day2.scale.x
	var b3s = $day3.scale.x
	var b4s = $day4.scale.x
	var b5s = $day5.scale.x
	var b6s = $day6.scale.x
	var bbr = $back.rotation
	var b1a = (b1scaletarget - b1s) * buttonjerk - b1v * buttondamp
	var b2a = (b2scaletarget - b2s) * buttonjerk - b2v * buttondamp
	var b3a = (b3scaletarget - b3s) * buttonjerk - b3v * buttondamp
	var b4a = (b4scaletarget - b4s) * buttonjerk - b4v * buttondamp
	var b5a = (b5scaletarget - b5s) * buttonjerk - b5v * buttondamp
	var b6a = (b6scaletarget - b6s) * buttonjerk - b6v * buttondamp
	var bbra = (bbrottarget - bbr) * bbjerk - bbrv * bbdamp
	b1v += b1a * delta
	b2v += b2a * delta
	b3v += b3a * delta
	b4v += b4a * delta
	b5v += b5a * delta
	b6v += b6a * delta
	bbrv += bbra * delta
	b1s += b1v * delta
	b2s += b2v * delta
	b3s += b3v * delta
	b4s += b4v * delta
	b5s += b5v * delta
	b6s += b6v * delta
	bbr += bbrv * delta
	$day1.scale = Vector2(b1s, b1s)
	$day2.scale = Vector2(b2s, b2s)
	$day3.scale = Vector2(b3s, b3s)
	$day4.scale = Vector2(b4s, b4s)
	$day5.scale = Vector2(b5s, b5s)
	$day6.scale = Vector2(b6s, b6s)
	$back.rotation = bbr
	
	ribbons()
