extends Object
class_name CorridorGenerator

# Simple BSP-aware corridor generator
# - collects one candidate edge per internal BSP node by picking one room from left subtree and one from right
# - prefers pairs whose projections overlap on the perpendicular axis so corridors are straight
# - runs Kruskal's MST over candidate edges to ensure no cycles
# - outputs connections with door positions and Rect2 geometry for 2-tile-wide floor + 1-tile walls

var tile_size: int = 16

class Edge:
	var a: int
	var b: int
	var weight: float
	var axis: String
	var coord: float
	var depth: int = 0

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
	tile_size = tile_size_in
	var n = rooms.size()
	if n <= 1:
		return []

	# collect candidate edges from BSP internal nodes
	var edges := []
	_collect_edges(bsp_root, rooms, edges, 0)

	# sort edges by depth (desc) then weight (asc)
	for i in range(1, edges.size()):
		var key = edges[i]
		var j = i - 1
		while j >= 0 and ((edges[j].depth < key.depth) or (edges[j].depth == key.depth and edges[j].weight > key.weight)):
			edges[j + 1] = edges[j]
			j -= 1
		edges[j + 1] = key

	# debug: how many candidate edges
	print("[CorridorGenerator] candidates=", edges.size())
	# Kruskal
	var uf = UnionFind.new(n)
	var conns := []
	for e in edges:
		if uf.find(e.a) != uf.find(e.b):
			uf.union(e.a, e.b)
			conns.append(_make_connection(rooms[e.a], rooms[e.b]))

	return conns

func _edge_compare(a:Edge, b:Edge) -> int:
	if a.weight < b.weight:
		return -1
	elif a.weight > b.weight:
		return 1
	return 0

func _collect_edges(node, rooms:Array, out_edges:Array, depth: int=0) -> void:
	if node == null:
		return
	if node.left != null and node.right != null:
		var left_rooms = _rooms_in_node(node.left, rooms)
		var right_rooms = _rooms_in_node(node.right, rooms)
		if left_rooms.size() > 0 and right_rooms.size() > 0:
			var best: Edge = null
			var best_w: float = 1e20
			var chosen_coord: float = 0.0
			# iterate pairs and prefer positive overlap on perpendicular axis
			for ai in left_rooms:
				var ra = rooms[ai].room_rect
				for bi in right_rooms:
					var rb = rooms[bi].room_rect
					if node.is_vertical_split:
						# vertical split -> rooms on left/right -> we want horizontal corridor; overlap on y
						var overlap = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y) - max(ra.position.y, rb.position.y)
						if overlap > 0:
							# weight by horizontal distance between room edges
							var dx = max(0.0, rb.position.x - (ra.position.x + ra.size.x))
							var w = dx
							if w < best_w:
								best_w = w
								best = Edge.new()
								best.a = ai
								best.b = bi
								best.weight = w
								best.axis = "h"
								# pick coordinate inside overlap (tile aligned)
								var y0 = max(ra.position.y, rb.position.y)
								var y1 = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y)
								chosen_coord = floor(((y0 + y1) * 0.5) / tile_size) * tile_size + tile_size * 0.5
								best.coord = chosen_coord
					else:
						# horizontal split -> rooms on top/bottom -> want vertical corridor; overlap on x
						var overlapx = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x) - max(ra.position.x, rb.position.x)
						if overlapx > 0:
							var dy = max(0.0, rb.position.y - (ra.position.y + ra.size.y))
							var w = dy
							if w < best_w:
								best_w = w
								best = Edge.new()
								best.a = ai
								best.b = bi
								best.weight = w
								best.axis = "v"
								var x0 = max(ra.position.x, rb.position.x)
								var x1 = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x)
								chosen_coord = floor(((x0 + x1) * 0.5) / tile_size) * tile_size + tile_size * 0.5
								best.coord = chosen_coord
			# if we found a pair with overlap, append (store depth)
			if best != null:
				best.depth = depth
				out_edges.append(best)
	# recurse children with increased depth
	_collect_edges(node.left, rooms, out_edges, depth + 1)
	_collect_edges(node.right, rooms, out_edges, depth + 1)

func _rooms_in_node(node, rooms:Array) -> Array:
	var idxs := []
	var rrect = node.rect
	for i in range(rooms.size()):
		var rr = rooms[i].leaf_rect
		# check if the leaf rect is inside the node rect (using position)
		if rr.position.x >= rrect.position.x and rr.position.y >= rrect.position.y and rr.position.x + rr.size.x <= rrect.position.x + rrect.size.x and rr.position.y + rr.size.y <= rrect.position.y + rrect.size.y:
			idxs.append(i)
	return idxs

func _make_connection(room_a, room_b) -> Dictionary:
	# room_a and room_b are Room instances
	var ra = room_a.room_rect
	var rb = room_b.room_rect
	# decide orientation: if their y projections overlap -> horizontal, else vertical
	var overlap_y = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y) - max(ra.position.y, rb.position.y)
	var overlap_x = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x) - max(ra.position.x, rb.position.x)

	var conn := {}
	if overlap_y > 0 and overlap_y >= overlap_x:
		# horizontal corridor
		var corridor_row = int(floor(((max(ra.position.y, rb.position.y) + min(ra.position.y + ra.size.y, rb.position.y + rb.size.y)) * 0.5) / tile_size))
		var y_px = corridor_row * tile_size
		# determine which room is left/right
		var left_room = ra
		var right_room = rb
		if ra.position.x > rb.position.x:
			left_room = rb
			right_room = ra
		# corridor tiles span from first tile after left_room to first tile of right_room
		var start_tile_x = int((left_room.position.x + left_room.size.x) / tile_size)
		var end_tile_x = int((right_room.position.x) / tile_size)
		var width_tiles = max(0, end_tile_x - start_tile_x)
		var floor_rect = Rect2(Vector2(start_tile_x * tile_size, y_px), Vector2(width_tiles * tile_size, tile_size * 2))
		# doors (inside room edges)
		var door_a = Vector2(left_room.position.x + left_room.size.x - tile_size * 0.5, y_px + tile_size * 0.5)
		var door_b = Vector2(right_room.position.x + tile_size * 0.5, y_px + tile_size * 0.5)
		# walls: top and bottom
		var wall_top = Rect2(Vector2(floor_rect.position.x, floor_rect.position.y - tile_size), Vector2(floor_rect.size.x, tile_size))
		var wall_bottom = Rect2(Vector2(floor_rect.position.x, floor_rect.position.y + floor_rect.size.y), Vector2(floor_rect.size.x, tile_size))
		conn = {
			"a_pos": door_a,
			"b_pos": door_b,
			"door_a": door_a,
			"door_b": door_b,
			"floor_rect": floor_rect,
			"wall_rects": [wall_top, wall_bottom],
			"axis": "h"
		}
	else:
		# vertical corridor
		var corridor_col = int(floor(((max(ra.position.x, rb.position.x) + min(ra.position.x + ra.size.x, rb.position.x + rb.size.x)) * 0.5) / tile_size))
		var x_px = corridor_col * tile_size
		var top_room = ra
		var bottom_room = rb
		if ra.position.y > rb.position.y:
			top_room = rb
			bottom_room = ra
		var start_tile_y = int((top_room.position.y + top_room.size.y) / tile_size)
		var end_tile_y = int((bottom_room.position.y) / tile_size)
		var height_tiles = max(0, end_tile_y - start_tile_y)
		var floor_rect = Rect2(Vector2(x_px, start_tile_y * tile_size), Vector2(tile_size * 2, height_tiles * tile_size))
		var door_a = Vector2(x_px + tile_size * 0.5, top_room.position.y + top_room.size.y - tile_size * 0.5)
		var door_b = Vector2(x_px + tile_size * 0.5, bottom_room.position.y + tile_size * 0.5)
		var wall_left = Rect2(Vector2(floor_rect.position.x - tile_size, floor_rect.position.y), Vector2(tile_size, floor_rect.size.y))
		var wall_right = Rect2(Vector2(floor_rect.position.x + floor_rect.size.x, floor_rect.position.y), Vector2(tile_size, floor_rect.size.y))
		conn = {
			"a_pos": door_a,
			"b_pos": door_b,
			"door_a": door_a,
			"door_b": door_b,
			"floor_rect": floor_rect,
			"wall_rects": [wall_left, wall_right],
			"axis": "v"
		}
	return conn
