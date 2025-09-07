extends Node2D

var tile_size: int = 16
var spikes: PackedScene = preload("res://objects/spikes.tscn")

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")


func _ready():
	var map_scene = preload("res://map/Map.tscn").instantiate()
	# connect to map_ready so we place the existing Player node when map is generated
	map_scene.connect("map_ready", Callable(self, "_on_map_ready"))
	# connect the boss trigger signal so Game will handle boss transitions
	if map_scene.has_signal("boss_triggered"):
		map_scene.connect("boss_triggered", Callable(self, "_on_boss_triggered"))
	add_child(map_scene)

func go_to_boss_room(triggering_player: Node) -> void:
	# Wrapper so Map can call Game.go_to_boss_room(player_node) directly.
	_on_boss_triggered(triggering_player)

func _on_map_ready(start_pos: Vector2) -> void:
	if player and is_instance_valid(player):
		player.global_position = start_pos + Vector2(-10,-10) #!!!! ZMIENIC POTEM
		print("[Game] Player position set to: ", start_pos)
	else:
		print("[Game] Cannot set Player position")

func _on_boss_triggered(triggering_player: Node) -> void:
	# preload boss room
	var boss_scene = preload("res://map/rooms/boss_room/boss_room.tscn")
	var boss = boss_scene.instantiate()
	# Defer adding the boss scene to avoid changing physics/monitoring state while
	# the engine is flushing queries (prevents "Can't change this state while flushing queries").
	call_deferred("_deferred_start_boss_sequence", boss, triggering_player)


func _deferred_start_boss_sequence(boss: Node, triggering_player: Node) -> void:
	if not is_instance_valid(boss):
		return
	# If an existing Map instance is present, remove it to avoid the boss
	# scene spawning at (0,0) underneath the map.
	var existing_map: Node = null
	if has_node("Map"):
		existing_map = get_node("Map")
	else:
		existing_map = get_tree().get_root().find_node("Map", true, false)
	if existing_map and is_instance_valid(existing_map):
		print("[Game] Removing existing Map before spawning boss")
		existing_map.queue_free()

	# Determine intended spawn position (player position) if available
	var spawn_pos := Vector2.ZERO
	if triggering_player and is_instance_valid(triggering_player):
		spawn_pos = triggering_player.global_position

	# Place the boss initially far away to avoid overlapping navmeshes and geometry
	var safe_offset = Vector2(10000, 10000)
	boss.global_position = spawn_pos + safe_offset
	print(boss.global_position)
	get_tree().get_root().add_child(boss)

	# After the map is freed and the tree settles, move the boss into the intended position
	call_deferred("_deferred_move_boss_into_position", boss, spawn_pos, triggering_player)


func _deferred_move_boss_into_position(boss: Node, spawn_pos: Vector2, triggering_player: Node) -> void:
	if not is_instance_valid(boss):
		return
	boss.global_position = spawn_pos
	# Now defer the reparent to the next idle to be extra-safe
	call_deferred("_deferred_reparent_player_to_boss", triggering_player, boss)
	
func _deferred_reparent_player_to_boss(triggering_player: Node, boss: Node) -> void:
		if not is_instance_valid(triggering_player) or not is_instance_valid(boss):
			return
		var old_parent = triggering_player.get_parent()
		old_parent.remove_child(triggering_player)
		boss.add_child(triggering_player)
		if boss.has_node("PlayerStart"):
			triggering_player.global_position = boss.get_node("PlayerStart").global_position
		if boss.has_node("Camera2D"):
			boss.get_node("Camera2D").enabled = true
		# opcjonalnie: ukryj mapę, zmień muzykę, UI itp.
