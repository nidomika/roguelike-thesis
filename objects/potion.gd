extends Area2D
class_name Potion

@export var heal_amount: int = 2

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: CharacterBody2D) -> void:
	if body.name == "Player":
		body.heal(heal_amount)
		queue_free()
