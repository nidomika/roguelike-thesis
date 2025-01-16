extends Node
class_name Branch

var left_child: Branch
var right_child: Branch
var position: Vector2i
var size: Vector2i

var min_room_size: int = 12
var max_room_size: int = 22

var min_monster_spawn_size: Vector2i = Vector2i(7, 5)
var enemies_count: int = 0

var padding_left: int = randi_range(2, 2)
var padding_top: int = randi_range(2, 2)
var padding_right: int = randi_range(2, 2)
var padding_bottom: int = randi_range(2, 2)

var room_position: Vector2i = Vector2i()
var room_size: Vector2i = Vector2i()

var inside_pos: Vector2i
var inside_size: Vector2i


func _init(starting_position: Vector2i = Vector2i(), starting_size: Vector2i = Vector2i()):
	self.position = starting_position
	self.size = starting_size
	
	inside_pos = position + Vector2i(padding_left, padding_top) + Vector2i(1, 1)
	inside_size = size - Vector2i(padding_left + padding_right, padding_top + padding_bottom) - Vector2i(2, 2)

	room_position = inside_pos
	room_size = inside_size


# BSP
func get_leaves() -> Array:
	if left_child == null and right_child == null:
		return [self]
	else:
		return left_child.get_leaves() + right_child.get_leaves()


func split(remaining: int) -> void:
	if size.x <= max_room_size and size.y <= max_room_size:
		return

	if remaining <= 0:
		return

	var split_horizontal: bool
	var ratio = float(size.x) / float(size.y)
	if ratio > 1.6:
		split_horizontal = false
	elif ratio < 0.6:
		split_horizontal = true
	else:
		split_horizontal = randf() < 0.5

	var dimension =  size.y if split_horizontal else size.x

	if dimension < min_room_size * 2:
		return

	var split_point = randi_range(min_room_size, dimension - min_room_size)

	if split_horizontal:
		var top_height = split_point
		var bottom_height = size.y - split_point
		left_child = Branch.new(position, Vector2i(size.x, top_height))
		right_child = Branch.new(Vector2i(position.x, position.y + top_height), Vector2i(size.x, bottom_height))
	else:
		var left_width = split_point
		var right_width = size.x - split_point
		left_child = Branch.new(position, Vector2i(left_width, size.y))
		right_child = Branch.new(Vector2i(position.x + left_width, position.y), Vector2i(right_width, size.y))

	left_child.split(remaining - 1)
	right_child.split(remaining - 1)


func assign_monsters(min_monsters: int, max_monsters: int):
	if left_child == null and right_child == null:
		if room_size.x >= min_monster_spawn_size.x and room_size.y >= min_monster_spawn_size.y:
			var room_area = room_size.x * room_size.y

			var max_area = max_room_size * max_room_size
			var proportion = float(room_area) / max_area

			enemies_count = int(lerp(min_monsters, max_monsters, proportion))
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

	connected_rooms.append(rooms[0].get_corridor_entrance())

	while connected_rooms.size() < rooms.size():
		for room_a in rooms:
			if not connected_rooms.has(room_a.get_corridor_entrance()):
				continue

			for room_b in rooms:
				if connected_rooms.has(room_b.get_corridor_entrance()) or room_a == room_b:
					continue

				var dist = room_a.get_corridor_entrance().distance_to(room_b.get_corridor_entrance())
				var edge = { "start": room_a.get_corridor_entrance(), "end": room_b.get_corridor_entrance(), "distance": dist }
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


func get_corridor_entrance() -> Vector2i:
	var c = room_position + room_size / 2
	return c + Vector2i(-1, 0)


func is_edge_duplicate(edges: Array, edge: Dictionary) -> bool:
	for e in edges:
		if (e["start"] == edge["end"] and e["end"] == edge["start"]) or (e["start"] == edge["start"] and e["end"] == edge["end"]):
			return true
	return false


func compare_edges(a, b) -> bool:
	return a["distance"] < b["distance"]


#func compare_edges(a, b) -> bool:
	#var manhattan_dist_a = abs(a["start"].x - a["end"].x) + abs(a["start"].y - a["end"].y)
	#var manhattan_dist_b = abs(b["start"].x - b["end"].x) + abs(b["start"].y - b["end"].y)
	#return manhattan_dist_a < manhattan_dist_b


func build_adjacency(rooms: Array, mst_edges: Array) -> Dictionary:
	var adjacency = {}

	for r in rooms:
		adjacency[r.get_corridor_entrance()] = []

	for edge in mst_edges:
		var start = edge["start"]
		var end = edge["end"]
		var dist = edge["distance"]

		adjacency[start].append({ "to": end, "distance": dist })
		adjacency[end].append({ "to": start, "distance": dist })

	return adjacency


func bfs_farthest(adjacency: Dictionary, start_node: Vector2i) -> Dictionary:
	var visited = {}
	var queue = []
	var distance_map = {}

	for node in adjacency.keys():
		visited[node] = false
		distance_map[node] = 999999

	distance_map[start_node] = 0
	visited[start_node] = true
	queue.append(start_node)

	while queue.size() > 0:
		var current = queue.pop_front()
		for neighbor in adjacency[current]:
			var next_node = neighbor["to"]
			var edge_dist = neighbor["distance"]
			if not visited[next_node]:
				visited[next_node] = true
				distance_map[next_node] = distance_map[current] + edge_dist
				queue.append(next_node)

	var farthest_node = start_node
	var max_dist = distance_map[start_node]

	for node in adjacency.keys():
		if distance_map[node] > max_dist:
			max_dist = distance_map[node]
			farthest_node = node

	return {
		"farthest_node": farthest_node,
		"distance": max_dist
	}


func find_two_farthest_rooms(rooms: Array, mst_edges: Array) -> Dictionary:
	var adjacency = build_adjacency(rooms, mst_edges)

	if rooms.size() == 0:
		return {}

	var first_center = rooms[0].get_corridor_entrance()

	var result1 = bfs_farthest(adjacency, first_center)
	var X = result1["farthest_node"]

	var result2 = bfs_farthest(adjacency, X)
	var Y = result2["farthest_node"]
	var distanceXY = result2["distance"]

	return {
		"start": X,
		"end": Y,
		"distance": distanceXY
	}
