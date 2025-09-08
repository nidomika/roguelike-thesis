extends Node2D
class_name Spawner

signal cleared(room_index: int)

@export var enemy_scenes: Array

var live_enemies: Array = []

@export var min_enemies: int = 1
@export var max_enemies: int = 8
@export var tiles_per_enemy: int = 16

func spawn_in_room(room_node: Node2D, room_index: int, spawn_rect: Rect2, tile_size: int) -> void:
	var room_area_tiles = (spawn_rect.size.x / tile_size) * (spawn_rect.size.y / tile_size)
	var count = clamp(int(room_area_tiles / tiles_per_enemy), min_enemies, max_enemies)

	var candidates = _get_spawn_candidates(spawn_rect, tile_size)
	var spawn_count = min(count, candidates.size())

	for i in range(spawn_count):
		var cell: Vector2i = candidates.pick_random()
		candidates.erase(cell)

		var world_pos = Vector2(cell.x * tile_size + tile_size * 0.5, cell.y * tile_size + tile_size * 0.5)
		var enemy_scene = enemy_scenes.pick_random()
		var enemy = enemy_scene.instantiate()

		live_enemies.append(enemy)
		enemy.connect("tree_exited", Callable(self, "_on_enemy_tree_exited").bind(enemy, room_index))

		room_node.add_child(enemy)
		enemy.global_position = world_pos


func _get_spawn_candidates(spawn_rect: Rect2, tile_size: int) -> Array[Vector2i]:
	var start_x = int(floor(spawn_rect.position.x / tile_size))
	var start_y = int(floor(spawn_rect.position.y / tile_size))
	var end_x = int(floor(spawn_rect.end.x / tile_size))
	var end_y = int(floor(spawn_rect.end.y / tile_size))

	var inner_cells: Array[Vector2i] = []
	for x in range(start_x + 1, end_x - 1):
		for y in range(start_y + 1, end_y - 1):
			inner_cells.append(Vector2i(x, y))

	if not inner_cells.is_empty():
		return inner_cells

	var all_cells: Array[Vector2i] = []
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			all_cells.append(Vector2i(x, y))

	return all_cells


func _on_enemy_tree_exited(enemy: Node, room_index: int) -> void:
	if enemy in live_enemies:
		live_enemies.erase(enemy)
	if live_enemies.is_empty():
		emit_signal("cleared", room_index)
