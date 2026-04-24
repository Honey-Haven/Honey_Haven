extends Node2D

@export var drop_scene:   PackedScene = preload("res://minigames/ChesterChase/scenes/cheese.tscn")
@export var trap_scene:   PackedScene = preload("res://minigames/ChesterChase/scenes/mouse_trap.tscn")
@export var portal_scene: PackedScene = preload("res://minigames/ChesterChase/scenes/portal.tscn")
@export var drop_interval:   float = 8.0
@export var trap_interval:   float = 10.0
@export var portal_interval: float = 12.0
var time_left: float  = 30.0
var portal_count: int = 0

# Safe spawn region — stays well inside the background (world half-extents ±1280/±720)
# and away from the boundary walls (inner boundary ~±1150/±645).
const SPAWN_HALF_W: float = 1000.0
const SPAWN_HALF_H: float = 540.0

func _ready() -> void:
	var drop_timer := Timer.new()
	add_child(drop_timer)
	drop_timer.wait_time = drop_interval
	drop_timer.timeout.connect(spawn_drop)
	drop_timer.start()

	var trap_timer := Timer.new()
	add_child(trap_timer)
	trap_timer.wait_time = trap_interval
	trap_timer.timeout.connect(spawn_trap)
	trap_timer.start()

	var portal_timer := Timer.new()
	add_child(portal_timer)
	portal_timer.wait_time = portal_interval
	portal_timer.timeout.connect(spawn_portals)
	portal_timer.start()

	var my_font: Font = load("res://minigames/ChesterChase/sprites/CookieCrisp-L36ly.ttf")
	$Label.add_theme_font_override("font", my_font)
	$Label.add_theme_font_size_override("font_size", 64)

	var game_timer := Timer.new()
	add_child(game_timer)
	game_timer.wait_time = time_left
	game_timer.one_shot  = true
	game_timer.timeout.connect(time_up)
	game_timer.start()

func _process(delta: float) -> void:
	time_left -= delta
	$Label.text = str(snappedf(time_left, 0.1)) + "s"

func spawn_drop() -> void:
	var obj := drop_scene.instantiate() as Node2D
	add_child(obj)
	obj.position = _random_spawn_pos()

func spawn_trap() -> void:
	var trap := trap_scene.instantiate() as Node2D
	add_child(trap)
	trap.position = _random_spawn_pos()

func spawn_portals() -> void:
	if portal_count >= 2:
		return
	var portal1 := portal_scene.instantiate() as ChesterPortal
	var portal2 := portal_scene.instantiate() as ChesterPortal
	add_child(portal1)
	add_child(portal2)
	portal1.position = _random_spawn_pos()
	portal2.position = _random_spawn_pos()
	portal1.linked_portal = portal2
	portal2.linked_portal = portal1
	portal_count = 2
	portal1.used.connect(on_portal_used)
	portal2.used.connect(on_portal_used)

func _random_spawn_pos() -> Vector2:
	return Vector2(
		randf_range(-SPAWN_HALF_W, SPAWN_HALF_W),
		randf_range(-SPAWN_HALF_H, SPAWN_HALF_H)
	)

func on_portal_used() -> void:
	portal_count = 0

func time_up() -> void:
	get_tree().change_scene_to_file.call_deferred("res://minigames/ChesterChase/scenes/cc_game_won.tscn")
