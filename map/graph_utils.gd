extends Object
class_name GraphUtils

# Utility functions for building a room graph and finding the longest simple path
# Assumes the graph is acyclic (tree / MST). Use get_longest_path_from_data(data).

func build_adjacency(rooms: Array, connections: Array) -> Array:
	var n = rooms.size()
	var adj := []
	for i in range(n):
		adj.append([])

	for c in connections:
		var ia = -1
		var ib = -1
		# prefer explicit indices if present
		if c.has("room_a_index") and c.has("room_b_index"):
			ia = c["room_a_index"]
			ib = c["room_b_index"]
		else:
			var a = c.get("door_a", null)
			var b = c.get("door_b", null)
			if a != null and b != null:
				for i in range(n):
					if rooms[i].room_rect.has_point(a):
						ia = i
						break
				for j in range(n):
					if rooms[j].room_rect.has_point(b):
						ib = j
						break

		if ia >= 0 and ib >= 0 and ia != ib:
			# avoid duplicate entries
			if not adj[ia].has(ib):
				adj[ia].append(ib)
			if not adj[ib].has(ia):
				adj[ib].append(ia)

	return adj


func _bfs_farthest(start: int, adj: Array) -> Dictionary:
	var n = adj.size()
	var q := []
	var parent := []
	var dist := []
	for i in range(n):
		parent.append(-1)
		dist.append(-1)
	q.append(start)
	dist[start] = 0
	var head = 0
	while head < q.size():
		var v = q[head]
		head += 1
		for to in adj[v]:
			if dist[to] == -1:
				dist[to] = dist[v] + 1
				parent[to] = v
				q.append(to)

	var far = start
	for i in range(n):
		if dist[i] > dist[far]:
			far = i
	return {"node": far, "parent": parent, "dist": dist}


func tree_diameter_path(adj: Array) -> Array:
	# returns list of node indices forming the longest simple path (diameter) in the tree
	if adj.size() == 0:
		return []
	var r1 = _bfs_farthest(0, adj)
	var a = r1["node"]
	var r2 = _bfs_farthest(a, adj)
	var b = r2["node"]
	var parent = r2["parent"]
	var path_rev := []
	var cur = b
	while cur != -1:
		path_rev.append(cur)
		cur = parent[cur]
	var path := []
	for i in range(path_rev.size() - 1, -1, -1):
		path.append(path_rev[i])
	return path


func get_longest_path_from_data(data: Dictionary) -> Array:
	# convenience wrapper: build adjacency from data and return diameter path (room indices)
	var rooms = data.get("rooms", [])
	var connections = data.get("connections", [])
	var adj = build_adjacency(rooms, connections)
	return tree_diameter_path(adj)


func get_room_centers(rooms: Array) -> Array:
	var centers := []
	for r in rooms:
		centers.append(r.room_rect.position + r.room_rect.size * 0.5)
	return centers


func get_path_positions(data: Dictionary, path: Array) -> Array:
	var rooms = data.get("rooms", [])
	var centers = get_room_centers(rooms)
	var out := []
	for idx in path:
		if idx >= 0 and idx < centers.size():
			out.append(centers[idx])
	return out
