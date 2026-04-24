extends Area2D

const PARALYZE_DURATION = 1.0

func _ready() -> void:
	body_entered.connect(on_body_entered)

func on_body_entered(body: Node2D) -> void:
	if body.name == "Marty":
		body.SPEED = 0
		hide()
		await get_tree().create_timer(PARALYZE_DURATION).timeout
		body.SPEED = 500.0
		queue_free()
