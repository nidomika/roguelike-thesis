extends Area2D

var room_size: Vector2i
var tile_size: int = 16
var room_position: Vector2i

signal player_entered


func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	var shape = $CollisionShape2D.shape as RectangleShape2D
	shape.size = Vector2i(room_size.x * tile_size, room_size.y * tile_size)
	
	$CollisionShape2D.position = Vector2i.ZERO
	position = Vector2i.ZERO


func _on_body_entered(body: CharacterBody2D) -> void:
	if body.name == "Player":
		player_entered.emit()
		queue_free()
