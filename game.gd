extends Node2D

var tile_size: int = 16
var spikes: PackedScene = preload("res://objects/spikes.tscn")

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")


func _ready():
	var map_scene = preload("res://map/Map.tscn").instantiate()
	add_child(map_scene)
