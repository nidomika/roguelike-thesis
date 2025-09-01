extends Object
class_name CorridorGenerator

# Clip a Rect2 vertically to [top, bottom]
func _intersect_rect_v(r: Rect2, top: float, bottom: float) -> Rect2:
	var ny = max(r.position.y, top)
	var ny2 = min(r.position.y + r.size.y, bottom)
	if ny2 <= ny:
		return Rect2(Vector2(r.position.x, r.position.y), Vector2(r.size.x, 0))
	return Rect2(Vector2(r.position.x, ny), Vector2(r.size.x, ny2 - ny))

# Clip a Rect2 horizontally to [left, right]
func _intersect_rect_h(r: Rect2, left: float, right: float) -> Rect2:
	var nx = max(r.position.x, left)
	var nx2 = min(r.position.x + r.size.x, right)
	if nx2 <= nx:
		return Rect2(Vector2(r.position.x, r.position.y), Vector2(0, r.size.y))
	return Rect2(Vector2(nx, r.position.y), Vector2(nx2 - nx, r.size.y))

# Simple BSP-aware corridor generator
# - collects one candidate edge per internal BSP node by picking one room from left subtree and one from right
# - prefers pairs whose projections overlap on the perpendicular axis so corridors are straight
# - runs Kruskal's MST over candidate edges to ensure no cycles
# - outputs connections with door positions and Rect2 geometry for 2-tile-wide floor + 1-tile walls

var tile_size: int = 16
@export var max_nn_dist_tiles: int = 12 # maximum NN fallback distance in tiles; lowered to avoid very long direct fallback corridors

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
	tile_size = tile_size_in
	var n = rooms.size()
	if n <= 1:
		return []

	# collect candidate edges from BSP internal nodes
	var edges := []
	_collect_edges(bsp_root, rooms, edges, 0)

	# Ensure graph connectivity: for each room, add an edge to its nearest neighbor (if not already present)
	var nrooms = rooms.size()
	if nrooms > 1:
		# build a set of existing pairs to avoid duplicates
		var pair_set = {}
		for e in edges:
			var key = str(min(e.a, e.b)) + ":" + str(max(e.a, e.b))
			pair_set[key] = true
		for i in range(nrooms):
			var ci = rooms[i].room_rect.position + rooms[i].room_rect.size * 0.5
			var best_j = -1
			var best_d = 1e20
			for j in range(nrooms):
				if i == j:
					continue
				var cj = rooms[j].room_rect.position + rooms[j].room_rect.size * 0.5
				var d = ci.distance_to(cj)
				if d < best_d:
					best_d = d
					best_j = j
			if best_j >= 0:
				# allow NN fallback only if centers are within max distance OR rooms have overlapping projection (x or y)
				var key = str(min(i, best_j)) + ":" + str(max(i, best_j))
				var allow = false
				var ri = rooms[i].room_rect
				var rj = rooms[best_j].room_rect
				var overlap_x = min(ri.position.x + ri.size.x, rj.position.x + rj.size.x) - max(ri.position.x, rj.position.x)
				var overlap_y = min(ri.position.y + ri.size.y, rj.position.y + rj.size.y) - max(ri.position.y, rj.position.y)
				if overlap_x > 0 or overlap_y > 0:
					allow = true
				else:
					var maxd = float(max_nn_dist_tiles) * float(tile_size)
					if best_d <= maxd:
						allow = true
				if allow and not pair_set.has(key):
					var ne = Edge.new()
					ne.a = i
					ne.b = best_j
					ne.weight = best_d
					ne.depth = 0
					ne.fallback = true
					edges.append(ne)
					pair_set[key] = true

		# iterative merge: if graph (edges) doesn't connect all rooms, add shortest cross-component edges
		var uf_check = UnionFind.new(nrooms)
		for e in edges:
			uf_check.union(e.a, e.b)
		# count components
		var comps = {}
		for i in range(nrooms):
			comps[uf_check.find(i)] = true
		var comp_count = comps.size()
		var safety = 0
		while comp_count > 1 and safety < nrooms * 2:
			# find shortest pair of rooms that are in different components
			var best_i = -1
			var best_j = -1
			var best_dist = 1e20
			for i in range(nrooms):
				for j in range(i+1, nrooms):
					if uf_check.find(i) == uf_check.find(j):
						continue
					var ci = rooms[i].room_rect.position + rooms[i].room_rect.size * 0.5
					var cj = rooms[j].room_rect.position + rooms[j].room_rect.size * 0.5
					var d = ci.distance_to(cj)
					if d < best_dist:
						best_dist = d
						best_i = i
						best_j = j
			if best_i >= 0 and best_j >= 0:
				var key = str(min(best_i, best_j)) + ":" + str(max(best_i, best_j))
				if not pair_set.has(key):
					var ne = Edge.new()
					ne.a = best_i
					ne.b = best_j
					ne.weight = best_dist
					ne.depth = 0
					edges.append(ne)
					pair_set[key] = true
				# union them in uf_check and recompute comp count
				uf_check.union(best_i, best_j)
				comps = {}
				for k in range(nrooms):
					comps[uf_check.find(k)] = true
				comp_count = comps.size()
			safety += 1

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
	# (after NN fallback)
	var nn_added = 0
	for e in edges:
		if e.depth == 0 and e.weight < 10000.0:
			# heuristic: treat these as original or short edges
			pass
		elif e.depth == 0 and e.weight >= 10000.0:
			nn_added += 1
	print("[CorridorGenerator] nn_penalized_edges=", nn_added)
	for e in edges:
		print("  edge a=", e.a, " b=", e.b, " depth=", e.depth, " weight=", e.weight, " axis=", e.axis, " coord=", e.coord, " penalized=", e.weight >= 10000.0)
	# Kruskal
	var uf = UnionFind.new(n)
	var conns := []
	for e in edges:
		if uf.find(e.a) != uf.find(e.b):
			uf.union(e.a, e.b)
			var conn = _make_connection(rooms[e.a], rooms[e.b])
			# annotate with source room indices for faster lookups later
			conn["room_a_index"] = e.a
			conn["room_b_index"] = e.b
			conns.append(conn)

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
					var score = 0.0
					if node.is_vertical_split:
						# vertical split -> rooms on left/right -> we want horizontal corridor; overlap on y
						var overlap = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y) - max(ra.position.y, rb.position.y)
						var dx = max(0.0, rb.position.x - (ra.position.x + ra.size.x))
						if overlap > 0:
							# prefer overlapping pairs by giving them lower score
							score = dx
							# choose y coordinate inside overlap
							var y0 = max(ra.position.y, rb.position.y)
							var y1 = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y)
							chosen_coord = floor(((y0 + y1) * 0.5) / tile_size) * tile_size + tile_size * 0.5
						else:
							# no overlap -> penalize heavily but still consider
							score = dx + 10000.0
					else:
						# horizontal split -> rooms on top/bottom -> want vertical corridor; overlap on x
						var overlapx = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x) - max(ra.position.x, rb.position.x)
						var dy = max(0.0, rb.position.y - (ra.position.y + ra.size.y))
						if overlapx > 0:
							score = dy
							var x0 = max(ra.position.x, rb.position.x)
							var x1 = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x)
							chosen_coord = floor(((x0 + x1) * 0.5) / tile_size) * tile_size + tile_size * 0.5
						else:
							score = dy + 10000.0
					if score < best_w:
						best_w = score
						best = Edge.new()
						best.a = ai
						best.b = bi
						best.weight = score
						best.axis = "h" if node.is_vertical_split else "v"
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
		# compute center Y inside overlap if possible, otherwise average centers and clamp into rooms
		var y_center: float
		var y0 = max(ra.position.y, rb.position.y)
		var y1 = min(ra.position.y + ra.size.y, rb.position.y + rb.size.y)
		if y1 > y0:
			y_center = (y0 + y1) * 0.5
		else:
			# no overlap (rare) - use average of room centers
			y_center = (ra.position.y + ra.size.y * 0.5 + rb.position.y + rb.size.y * 0.5) * 0.5
		# clamp door y so it lies inside each room (half-tile inset)
		# choose left/right rooms first
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
		width_tiles = max(1, width_tiles)
		# determine door y positions clamped into room vertical extents
		var door_a_y = clamp(y_center, left_room.position.y + tile_size * 0.5, left_room.position.y + left_room.size.y - tile_size * 0.5)
		var door_b_y = clamp(y_center, right_room.position.y + tile_size * 0.5, right_room.position.y + right_room.size.y - tile_size * 0.5)
		# use average door y for corridor vertical placement so floor is continuous
		var door_y = (door_a_y + door_b_y) * 0.5
		var floor_rect = Rect2(Vector2(start_tile_x * tile_size, door_y - tile_size * 0.5), Vector2(width_tiles * tile_size, tile_size * 2))
		# doors (inside room edges)
		var door_a = Vector2(left_room.position.x + left_room.size.x - tile_size * 0.5, door_a_y)
		var door_b = Vector2(right_room.position.x + tile_size * 0.5, door_b_y)
		# walls: top and bottom
		var wall_top = Rect2(Vector2(floor_rect.position.x, floor_rect.position.y - tile_size), Vector2(floor_rect.size.x, tile_size))
		var wall_bottom = Rect2(Vector2(floor_rect.position.x, floor_rect.position.y + floor_rect.size.y), Vector2(floor_rect.size.x, tile_size))
		# clip walls so they don't extend beyond the vertical union of the two rooms
		var union_top = min(left_room.position.y, right_room.position.y)
		var union_bottom = max(left_room.position.y + left_room.size.y, right_room.position.y + right_room.size.y)
		wall_top = _intersect_rect_v(wall_top, union_top, union_bottom)
		wall_bottom = _intersect_rect_v(wall_bottom, union_top, union_bottom)
		var walls := []
		if wall_top.size.y > 0:
			walls.append(wall_top)
		if wall_bottom.size.y > 0:
			walls.append(wall_bottom)
		conn = {
			"a_pos": door_a,
			"b_pos": door_b,
			"door_a": door_a,
			"door_b": door_b,
			"floor_rect": floor_rect,
			"wall_rects": walls,
			"axis": "h"
		}
		# store the computed door positions (these align with the corridor floor/walls)
		conn["door_a_edge"] = door_a
		conn["door_b_edge"] = door_b
		var da_tile = Vector2i(int(door_a.x / tile_size), int(door_a.y / tile_size))
		var db_tile = Vector2i(int(door_b.x / tile_size), int(door_b.y / tile_size))
		conn["door_a_tile"] = da_tile
		conn["door_b_tile"] = db_tile
		# compute two adjacent door tiles (corridor is 2 tiles high for horizontal corridors)
		var floor_sy = int(floor_rect.position.y / tile_size)
		conn["door_a_tiles"] = [Vector2i(da_tile.x, floor_sy), Vector2i(da_tile.x, floor_sy + 1)]
		conn["door_b_tiles"] = [Vector2i(db_tile.x, floor_sy), Vector2i(db_tile.x, floor_sy + 1)]
		# compute and store side and tile-index along the room edge (use Room.get_edge_info)
		if room_a != null:
			var ia = room_a.get_edge_info(door_a)
			conn["door_a_side"] = ia["side"]
			# store scalar tile index (legacy) and a range for the two-tile opening
			conn["door_a_tile_index"] = ia["tile_index"]
			conn["door_a_tile_index_range"] = Vector2i(ia["tile_index"], min(ia["tile_index"] + 1, max(0, int(round(room_a.room_rect.size.y / tile_size)) - 1)))
		if room_b != null:
			var ib = room_b.get_edge_info(door_b)
			conn["door_b_side"] = ib["side"]
			conn["door_b_tile_index"] = ib["tile_index"]
			conn["door_b_tile_index_range"] = Vector2i(ib["tile_index"], min(ib["tile_index"] + 1, max(0, int(round(room_b.room_rect.size.y / tile_size)) - 1)))
	else:
		# vertical corridor
		var x_center: float
		var x0 = max(ra.position.x, rb.position.x)
		var x1 = min(ra.position.x + ra.size.x, rb.position.x + rb.size.x)
		if x1 > x0:
			x_center = (x0 + x1) * 0.5
		else:
			x_center = (ra.position.x + ra.size.x * 0.5 + rb.position.x + rb.size.x * 0.5) * 0.5
		# x_center is used directly below
		var top_room = ra
		var bottom_room = rb
		if ra.position.y > rb.position.y:
			top_room = rb
			bottom_room = ra
		var start_tile_y = int((top_room.position.y + top_room.size.y) / tile_size)
		var end_tile_y = int((bottom_room.position.y) / tile_size)
		var height_tiles = max(0, end_tile_y - start_tile_y)
		height_tiles = max(1, height_tiles)
		# determine door x positions clamped into room horizontal extents
		var door_a_x = clamp(x_center, top_room.position.x + tile_size * 0.5, top_room.position.x + top_room.size.x - tile_size * 0.5)
		var door_b_x = clamp(x_center, bottom_room.position.x + tile_size * 0.5, bottom_room.position.x + bottom_room.size.x - tile_size * 0.5)
		var door_x = (door_a_x + door_b_x) * 0.5
		var floor_rect = Rect2(Vector2(door_x - tile_size * 0.5, start_tile_y * tile_size), Vector2(tile_size * 2, height_tiles * tile_size))
		var door_a = Vector2(door_a_x, top_room.position.y + top_room.size.y - tile_size * 0.5)
		var door_b = Vector2(door_b_x, bottom_room.position.y + tile_size * 0.5)
		var wall_left = Rect2(Vector2(floor_rect.position.x - tile_size, floor_rect.position.y), Vector2(tile_size, floor_rect.size.y))
		var wall_right = Rect2(Vector2(floor_rect.position.x + floor_rect.size.x, floor_rect.position.y), Vector2(tile_size, floor_rect.size.y))
		# clip walls so they don't extend beyond the horizontal union of the two rooms
		var union_left = min(top_room.position.x, bottom_room.position.x)
		var union_right = max(top_room.position.x + top_room.size.x, bottom_room.position.x + bottom_room.size.x)
		wall_left = _intersect_rect_h(wall_left, union_left, union_right)
		wall_right = _intersect_rect_h(wall_right, union_left, union_right)
		var vwalls := []
		if wall_left.size.x > 0:
			vwalls.append(wall_left)
		if wall_right.size.x > 0:
			vwalls.append(wall_right)
		conn = {
			"a_pos": door_a,
			"b_pos": door_b,
			"door_a": door_a,
			"door_b": door_b,
			"floor_rect": floor_rect,
			"wall_rects": vwalls,
			"axis": "v"
		}
		# store the computed door positions (these align with the corridor floor/walls)
		conn["door_a_edge"] = door_a
		conn["door_b_edge"] = door_b
		var da_tile2 = Vector2i(int(door_a.x / tile_size), int(door_a.y / tile_size))
		var db_tile2 = Vector2i(int(door_b.x / tile_size), int(door_b.y / tile_size))
		conn["door_a_tile"] = da_tile2
		conn["door_b_tile"] = db_tile2
		# for vertical corridors the opening spans two horizontal tiles
		var floor_sx = int(floor_rect.position.x / tile_size)
		conn["door_a_tiles"] = [Vector2i(floor_sx, da_tile2.y), Vector2i(floor_sx + 1, da_tile2.y)]
		conn["door_b_tiles"] = [Vector2i(floor_sx, db_tile2.y), Vector2i(floor_sx + 1, db_tile2.y)]
		# compute and store side and tile-index along the room edge
		if room_a != null:
			var ia2 = room_a.get_edge_info(door_a)
			conn["door_a_side"] = ia2["side"]
			conn["door_a_tile_index"] = ia2["tile_index"]
			conn["door_a_tile_index_range"] = Vector2i(ia2["tile_index"], min(ia2["tile_index"] + 1, max(0, int(round(room_a.room_rect.size.x / tile_size)) - 1)))
		if room_b != null:
			var ib2 = room_b.get_edge_info(door_b)
			conn["door_b_side"] = ib2["side"]
			conn["door_b_tile_index"] = ib2["tile_index"]
			conn["door_b_tile_index_range"] = Vector2i(ib2["tile_index"], min(ib2["tile_index"] + 1, max(0, int(round(room_b.room_rect.size.x / tile_size)) - 1)))
	return conn
