extends Node2D

var tile_size: int = 16
var spikes: PackedScene = preload("res://objects/spikes.tscn")

@onready var player: Character = get_node("Player")


func _ready():
	var map_scene = preload("res://map/Map.tscn").instantiate()
	map_scene.connect("map_ready", Callable(self, "_on_map_ready"))
	map_scene.connect("boss_triggered", Callable(self, "_on_boss_triggered"))
	add_child(map_scene)


func _on_map_ready(start_pos: Vector2) -> void:
	player.global_position = start_pos + Vector2(-10,-10) #!!!! ZMIENIC POTEM


func _on_boss_triggered(triggering_player: Node) -> void:
	var boss_scene = preload("res://map/rooms/boss_room/boss_room.tscn")
	var boss_room = boss_scene.instantiate()
	
	if not is_instance_valid(boss_room):
		return

	var existing_map = get_node("Map")
	existing_map.queue_free()

	call_deferred("add_child", boss_room)
	
	var spawn_pos = triggering_player.global_position
	boss_room.global_position = spawn_pos 
	triggering_player.global_position = boss_room.get_node("PlayerStart").global_position
	boss_room.get_node("Camera2D").enabled = true
