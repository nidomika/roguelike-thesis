extends Node
class_name MSTConnector

var parent = []

func get_center(rect: Rect2) -> Vector2:
	return rect.position + rect.size / 2

func build(rooms: Array) -> Array:
	var n = rooms.size()
	var edges = []
	for i in range(n):
		for j in range(i + 1, n):
			var d = get_center(rooms[i].room_rect).distance_to(get_center(rooms[j].room_rect))
			edges.append({ "a": i, "b": j, "dist": d })
	edges.sort_custom(compare_edges)
	
	parent.resize(n)
	for i in range(n):
		parent[i] = i
	
	var connections = []
	# Kruskal
	for edge in edges:
		if find(edge["a"]) != find(edge["b"]):
			union(edge["a"], edge["b"])
			connections.append({
				"a": rooms[edge["a"]],
				"b": rooms[edge["b"]]
			})
		if connections.size() >= n - 1:
			break
	return connections

func compare_edges(a, b) -> bool:
	return a["dist"] < b["dist"]


func find(x):
	if parent[x] != x:
		parent[x] = find(parent[x])
	return parent[x]

func union(x, y):
	parent[find(x)] = find(y)
