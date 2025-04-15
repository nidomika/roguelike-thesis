extends Node2D

var tile_size: int = 16
var spikes: PackedScene = preload("res://rooms/spikes.tscn")

@export var world_size: Vector2i = Vector2i(100, 60)

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")


var spawn_room_coords: Vector2i
var boss_room_coords: Vector2i
