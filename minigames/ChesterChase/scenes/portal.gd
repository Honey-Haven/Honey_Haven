class_name ChesterPortal
extends Area2D

var linked_portal: Area2D
signal used

func _ready() -> void:
	body_entered.connect(on_body_entered)

func on_body_entered(body: Node2D) -> void:
	if body.name == "Marty":
		body.global_position = linked_portal.global_position
		used.emit()
		linked_portal.queue_free()
		queue_free()
