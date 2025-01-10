extends Area2D
class_name Hitbox

@export var damage: int = 1
var knockback_direction: Vector2 = Vector2.ZERO
@export var knockback_force: int = 300

@onready var collision_shape: CollisionShape2D = get_child(0)


func _init() -> void:
	var __ = connect("body_entered", Callable(self, "_on_body_entered"))
	__ = connect("body_exited", Callable(self, "_on_body_exited"))


func _ready() -> void:
	assert(collision_shape != null)


func _on_body_entered(body: Node2D) -> void:
	_collide(body)


func _collide(body: Node2D) -> void:
	if body == null or not body.has_method("take_damage"):
		queue_free()
	else:
		body.take_damage(damage, knockback_direction, knockback_force)
