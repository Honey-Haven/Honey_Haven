extends Node

var bgm_players: Array[AudioStreamPlayer] = []
var active_bgm_idx: int = 0
var sfx_player: AudioStreamPlayer

# Saved playback position per resource path so switching back resumes in place.
var _saved_positions: Dictionary = {}  # path (String) → position (float)
var _current_path: String = ""

func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		add_child(p)
		bgm_players.append(p)

	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	SignalBus.bgm_play.connect(_on_bgm_play)
	SignalBus.bgm_stop.connect(_on_bgm_stop)
	SignalBus.sfx_play.connect(_on_sfx_play)

func _on_bgm_play(path: String, fade_time: float, volume: float = 0.0) -> void:
	var stream: AudioStream = load(path)
	if not stream:
		push_error("AudioManager: Could not load BGM at " + path)
		return

	var old_player: AudioStreamPlayer = bgm_players[active_bgm_idx]

	# Save the outgoing track's position before we switch.
	if _current_path != "" and old_player.playing:
		_saved_positions[_current_path] = old_player.get_playback_position()

	active_bgm_idx = (active_bgm_idx + 1) % 2
	var new_player: AudioStreamPlayer = bgm_players[active_bgm_idx]
	_current_path = path

	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	# Resume from saved position if we've heard this track before.
	if _saved_positions.has(path):
		new_player.seek(_saved_positions[path])

	var tw := create_tween().set_parallel(true)
	tw.tween_property(new_player, "volume_db", volume, fade_time).set_trans(Tween.TRANS_SINE)
	if old_player.playing:
		tw.tween_property(old_player, "volume_db", -80.0, fade_time).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(old_player.stop)

func _on_bgm_stop(fade_time: float) -> void:
	var current_player: AudioStreamPlayer = bgm_players[active_bgm_idx]
	if current_player.playing:
		# Save position so the track can resume from here later.
		if _current_path != "":
			_saved_positions[_current_path] = current_player.get_playback_position()
		var tw := create_tween()
		tw.tween_property(current_player, "volume_db", -80.0, fade_time)
		tw.tween_callback(current_player.stop)

func _on_sfx_play(path: String) -> void:
	var stream: AudioStream = load(path)
	if stream:
		sfx_player.stream = stream
		sfx_player.play()
