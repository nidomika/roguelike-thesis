extends Object
class_name CorridorGenerator

@export var tile_size: int = 16
@export var max_nn_dist_tiles: int = 12

class Edge:
	var a: int
	var b: int
	var weight: float
	var axis: String
	var coord: float
	var depth: int = 0
	var fallback: bool = false

class UnionFind:
	var parent: Array
	func _init(n:int):
		parent = []
		for i in range(n):
			parent.append(i)
	func find(x:int) -> int:
		if parent[x] != x:
			parent[x] = find(parent[x])
		return parent[x]
	func union(a:int,b:int) -> void:
		var ra = find(a)
		var rb = find(b)
		if ra != rb:
			parent[rb] = ra

func generate_mst(rooms:Array, bsp_root, tile_size_in:int) -> Array:
	self.tile_size = tile_size_in
	var n = rooms.size()
	if n <= 1:
		return []

	var edges = _collect_candidate_edges(bsp_root, rooms)
	_ensure_connectivity(edges, rooms)
	
	edges.sort_custom(Callable(self, "_edge_compare"))

	var uf = UnionFind.new(n)
	var conns := []
	for e in edges:
		if uf.find(e.a) != uf.find(e.b):
			uf.union(e.a, e.b)
			var conn = _make_connection(rooms[e.a], rooms[e.b])
			conn["room_a_index"] = e.a
			conn["room_b_index"] = e.b
			conns.append(conn)

	return conns

func _edge_compare(a: Edge, b: Edge) -> bool:
	if a.depth != b.depth:
		return a.depth > b.depth
	return a.weight < b.weight

func _collect_candidate_edges(node, rooms: Array) -> Array:
	var out_edges = []
	_collect_edges_recursive(node, rooms, out_edges, 0)
	return out_edges

func _collect_edges_recursive(node, rooms:Array, out_edges:Array, depth: int=0) -> void:
	if node == null or node.left == null or node.right == null:
		return

	var left_rooms = _rooms_in_node(node.left, rooms)
	var right_rooms = _rooms_in_node(node.right, rooms)

	if left_rooms.is_empty() or right_rooms.is_empty():
		_collect_edges_recursive(node.left, rooms, out_edges, depth + 1)
		_collect_edges_recursive(node.right, rooms, out_edges, depth + 1)
		return

	var best_edge: Edge = null
	var best_weight: float = 1e20

	for ai in left_rooms:
		for bi in right_rooms:
			var ra = rooms[ai].room_rect
			var rb = rooms[bi].room_rect
			var weight: float
			var coord: float
			var axis: String

			if node.is_vertical_split:
				axis = "h"
				var overlap = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y) - max(ra.position.y, rb.position.y)
				var dist = max(0.0, rb.position.x - (ra.position.x + ra.size.x))
				if overlap > 0:
					weight = dist
					coord = floor(((max(ra.position.y, rb.position.y) + min(ra.position.y + ra.size.y, rb.position.y + rb.size.y)) * 0.5) / tile_size) * tile_size + tile_size * 0.5
				else:
					weight = dist + 10000.0
			else:
				axis = "v"
				var overlap = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x) - max(ra.position.x, rb.position.x)
				var dist = max(0.0, rb.position.y - (ra.position.y + ra.size.y))
				if overlap > 0:
					weight = dist
					coord = floor(((max(ra.position.x, rb.position.x) + min(ra.position.x + ra.size.x, rb.position.x + rb.size.x)) * 0.5) / tile_size) * tile_size + tile_size * 0.5
				else:
					weight = dist + 10000.0
			
			if weight < best_weight:
				best_weight = weight
				best_edge = Edge.new()
				best_edge.a = ai
				best_edge.b = bi
				best_edge.weight = weight
				best_edge.axis = axis
				best_edge.coord = coord
				best_edge.depth = depth

	if best_edge:
		out_edges.append(best_edge)

	_collect_edges_recursive(node.left, rooms, out_edges, depth + 1)
	_collect_edges_recursive(node.right, rooms, out_edges, depth + 1)

func _ensure_connectivity(edges: Array, rooms: Array) -> void:
	var n = rooms.size()
	if n <= 1:
		return

	var uf = UnionFind.new(n)
	for edge in edges:
		uf.union(edge.a, edge.b)

	var components = {}
	for i in range(n):
		var root = uf.find(i)
		if not components.has(root):
			components[root] = []
		components[root].append(i)

	if components.size() <= 1:
		return

	while components.size() > 1:
		var comp_keys = components.keys()
		var comp1_indices = components[comp_keys[0]]
		var best_edge: Edge = null
		var min_dist = 1e20

		for i in comp1_indices:
			for j in range(n):
				if uf.find(i) != uf.find(j):
					var dist = rooms[i].get_center().distance_to(rooms[j].get_center())
					if dist < min_dist:
						min_dist = dist
						best_edge = Edge.new()
						best_edge.a = i
						best_edge.b = j
						best_edge.weight = dist
						best_edge.fallback = true
		
		if best_edge:
			edges.append(best_edge)
			uf.union(best_edge.a, best_edge.b)
			components = {}
			for i in range(n):
				var root = uf.find(i)
				if not components.has(root):
					components[root] = []
				components[root].append(i)
		else:
			break

func _rooms_in_node(node, rooms:Array) -> Array:
	var idxs := []
	if not node:
		return idxs
	var rrect = node.rect
	for i in range(rooms.size()):
		var room_center = rooms[i].get_center()
		if rrect.has_point(room_center):
			idxs.append(i)
	return idxs

func _make_connection(room_a, room_b) -> Dictionary:
	var ra = room_a.room_rect
	var rb = room_b.room_rect
	var overlap_y = max(0, min(ra.end.y, rb.end.y) - max(ra.position.y, rb.position.y))
	var conn := {}

	if overlap_y > 0: # Horizontal corridor
		var y_center = (max(ra.position.y, rb.position.y) + min(ra.end.y, rb.end.y)) / 2
		var left_room = ra if ra.position.x < rb.position.x else rb
		var right_room = rb if ra.position.x < rb.position.x else ra
		
		var start_x = left_room.end.x
		var end_x = right_room.position.x
		var corridor_width = end_x - start_x
		
		var floor_rect = Rect2(start_x, y_center - tile_size, corridor_width, tile_size * 2)
		
		var door_a_y = int(y_center / tile_size)
		var door_b_y = int(y_center / tile_size)
		
		var door_a_x = int(start_x / tile_size)
		var door_b_x = int(end_x / tile_size) - 1
		
		conn = {
			"floor_rect": floor_rect,
			"door_a_tile": Vector2i(door_a_x, door_a_y),
			"door_a_tiles": [Vector2i(door_a_x, door_a_y), Vector2i(door_a_x, door_a_y - 1)],
			"door_b_tile": Vector2i(door_b_x, door_b_y),
			"door_b_tiles": [Vector2i(door_b_x, door_b_y), Vector2i(door_b_x, door_b_y - 1)],
		}
	else: # Vertical corridor
		var x_center = (max(ra.position.x, rb.position.x) + min(ra.end.x, rb.end.x)) / 2
		var top_room = ra if ra.position.y < rb.position.y else rb
		var bottom_room = rb if ra.position.y < rb.position.y else ra

		var start_y = top_room.end.y
		var end_y = bottom_room.position.y
		var corridor_height = end_y - start_y

		var floor_rect = Rect2(x_center - tile_size, start_y, tile_size * 2, corridor_height)
		
		var door_a_x = int(x_center / tile_size)
		var door_b_x = int(x_center / tile_size)
		
		var door_a_y = int(start_y / tile_size)
		var door_b_y = int(end_y / tile_size) - 1

		conn = {
			"floor_rect": floor_rect,
			"door_a_tile": Vector2i(door_a_x, door_a_y),
			"door_a_tiles": [Vector2i(door_a_x, door_a_y), Vector2i(door_a_x - 1, door_a_y)],
			"door_b_tile": Vector2i(door_b_x, door_b_y),
			"door_b_tiles": [Vector2i(door_b_x, door_b_y), Vector2i(door_b_x - 1, door_b_y)],
		}
	return conn
