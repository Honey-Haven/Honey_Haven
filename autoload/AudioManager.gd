extends Node

var bgm_players: Array[AudioStreamPlayer] = []
var active_bgm_idx: int = 0
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	# Create two players for BGM crossfading
	for i in 2:
		var p = AudioStreamPlayer.new()
		add_child(p)
		bgm_players.append(p)
	
	# Create one player for general SFX
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	SignalBus.bgm_play.connect(_on_bgm_play)
	SignalBus.bgm_stop.connect(_on_bgm_stop)
	SignalBus.sfx_play.connect(_on_sfx_play)

func _on_bgm_play(path: String, fade_time: float, volume: float = 0.0) -> void:
	print("AudioManager playing: ", path, " at Volume: ", volume)
	var stream = load(path)
	if not stream:
		push_error("AudioManager: Could not load BGM at " + path)
		return
	
	var old_player = bgm_players[active_bgm_idx]
	active_bgm_idx = (active_bgm_idx + 1) % 2
	var new_player = bgm_players[active_bgm_idx]
	
	new_player.stream = stream
	new_player.volume_db = -80.0 # Start silent
	new_player.play()
	
	var tw = create_tween().set_parallel(true)
	# Fade new track in
	tw.tween_property(new_player, "volume_db", volume, fade_time).set_trans(Tween.TRANS_SINE)
	# Fade old track out
	if old_player.playing:
		tw.tween_property(old_player, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(old_player.stop)

func _on_bgm_stop(fade_time: float) -> void:
	var current_player = bgm_players[active_bgm_idx]
	if current_player.playing:
		var tw = create_tween()
		tw.tween_property(current_player, "volume_db", -80.0, fade_time)
		tw.tween_callback(current_player.stop)

func _on_sfx_play(path: String) -> void:
	var stream = load(path)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()
