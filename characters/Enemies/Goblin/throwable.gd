extends Hitbox

var enemy_exited: bool = false

var direction: Vector2 = Vector2.ZERO
var throwable_speed: int = 0


func launch(initial_position: Vector2, dir: Vector2, speed: int) -> void:
	position = initial_position
	direction = dir
	knockback_direction = dir
	throwable_speed = speed
	
	rotation += dir.angle()


func _physics_process(delta: float) -> void:
	position += direction * throwable_speed * delta


func _on_body_exited(_body: Node2D) -> void:
	if not enemy_exited:
		enemy_exited = true
		set_collision_mask_value(1, true)
		set_collision_mask_value(2, true)


func _collide(body: Node2D) -> void:
	if enemy_exited:
		if body.has_method("take_damage"):
			body.take_damage(damage, knockback_direction, knockback_force)
		queue_free()
