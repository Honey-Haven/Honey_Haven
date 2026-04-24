extends Node

var mostRecentDay = 0
var selected_script: String = ""
var player: AudioStreamPlayer
var soundplaying = false

signal dayStart(dayNumber)

func stopsound() -> void:
	if soundplaying:
		player.stop()
		soundplaying = false
		
func playsound() -> void:
	if not soundplaying:
		player.seek(0.0)
		player.play()
		soundplaying = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = preload("res://audio/bgm/musicupdated/Music/Honey-Haven-Title.mp3")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
