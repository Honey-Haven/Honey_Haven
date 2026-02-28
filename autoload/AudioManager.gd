extends Node

@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

func _ready() -> void:
	SignalBus.bgm_play.connect(_play_bgm)
	SignalBus.bgm_stop.connect(_stop_bgm)
	SignalBus.sfx_play.connect(_play_sfx)

func _play_bgm(path: String, fade_in: float) -> void:
	if path == "":
		return
	var stream: AudioStream = load(path)
	if stream == null:
		push_error("AudioManager: could not load BGM '%s'" % path)
		return
	bgm_player.stream = stream
	bgm_player.volume_db = -80.0
	bgm_player.play()
	var tween: Tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", 0.0, fade_in)

func _stop_bgm(fade_out: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(bgm_player.stop)

func _play_sfx(path: String) -> void:
	if path == "":
		return
	var stream: AudioStream = load(path)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()
