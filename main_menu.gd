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

@onready var button1 = $playbutton/Button
@onready var button2 = $helpbutton/Button2
@onready var button3 = $contactdevbutton/Button3

var b1scaletarget = 1.0
var b2scaletarget = 1.0
var b3scaletarget = 1.0
var b1v = 0.0
var b2v = 0.0
var b3v = 0.0
var buttonjerk = 20.0
var buttondamp = 2.0
var clicking = 0

var fadetimer = -1.0
var fadeduration = 0.5
var fadeToTransition = false

func ishovered(button):
	return button.get_global_rect().has_point(get_global_mouse_position())

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if clicking == 1:
				print("clicked play")
				fadetimer = fadeduration
				fadeToTransition = true
			elif clicking == 2:
				print("clicked help")
			elif clicking == 3:
				print("clicked contact dev")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fadetimer = 0.5
	titlebasex = $title.global_position.x
	titlebasey = $title.global_position.y
	$FADE.visible = true
	menucontrolflow.playsound()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (fadetimer >= 0.0):
		fadetimer = max(0.0, fadetimer - delta)
		$FADE.visible = true
		if fadeToTransition:
			$FADE.modulate.a = 1 - (fadetimer / fadeduration)
			if fadetimer == 0.0:
				print("switchy scene...")
				get_tree().change_scene_to_file("res://scenes/days_menu.tscn")
		else:
			$FADE.modulate.a = fadetimer / fadeduration
			if fadetimer == 0.0:
				fadetimer = -1.0
	else:
		$FADE.visible = false
	
	bobbletimer += delta
	$title.global_position.x = titlebasex + xbobbleamp * sin(bobbletimer * bobblespeed)
	$title.global_position.y = titlebasey + ybobbleamp * sin(bobbletimer * bobblespeed * 2)
	var size = titlebasescale + scaleamp * sin(bobbletimer * bobblespeed * 2)
	$title.scale = Vector2(size,size)
	$title.rotation = rotationamp * -sin(bobbletimer * bobblespeed)
	
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
	
	var b1s = $playbutton.scale.x
	var b2s = $helpbutton.scale.x
	var b3s = $contactdevbutton.scale.x
	var b1a = (b1scaletarget - b1s) * buttonjerk - b1v * buttondamp
	var b2a = (b2scaletarget - b2s) * buttonjerk - b2v * buttondamp
	var b3a = (b3scaletarget - b3s) * buttonjerk - b3v * buttondamp
	b1v += b1a * delta
	b2v += b2a * delta
	b3v += b3a * delta
	b1s += b1v * delta
	b2s += b2v * delta
	b3s += b3v * delta
	$playbutton.scale = Vector2(b1s, b1s)
	$helpbutton.scale = Vector2(b2s, b2s)
	$contactdevbutton.scale = Vector2(b3s, b3s)
