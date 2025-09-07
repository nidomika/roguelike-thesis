extends Node2D
class_name Room

var room_rect: Rect2
var door_positions: Array = []
var is_cleared: bool = false

var SpawnerScript = preload("res://map/spawner.gd")

const GOBLIN_SCENE := preload("res://characters/enemies/goblin/goblin.tscn")
const BAT_SCENE := preload("res://characters/enemies/bat/bat.tscn")

signal player_entered(room_index)

func _init(rect: Rect2):
	self.room_rect = rect

func setup_detector(tile_size: int, room_index: int) -> void:
	var det_scene = load("res://miscellaneous/player_detector.tscn")
	var det = det_scene.instantiate()
	det.room_size = get_size_tiles() - Vector2i(1, 1)
	det.tile_size = tile_size
	det.position = room_rect.size * 0.5
	add_child(det)
	
	det.connect("player_entered", Callable(self, "_on_detector_player_entered").bind(room_index))

	if not has_node("Spawner"):
		var spawner = SpawnerScript.new()
		spawner.name = "Spawner"
		spawner.enemy_scenes = [GOBLIN_SCENE, BAT_SCENE]
		add_child(spawner)


func _on_detector_player_entered(room_index: int) -> void:
	emit_signal("player_entered", room_index)

func get_center() -> Vector2i:
	return Vector2i(room_rect.position + room_rect.size * 0.5)

func get_size_tiles() -> Vector2i:
	if not room_rect:
		return Vector2i.ZERO
	var tile_size = 16.0
	return Vector2i(int(room_rect.size.x / tile_size), int(room_rect.size.y / tile_size))
