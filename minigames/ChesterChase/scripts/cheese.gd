extends Area2D

const BOOST_AMOUNT = 200.0
const BOOST_DURATION = 3.0

func _ready() -> void:
	body_entered.connect(on_body_entered)

func on_body_entered(body: Node2D) -> void:
	if body.name == "Marty":
		body.SPEED += BOOST_AMOUNT
		hide()
		await get_tree().create_timer(BOOST_DURATION).timeout
		# Only subtract if node is still valid
		if is_instance_valid(body):
			body.SPEED -= BOOST_AMOUNT
		queue_free()
