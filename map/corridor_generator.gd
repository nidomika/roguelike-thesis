extends RefCounted
class_name CorridorGenerator

# Generate an array of dictionaries { "door_a": Vector2, "door_b": Vector2 }
# by connecting sibling rooms in the BSP tree.
func generate(rooms: Array, root, tile_size: int) -> Array:
	var conns := []
	_connect_node(root, rooms, tile_size, conns)
	return conns

# Recursive helper: for each node, connect its left/right if both have rooms
func _connect_node(node, rooms: Array, tile_size: int, conns: Array) -> void:
	# Connect siblings first (to ensure bottom-up order)
	if node.left != null and node.right != null:
		# Only if both subtrees have actual rooms
		if node.left.has_room and node.right.has_room:
			var roomA = _find_room(node.left, rooms)
			var roomB = _find_room(node.right, rooms)
			if roomA != null and roomB != null:
				var da = _choose_door(roomA, node.is_vertical_split, false, tile_size)
				var db = _choose_door(roomB, node.is_vertical_split, true, tile_size)
				conns.append({ "door_a": da, "door_b": db })
	# Recurse into children
	if node.left != null:
		_connect_node(node.left, rooms, tile_size, conns)
	if node.right != null:
		_connect_node(node.right, rooms, tile_size, conns)

# Choose a door position from get_door_positions() on the correct wall
func _choose_door(room, is_vertical_split: bool, inverse: bool, tile_size: int) -> Vector2:
	var candidates := []
	var wall_pos: float

	if is_vertical_split:
		# Horizontal corridor => doors on left/right walls
		if inverse:
			wall_pos = room.room_rect.position.x
		else:
			wall_pos = room.room_rect.position.x + room.room_rect.size.x
		for p in room.get_door_positions():
			if int(p.x) == int(wall_pos):
				candidates.append(p)
	else:
		# Vertical corridor => doors on top/bottom walls
		if inverse:
			wall_pos = room.room_rect.position.y
		else:
			wall_pos = room.room_rect.position.y + room.room_rect.size.y
		for p in room.get_door_positions():
			if int(p.y) == int(wall_pos):
				candidates.append(p)

	# Pick a random door if available
	if candidates.size() > 0:
		return candidates[randi() % candidates.size()]

	# Fallback: center of room
	var center = room.room_rect.position + room.room_rect.size * 0.5
	center.x = floor(center.x / tile_size) * tile_size + tile_size * 0.5
	center.y = floor(center.y / tile_size) * tile_size + tile_size * 0.5
	return center

# Find the Room instance matching this node's rect
func _find_room(node, rooms: Array):
	for r in rooms:
		if r.room_rect == node.rect:
			return r
	return null
