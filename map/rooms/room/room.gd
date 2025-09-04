extends Node2D
class_name Room

const ROOM_MARGIN := 4

var tile_size: float
var room_rect: Rect2
var leaf_rect: Rect2
var door_positions: Array = []

var SpawnerScript = preload("res://map/spawner.gd")

signal player_entered

func setup_detector(tile_size_in: int = 16, room_index: int = -1) -> void:
	# Instance a PlayerDetector inside this Room node and forward its signal
	var det_scene = load("res://miscellaneous/player_detector.tscn")
	var det = det_scene.instantiate()
	det.room_size = get_size_tiles() - Vector2i(3, 3)
	det.tile_size = tile_size_in
	# position detector at the center of the room (room node is placed at room_rect.position)
	det.position = room_rect.size * 0.5
	add_child(det)
	# small debug log to help trace alignment issues
	print("[Room.setup_detector] room_index=", room_index, " room.position=", position, " room.room_rect=", room_rect, " det.local_pos=", det.position, " det.global_pos=", det.global_position)
	# forward detector event as a room-level signal including the room index
	# bind the room_index into the callable so the detector's signal forwards it
	det.connect("player_entered", Callable(self, "_on_detector_player_entered").bind(room_index))

	# Ensure the room has a Spawner child created programmatically if none exists
	if not has_node("Spawner"):
		var spawner = SpawnerScript.new()
		spawner.name = "Spawner"
		add_child(spawner)

func _on_detector_player_entered(room_index: int) -> void:
	print("[Room] detector fired for room_index=", room_index, " room_rect=", room_rect, " node_position=", position)
	# select random spawn count and trigger room-local spawner if present
	var spawn_count := -1
	# if Room has exported desired min/max overrides, otherwise Spawner will use its own
	# pick a random number here (in tiles-based or enemy-count space) - use a simple random
	spawn_count = randi_range(1, 4)
	# find the Spawner child (we created it in setup_detector) and start spawn
	var spawner_node := $Spawner if has_node("Spawner") else null
	if spawner_node and spawner_node.has_method("start_spawn_for_room"):
		call_deferred("_deferred_start_spawner", spawner_node, spawn_count, room_index, room_rect, tile_size)
	# forward room-level event
	emit_signal("player_entered", room_index)



func _deferred_start_spawner(spawner_node: Node, count: int, room_index: int, room_rect_in: Rect2 = Rect2(), tile_size_in: int = 16) -> void:
	if not is_instance_valid(spawner_node):
		return
	if spawner_node.has_method("start_spawn_for_room"):
		spawner_node.start_spawn_for_room(room_index, count, room_rect_in, tile_size_in)

# internal default minimum room size in tiles (can be overridden by MapGenerator)
var min_room_tiles: Vector2i = Vector2i(8, 8)

func _init(leaf_rect_in: Rect2, room_rect_in: Variant = null, min_tiles: Variant = null, tile_size_in: Variant = null):
	# store original leaf rect so other systems can match rooms to BSP leaves
	self.leaf_rect = leaf_rect_in

	tile_size = tile_size_in
	var margin = max(ROOM_MARGIN, int(tile_size))
	# allow caller to override default min tiles for this room
	if min_tiles != null:
		min_room_tiles = min_tiles
	# (pixel-level available size computed when needed)

	# If the available area is too small (in tiles), create a minimal room and align to tiles
	var avail_tiles_pixels_w = int(floor((leaf_rect_in.size.x - 2 * margin) / tile_size))
	var avail_tiles_pixels_h = int(floor((leaf_rect_in.size.y - 2 * margin) / tile_size))
	if avail_tiles_pixels_w < min_room_tiles.x or avail_tiles_pixels_h < min_room_tiles.y:
		var rr = Rect2(leaf_rect_in.position + Vector2(margin, margin), Vector2(min_room_tiles.x * tile_size, min_room_tiles.y * tile_size))
		room_rect = _align_rect_to_tile(rr)
		return

	# Compute inner bounds in tiles
	var inner_left = leaf_rect_in.position.x + margin
	var inner_top = leaf_rect_in.position.y + margin
	var inner_right = leaf_rect_in.position.x + leaf_rect_in.size.x - margin
	var inner_bottom = leaf_rect_in.position.y + leaf_rect_in.size.y - margin

	var left_tile = int(ceil(inner_left / tile_size))
	var top_tile = int(ceil(inner_top / tile_size))
	var right_tile = int(floor(inner_right / tile_size))
	var bottom_tile = int(floor(inner_bottom / tile_size))

	var available_tiles_w = max(0, right_tile - left_tile + 1)
	var available_tiles_h = max(0, bottom_tile - top_tile + 1)

	var min_tiles_w = max(1, min_room_tiles.x)
	var min_tiles_h = max(1, min_room_tiles.y)

	# clamp min to available
	min_tiles_w = min(min_tiles_w, available_tiles_w)
	min_tiles_h = min(min_tiles_h, available_tiles_h)

	# pick width/height in tiles
	var tiles_w = randi_range(min_tiles_w, max(available_tiles_w, min_tiles_w))
	var tiles_h = randi_range(min_tiles_h, max(available_tiles_h, min_tiles_h))

	tiles_w = max(tiles_w, 4)
	tiles_h = max(tiles_h, 4)

	tiles_w = min(tiles_w, available_tiles_w)
	tiles_h = min(tiles_h, available_tiles_h)

	var room_width = tiles_w * tile_size
	var room_height = tiles_h * tile_size

	# choose tile origin inside [left_tile .. right_tile - tiles_w +1]
	var max_origin_x_tile = left_tile + max(0, available_tiles_w - tiles_w)
	var max_origin_y_tile = top_tile + max(0, available_tiles_h - tiles_h)
	var origin_x_tile = randi_range(left_tile, max_origin_x_tile)
	var origin_y_tile = randi_range(top_tile, max_origin_y_tile)

	room_rect = Rect2(Vector2(origin_x_tile * tile_size, origin_y_tile * tile_size), Vector2(room_width, room_height))

	# if caller provided a specific room_rect, prefer it but clamp to leaf bounds
	if room_rect_in != null:
		room_rect = _clamp_and_align_room_rect(room_rect_in, leaf_rect_in, margin)

func set_room_rect(rr_in: Rect2) -> void:
	# helper to set room_rect from external generator, with clamping and alignment
	var margin = max(ROOM_MARGIN, int(tile_size))
	var rr = rr_in
	if rr.position.x < leaf_rect.position.x + margin:
		rr.position.x = leaf_rect.position.x + margin
	if rr.position.y < leaf_rect.position.y + margin:
		rr.position.y = leaf_rect.position.y + margin
	if rr.position.x + rr.size.x > leaf_rect.position.x + leaf_rect.size.x - margin:
		rr.size.x = leaf_rect.position.x + leaf_rect.size.x - margin - rr.position.x
	if rr.position.y + rr.size.y > leaf_rect.position.y + leaf_rect.size.y - margin:
		rr.size.y = leaf_rect.position.y + leaf_rect.size.y - margin - rr.position.y
	# align
	rr.position.x = floor(rr.position.x / tile_size) * tile_size
	rr.position.y = floor(rr.position.y / tile_size) * tile_size
	rr.size.x = floor(rr.size.x / tile_size) * tile_size
	rr.size.y = floor(rr.size.y / tile_size) * tile_size
	room_rect = rr


func get_door_positions() -> Array:
	# Return only door positions explicitly provided by the map generator.
	# Do not synthesize fallback positions here — return an empty list if none are stored.
	if door_positions and door_positions.size() > 0:
		if typeof(door_positions[0]) == TYPE_DICTIONARY:
			var simple := []
			for e in door_positions:
				# return the center pos for compatibility
				simple.append(e.get("pos", Vector2.ZERO))
				# if caller needs tiles they should call get_door_entries()
			return simple
		else:
			return door_positions
	return []


func get_door_entries() -> Array:
	# Return stored door entry dicts if present; otherwise return empty list (no fallback construction).
	if door_positions and door_positions.size() > 0 and typeof(door_positions[0]) == TYPE_DICTIONARY:
		# Return a shallow copy to avoid accidental external mutation
		var out := []
		for e in door_positions:
			out.append(e.duplicate())
		return out
	return []


func get_center() -> Vector2:
	return room_rect.position + room_rect.size * 0.5


func get_size_tiles() -> Vector2i:
	return Vector2i(int(room_rect.size.x / tile_size), int(room_rect.size.y / tile_size))

func get_floor_cells() -> Array:
	var cells := []

	var start_x = int(room_rect.position.x / tile_size)
	var start_y = int(room_rect.position.y / tile_size)

	var w = int(room_rect.size.x / tile_size)
	var h = int(room_rect.size.y / tile_size)

	for x in range(start_x, start_x + w):
		for y in range(start_y, start_y + h):
			cells.append(Vector2i(x, y))
	return cells


func get_edge_info(point: Vector2) -> Dictionary:
	# Returns info about the nearest point on this room's edge to `point`.
	# Result keys: "side" ("left"/"right"/"top"/"bottom"),
	# "edge_point" (Vector2 clamped to the edge), "offset" (float, pixels from edge start),
	# "tile_index" (int, offset in tiles along that edge).
	var r = room_rect
	var left = r.position.x
	var right = r.position.x + r.size.x
	var top = r.position.y
	var bottom = r.position.y + r.size.y

	var d_left = abs(point.x - left)
	var d_right = abs(point.x - right)
	var d_top = abs(point.y - top)
	var d_bottom = abs(point.y - bottom)

	var min_h = min(d_left, d_right)
	var min_v = min(d_top, d_bottom)

	var side := ""
	var edge_point := point
	var offset := 0.0
	var tile_index := 0

	if min_h <= min_v:
		# nearest is left or right edge
		if d_left <= d_right:
			side = "left"
			edge_point = Vector2(left, clamp(point.y, top, bottom))
			offset = edge_point.y - top
			tile_index = int(floor(offset / tile_size))
			var tiles_h = max(1, int(round(r.size.y / tile_size)))
			tile_index = clamp(tile_index, 0, tiles_h - 1)
		else:
			side = "right"
			edge_point = Vector2(right, clamp(point.y, top, bottom))
			offset = edge_point.y - top
			tile_index = int(floor(offset / tile_size))
			var tiles_h2 = max(1, int(round(r.size.y / tile_size)))
			tile_index = clamp(tile_index, 0, tiles_h2 - 1)
	else:
		# nearest is top or bottom
		if d_top <= d_bottom:
			side = "top"
			edge_point = Vector2(clamp(point.x, left, right), top)
			offset = edge_point.x - left
			tile_index = int(floor(offset / tile_size))
			var tiles_w = max(1, int(round(r.size.x / tile_size)))
			tile_index = clamp(tile_index, 0, tiles_w - 1)
		else:
			side = "bottom"
			edge_point = Vector2(clamp(point.x, left, right), bottom)
			offset = edge_point.x - left
			tile_index = int(floor(offset / tile_size))
			var tiles_w2 = max(1, int(round(r.size.x / tile_size)))
			tile_index = clamp(tile_index, 0, tiles_w2 - 1)

	return {"side": side, "edge_point": edge_point, "offset": offset, "tile_index": tile_index}


func _align_rect_to_tile(rr: Rect2) -> Rect2:
	var pos = rr.position
	var size = rr.size
	pos.x = floor(pos.x / tile_size) * tile_size
	pos.y = floor(pos.y / tile_size) * tile_size
	size.x = floor(size.x / tile_size) * tile_size
	size.y = floor(size.y / tile_size) * tile_size
	return Rect2(pos, size)


func _clamp_and_align_room_rect(rr_in: Rect2, leaf_rect_in: Rect2, margin: int) -> Rect2:
	var rr = rr_in
	if rr.position.x < leaf_rect_in.position.x + margin:
		rr.position.x = leaf_rect_in.position.x + margin
	if rr.position.y < leaf_rect_in.position.y + margin:
		rr.position.y = leaf_rect_in.position.y + margin
	if rr.position.x + rr.size.x > leaf_rect_in.position.x + leaf_rect_in.size.x - margin:
		rr.size.x = leaf_rect_in.position.x + leaf_rect_in.size.x - margin - rr.position.x
	if rr.position.y + rr.size.y > leaf_rect_in.position.y + leaf_rect_in.size.y - margin:
		rr.size.y = leaf_rect_in.position.y + leaf_rect_in.size.y - margin - rr.position.y
	return _align_rect_to_tile(rr)
