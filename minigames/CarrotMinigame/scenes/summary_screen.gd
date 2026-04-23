extends Node2D

var score : int
var accuracy : int
var adjustedscore : float
var stars : int
var dialogue = ["ATROCIOUS!\nGet out of here.",
				"What were you even\ndoing out there?",
				"Not bad...",
				"WOW! You're the\nbest mailmouse ever!"]
var spritename = ["res://actors/buttons/buttonsAngry.webp",
				 "res://actors/buttons/buttonsFakeSmile.webp",
				 "res://actors/buttons/buttonsneutral.webp",
				 "res://actors/buttons/buttonsHappy.webp"]
var scales = [0.5, 0.742, 0.5, 0.5]

var countscore = 0
var countacc = 0
var countanimationtime = 0.0
const countanimdur = 0.05
var accanimdur = 0.02
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

func _ready() -> void:
	score = CarrotsResults.score
	accuracy = CarrotsResults.accuracy
	stars = 0
	adjustedscore = score * accuracy / 100.0
	if (adjustedscore > 0.0):
		stars += 1
	if (adjustedscore > 21.0):
		stars += 1
	if (adjustedscore > 39.0):
		stars += 1
	countstartime = countstardur
	$buny.texture = load(spritename[2])
	var size = scales[2]
	$buny.scale = Vector2(-size, size)
	hmmtime = 2.0

	# pivot_offset needs size, which is only valid after the first layout frame.
	# call_deferred runs after _ready() completes, giving Control nodes time to lay out.
	call_deferred("_set_pivots")

	# Replay / Continue buttons — hardcoded for VN integration.
	call_deferred("_create_buttons")


func _set_pivots() -> void:
	$Label.pivot_offset  = $Label.size  / 2.0
	$Label2.pivot_offset = $Label2.size / 2.0
	$Label3.pivot_offset = $Label3.size / 2.0


func _process(delta: float) -> void:
	if (hmmtime > 0.0):
		hmmtime -= delta
		return

	if (countscore < score):
		countanimationtime = max(0.0, countanimationtime - delta)
		if (countanimationtime == 0.0):
			countanimationtime = countanimdur
			countscore += 1
			$AudioStreamPlayer.play()
			if countscore == score:
				flareTime = 0.5
	elif (countacc < accuracy):
		if (countstars == 0 and flareTime > 0):
			flareTime = max(0.0, flareTime - delta)
			var size = baseLabelScale * (1.0 + flareAmplitude * sin(flareTime * PI / flareDur))
			$Label.scale = Vector2(size, size)
		else:
			countanimationtime = max(0.0, countanimationtime - delta)
			if (countanimationtime == 0.0):
				countanimationtime = accanimdur
				countacc += 1
				$AudioStreamPlayer.play()
				if countacc == accuracy:
					flareTime = 0.5
	elif (countstars < stars):
		if (countstars == 0 and flareTime > 0):
			flareTime = max(0.0, flareTime - delta)
			var size = baseLabelScale * (1.0 + flareAmplitude * sin(flareTime * PI / flareDur))
			$Label3.scale = Vector2(size, size)
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
					$star1.scale = Vector2(size, size)
				elif (countstars == 2):
					$star2.scale = Vector2(size, size)
				elif (countstars == 3):
					$star3.scale = Vector2(size, size)
	elif not text:
		$Label2.text = dialogue[stars]
		text = true
		$buny.texture = load(spritename[stars])
		var size = scales[stars]
		$buny.scale = Vector2(-size, size)

	$Label.text  = "%d"   % countscore
	$Label3.text = "%d%%" % countacc
	if (countstars > 0):
		$star1.texture = preload("res://minigames/CarrotMinigame/sprites/staricon.png")
	if (countstars > 1):
		$star2.texture = preload("res://minigames/CarrotMinigame/sprites/staricon.png")
	if (countstars > 2):
		$star3.texture = preload("res://minigames/CarrotMinigame/sprites/staricon.png")


# ── Hardcoded navigation buttons (VN integration) ────────────
func _create_buttons() -> void:
	var vp  := get_viewport_rect().size
	var cl  := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)

	var btn_replay   := _make_btn("Play Again",     Color(0.15, 0.35, 0.60))
	var btn_continue := _make_btn("Continue Story", Color(0.20, 0.50, 0.25))

	btn_replay.position   = Vector2(vp.x * 0.5 - 220, vp.y - 80)
	btn_continue.position = Vector2(vp.x * 0.5 + 20,  vp.y - 80)

	cl.add_child(btn_replay)
	cl.add_child(btn_continue)

	btn_replay.pressed.connect(_on_replay)
	btn_continue.pressed.connect(_on_continue)


func _make_btn(label_text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size = Vector2(200, 52)
	btn.focus_mode = Control.FOCUS_NONE
	var sn := StyleBoxFlat.new()
	sn.bg_color = color
	sn.set_corner_radius_all(10)
	sn.content_margin_left   = 18; sn.content_margin_right  = 18
	sn.content_margin_top    = 8;  sn.content_margin_bottom = 8
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = color.lightened(0.25)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 18)
	return btn


func _on_replay() -> void:
	get_tree().change_scene_to_file("res://minigames/CarrotMinigame/scenes/main.tscn")

func _on_continue() -> void:
	MinigameReturn.returning_from_minigame = true
	get_tree().change_scene_to_file(MinigameReturn.vn_scene_path)
