extends Area2D

var room_size: Vector2i
var tile_size: int = 16
var room_position: Vector2i

signal player_entered


func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	var shape = $CollisionShape2D.shape as RectangleShape2D
	# use Vector2 for shape size (pixels)
	shape.size = Vector2(room_size.x * tile_size, room_size.y * tile_size)

	# keep the Area2D node position if the parent (Room) already set it
	# (do not override position here)
	$CollisionShape2D.position = Vector2.ZERO


func _on_body_entered(body: CharacterBody2D) -> void:
	if body.name == "Player":
		print("[PlayerDetector] Player entered detector at global_pos=", global_position)
		player_entered.emit()
		queue_free()
