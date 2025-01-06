extends Node

class_name Branch

var left_child: Branch
var right_child: Branch
var position: Vector2i
var size: Vector2i

var min_room_size: int = 10

func _init(starting_position: Vector2i = Vector2i(), starting_size: Vector2i = Vector2i()):
	self.position = starting_position
	self.size = starting_size

func get_leaves() -> Array:
	if left_child == null and right_child == null:
		return [self]
	else:
		return left_child.get_leaves() + right_child.get_leaves()

func split(remaining: int):
	var split_horizontal: bool = randf() > 0.5
	if size.x > size.y:
		split_horizontal = false
	elif size.y > size.x:
		split_horizontal = true

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
			
func get_center() -> Vector2i:
	return position + size / 2

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
