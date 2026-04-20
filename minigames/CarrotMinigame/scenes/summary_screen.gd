extends Node2D

var score : int
var stars : int
var dialogue = ["ATROCIOUS!\nGet out of here.",
				"What were you even\ndoing out there?",
				"Not bad...",
				"WOW! You're the\nbest mailmouse ever!"]
var spritename = ["res://sprites/buttonsAngry.webp",
				 "res://sprites/buttonsFakeSmile.webp",
				 "res://sprites/buttonsneutral.webp",
				 "res://sprites/buttonsHappy.webp"]
var scales = [0.5, 0.742, 0.5, 0.5]

var countscore = 0
var countanimationtime = 0.0
const countanimdur = 0.05
var countstars = 0
var countstartime = 0.0
const countstardur = 0.7
var text = false
var flareTime = 0.0
var flareDur = 0.5
var hmmtime = 0.0

const baseLabelScale = 1.0
const baseStarScale = 0.255
const flareAmplitude = 0.25

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score = CarrotsResults.score
	stars = 0
	if (score > 0):
		stars += 1
	if (score > 25):
		stars += 1
	if (score > 42):
		stars += 1
	countstartime = countstardur
	$buny.texture = load(spritename[2])
	var size = scales[2]
	$buny.scale = Vector2(-size,size)
	hmmtime = 2.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (hmmtime > 0.0):
		hmmtime -= delta
		return
	# $Label2.text = dialogue[stars]
	if (countscore < score):
		countanimationtime = max(0.0, countanimationtime - delta)
		if (countanimationtime == 0.0):
			countanimationtime = countanimdur
			countscore += 1
			$AudioStreamPlayer.play()
			if countscore == score:
				flareTime = 0.5
	elif (countstars < stars):
		if (countstars == 0 and flareTime > 0):
			flareTime = max(0.0, flareTime - delta)
			var size = baseLabelScale * (1.0 + flareAmplitude * sin(flareTime * PI / flareDur))
			$Label.scale = Vector2(size,size)
		else:
			countstartime = max(0.0, countstartime - delta)
			if (countstartime == 0.0):
				countstartime = countstardur
				countstars += 1
				$AudioStreamPlayer.play()
				if countscore == score:
					flareTime = 0.5
			if (flareTime > 0):
				flareTime = max(0.0, flareTime - delta)
				var size = baseStarScale * (1.0 + flareAmplitude * sin(flareTime * PI / flareDur))
				if (countstars == 1):
					$star1.scale = Vector2(size,size)
				elif (countstars == 2):
					$star2.scale = Vector2(size,size)
				elif (countstars == 3):
					$star3.scale = Vector2(size,size)
	elif not text:
		$Label2.text = dialogue[stars]
		text = true
		$buny.texture = load(spritename[stars])
		var size = scales[stars]
		$buny.scale = Vector2(-size,size)
	
	$Label.text = "%d" % countscore
	if (countstars > 0):
		$star1.texture = preload("res://minigames/CarrotMinigame/sprites/staricon.png")
	if (countstars > 1):
		$star2.texture = preload("res://minigames/CarrotMinigame/sprites/staricon.png")
	if (countstars > 2):
		$star3.texture = preload("res://minigames/CarrotMinigame/sprites/staricon.png")

func _input(event: InputEvent) -> void:
	# Only allow returning if the animations are finished (text is visible)
	if text and (event is InputEventMouseButton or event.is_action_pressed("ui_accept")):
		if event.is_pressed():
			MinigameReturn.returning_from_minigame = true
			get_tree().change_scene_to_file(MinigameReturn.vn_scene_path)
