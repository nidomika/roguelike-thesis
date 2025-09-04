extends Node2D
class_name Spawner

signal cleared(room_index: int)

const GOBLIN_SCENE := preload("res://characters/enemies/goblin/goblin.tscn")
const BAT_SCENE := preload("res://characters/enemies/bat/bat.tscn")

var live_enemies: Array = []

func _ready() -> void:
	# ensure random seeded elsewhere; project usually seeds in a global singleton
	pass

func start_spawn_for_room(room_index: int, count: int, room_rect: Rect2 = Rect2(), tile_size: int = 16) -> void:
	var room = get_parent()
	if room == null:
		push_warning("Spawner has no parent room")
		return

	var tile_sz: int = int(tile_size)

	var floor_cells: Array = []
	# If caller provided a room_rect (non-empty), compute tile coords inside that rect
	if room_rect.size != Vector2.ZERO:
		var start_x = int(floor(room_rect.position.x / tile_sz))
		var start_y = int(floor(room_rect.position.y / tile_sz))
		var w = int(floor(room_rect.size.x / tile_sz))
		var h = int(floor(room_rect.size.y / tile_sz))
		for x in range(start_x, start_x + w):
			for y in range(start_y, start_y + h):
				floor_cells.append(Vector2i(x, y))
	else:
		if room.has_method("get_floor_cells"):
			floor_cells = room.get_floor_cells()

	# fallback: place a single spawn at room center
	if floor_cells.is_empty():
		var center = room.get_center() if room.has_method("get_center") else Vector2.ZERO
		var c = Vector2i(int(center.x / tile_sz), int(center.y / tile_sz))
		floor_cells = [c]

	# Exclude outer edge tiles to avoid spawning on doors/walls
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF
	for c in floor_cells:
		if c.x < min_x: min_x = c.x
		if c.x > max_x: max_x = c.x
		if c.y < min_y: min_y = c.y
		if c.y > max_y: max_y = c.y

	var inner_cells: Array = []
	for c in floor_cells:
		if c.x > min_x and c.x < max_x and c.y > min_y and c.y < max_y:
			inner_cells.append(c)

	var candidates = inner_cells if not inner_cells.is_empty() else floor_cells.duplicate()

	var spawn_n = int(count)
	if spawn_n <= 0:
		spawn_n = randi_range(1, 3)
	spawn_n = min(spawn_n, candidates.size())

	for i in range(spawn_n):
		if candidates.is_empty():
			break
		var idx = randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[idx]
		candidates.remove_at(idx)

		var world_pos = Vector2(cell.x * tile_sz + tile_sz * 0.5, cell.y * tile_sz + tile_sz * 0.5)

		var scene := GOBLIN_SCENE if randf() < 0.5 else BAT_SCENE
		var enemy = scene.instantiate()

		# add to tracking list before it can be removed
		live_enemies.append(enemy)

		# connect to tree_exited to detect when it is removed/freed
		enemy.connect("tree_exited", Callable(self, "_on_enemy_tree_exited").bind(enemy, room_index))

		# attach to room so it moves with the room and is logically grouped
		room.add_child(enemy)

		# position enemy in world coordinates (use global_position so parent offset is handled)
		if enemy is Node2D:
			enemy.global_position = world_pos
		elif enemy.has_method("set_global_position"):
			enemy.set_global_position(world_pos)

	# nothing spawned -> immediately emit cleared
	if live_enemies.is_empty():
		print("[Spawner] immediate cleared room=", room_index)
		emit_signal("cleared", room_index)

func _on_enemy_tree_exited(enemy: Node, room_index: int) -> void:
	if enemy in live_enemies:
		live_enemies.erase(enemy)
	if live_enemies.is_empty():
		print("[Spawner] all enemies gone, cleared room=", room_index)
		emit_signal("cleared", room_index)
