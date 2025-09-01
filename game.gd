extends Node2D

var tile_size: int = 16
var spikes: PackedScene = preload("res://objects/spikes.tscn")

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")


func _ready():
	var map_scene = preload("res://map/Map.tscn").instantiate()
	# connect to map_ready so we place the existing Player node when map is generated
	map_scene.connect("map_ready", Callable(self, "_on_map_ready"))
	add_child(map_scene)
	map_scene.log_room_doors()

func _on_map_ready(start_pos: Vector2) -> void:
	if player and is_instance_valid(player):
		player.global_position = start_pos
		print("[Game] Player position set to: ", start_pos)
	else:
		print("[Game] Cannot set Player position")
