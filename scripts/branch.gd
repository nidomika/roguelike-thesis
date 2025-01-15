extends Node
class_name Branch

var left_child: Branch
var right_child: Branch
var position: Vector2i
var size: Vector2i

var min_room_size: int = 10
var max_room_size: int = 22

var min_monster_spawn_size: Vector2i = Vector2i(8, 5)
var enemies_count: int = 0

var padding_left: int = randi_range(2, 3)
var padding_top: int = randi_range(2, 3)
var padding_right: int = randi_range(2, 3)
var padding_bottom: int = randi_range(2, 3)

var room_position: Vector2i = Vector2i()
var room_size: Vector2i = Vector2i()

var inside_pos: Vector2i
var inside_size: Vector2i


func _init(starting_position: Vector2i = Vector2i(), starting_size: Vector2i = Vector2i()):
	self.position = starting_position
	self.size = starting_size
	
	inside_pos = position + Vector2i(padding_left, padding_top)
	inside_size = size - Vector2i(padding_left + padding_right, padding_top + padding_bottom)
	
	room_position = inside_pos
	room_size = inside_size


# BSP
func get_leaves() -> Array:
	if left_child == null and right_child == null:
		return [self]
	else:
		return left_child.get_leaves() + right_child.get_leaves()


func split(remaining: int):
	if size.x <= max_room_size and size.y <= max_room_size:
		return
		
	var split_horizontal: bool
	var ratio = float(size.x) / float(size.y)

	if ratio > 1.6:
		split_horizontal = false
	elif ratio <= 0.5:
		split_horizontal = true
	else:
		split_horizontal = (randf() > 0.5)

	var max_split_point = (size.y if split_horizontal else size.x) - min_room_size
	if max_split_point <= min_room_size:
		return

	var split_point = randi_range(min_room_size, max_split_point)

	if split_horizontal:
		var left_height = split_point
		var right_height = size.y - split_point
		if left_height >= min_room_size and right_height >= min_room_size:
			left_child = Branch.new(position, Vector2i(size.x, left_height))
			right_child = Branch.new(Vector2i(position.x, position.y + left_height), Vector2i(size.x, right_height))
	else:
		var left_width = split_point
		var right_width = size.x - split_point
		if left_width >= min_room_size and right_width >= min_room_size:
			left_child = Branch.new(position, Vector2i(left_width, size.y))
			right_child = Branch.new(Vector2i(position.x + left_width, position.y), Vector2i(right_width, size.y))

	if (remaining > 0 and left_child != null and right_child != null):
		left_child.split(remaining - 1)
		right_child.split(remaining - 1)


func assign_monsters(min_monsters: int, max_monsters: int):
	if left_child == null and right_child == null:
		if room_size.x >= min_monster_spawn_size.x and room_size.y >= min_monster_spawn_size.y:
			enemies_count = randi_range(min_monsters, max_monsters)
		else:
			enemies_count = 0
	else:
		if left_child != null:
			left_child.assign_monsters(min_monsters, max_monsters)
		if right_child != null:
			right_child.assign_monsters(min_monsters, max_monsters)


# Minimum Spanning Tree
func get_center() -> Vector2i:
	return room_position + room_size / 2


func generate_mst_connections() -> Array:
	var rooms = get_leaves()
	if rooms.size() <= 1:
		return []

	var connected_rooms = []
	var available_edges = []
	var mst_connections = []

	connected_rooms.append(rooms[0].get_center())

	while connected_rooms.size() < rooms.size():
		for room_a in rooms:
			if not connected_rooms.has(room_a.get_center()):
				continue

			for room_b in rooms:
				if connected_rooms.has(room_b.get_center()) or room_a == room_b:
					continue

				var dist = room_a.get_center().distance_to(room_b.get_center())
				var edge = { "start": room_a.get_center(), "end": room_b.get_center(), "distance": dist }
				if not is_edge_duplicate(available_edges, edge):
					available_edges.append(edge)

		available_edges.sort_custom(compare_edges)
		if available_edges.size() == 0:
			break

		var shortest_edge = available_edges.pop_front()
		if connected_rooms.has(shortest_edge["end"]) and connected_rooms.has(shortest_edge["start"]):
			continue

		mst_connections.append(shortest_edge)
		if not connected_rooms.has(shortest_edge["end"]):
			connected_rooms.append(shortest_edge["end"])

	return mst_connections


func is_edge_duplicate(edges: Array, edge: Dictionary) -> bool:
	for e in edges:
		if (e["start"] == edge["end"] and e["end"] == edge["start"]) or (e["start"] == edge["start"] and e["end"] == edge["end"]):
			return true
	return false


func compare_edges(a, b) -> bool:
	return a["distance"] < b["distance"]
