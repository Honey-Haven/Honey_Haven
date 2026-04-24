extends Node2D

@onready var button1 = $background/playbutton/Button
@onready var button2 = $background/helpbutton/Button2
@onready var button3 = $menubutton/Button
@onready var xbutton = $background/xbutton/Button3

var b1scaletarget = 1.0
var b2scaletarget = 1.0
var b3scaletarget = 1.0
var ytarget = -400
var b1v = 0.0
var b2v = 0.0
var b3v = 0.0
var yv = 0.0
var buttonjerk = 20.0
var buttondamp = 2.0
var yjerk = 10.0
var ydamp = 7.0
var clicking = 0

var xbuttontimer = 0.0
var xbuttonspeed = 3.0
var xbuttonbasescale = 1.0
var xbuttonscaleamp = 0.1

var fadetimer = -1.0
var fadeduration = 0.5
var fadeToTransition = false

func ishovered(button):
	return button.get_global_rect().has_point(get_global_mouse_position())

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if clicking == 1:
				print("clicked return home")
				fadetimer = fadeduration
				fadeToTransition = true
			elif clicking == 2:
				print("clicked help")
			elif clicking == 3:
				print("clicked menu")
				if ytarget == -400:
					$background.visible = true
					ytarget = 360
				else:
					ytarget = -400

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#fadetimer = 0.5
	#$FADE.visible = true
	$background.visible = false
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (fadetimer >= 0.0):
		fadetimer = max(0.0, fadetimer - delta)
		$FADE.visible = true
		if fadeToTransition:
			$FADE.modulate.a = 1 - (fadetimer / fadeduration)
			if fadetimer == 0.0:
				AudioManager.stop_and_forget()
				MinigameReturn.returning_from_minigame = false
				MinigameReturn.pending_result = {}
				MinigameReturn.script_path = ""
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		else:
			$FADE.modulate.a = fadetimer / fadeduration
			if fadetimer == 0.0:
				fadetimer = -1.0
	else:
		$FADE.visible = false
	
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
	if (ishovered(xbutton)):
		xbuttontimer += delta
		var size = xbuttonbasescale + xbuttonscaleamp * sin(xbuttontimer * xbuttonspeed)
		$background/xbutton.scale = Vector2(size,size)
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			clicking = 3
	else:
		var size = $background/xbutton.scale.x
		var dsize = xbuttonbasescale - size
		size += dsize * xbuttonspeed * delta
		if (abs(dsize) < 0.01):
			$background/xbutton.scale = Vector2(xbuttonbasescale, xbuttonbasescale)
			xbuttontimer = 0.0
		else:
			$background/xbutton.scale = Vector2(size, size)
	
	var b1s = $background/playbutton.scale.x
	var b2s = $background/helpbutton.scale.x
	var b3s = $menubutton.scale.x
	var y = $background.global_position.y
	var b1a = (b1scaletarget - b1s) * buttonjerk - b1v * buttondamp
	var b2a = (b2scaletarget - b2s) * buttonjerk - b2v * buttondamp
	var b3a = (b3scaletarget - b3s) * buttonjerk - b3v * buttondamp
	var ya = (ytarget - y) * yjerk - yv * ydamp
	b1v += b1a * delta
	b2v += b2a * delta
	b3v += b3a * delta
	yv += ya * delta
	b1s += b1v * delta
	b2s += b2v * delta
	b3s += b3v * delta
	y += yv * delta
	$background/playbutton.scale = Vector2(b1s, b1s)
	$background/helpbutton.scale = Vector2(b2s, b2s)
	$menubutton.scale = Vector2(b3s, b3s)
	$background.global_position.y = y
	$menubutton.global_position.y = -360.0-y
	if y < -360:
		$background.visible = false
	else:
		$background.visible = true
