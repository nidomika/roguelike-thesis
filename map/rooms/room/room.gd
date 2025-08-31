extends Node2D
class_name Room

const ROOM_MARGIN := 8

@export var tile_size: float = 16.0
var room_rect: Rect2
var leaf_rect: Rect2

var min_room_width = 128
var min_room_height = 128

func _init(leaf_rect_in: Rect2, room_rect_in: Variant = null):
	# store original leaf rect so other systems can match rooms to BSP leaves
	self.leaf_rect = leaf_rect_in

	# ensure at least one tile gap between room and leaf rect
	var margin = max(ROOM_MARGIN, int(tile_size))
	var available_width = leaf_rect_in.size.x - 2 * margin
	var available_height = leaf_rect_in.size.y - 2 * margin

	if available_width < min_room_width or available_height < min_room_height:
		room_rect = Rect2(leaf_rect_in.position + Vector2(margin, margin), Vector2(min_room_width, min_room_height))
		var rect_pos = room_rect.position
		rect_pos.x = floor(rect_pos.x / tile_size) * tile_size
		rect_pos.y = floor(rect_pos.y / tile_size) * tile_size
		var rect_size = room_rect.size
		rect_size.x = floor(rect_size.x / tile_size) * tile_size
		rect_size.y = floor(rect_size.y / tile_size) * tile_size
		room_rect = Rect2(rect_pos, rect_size)
		return

	

	# Align inner leaf bounds to tile grid
	var leaf_left = leaf_rect_in.position.x + margin
	var leaf_top = leaf_rect_in.position.y + margin
	var leaf_right = leaf_rect_in.position.x + leaf_rect_in.size.x - margin
	var leaf_bottom = leaf_rect_in.position.y + leaf_rect_in.size.y - margin

	var left_tile = int(ceil(leaf_left / tile_size))
	var top_tile = int(ceil(leaf_top / tile_size))
	var right_tile = int(floor(leaf_right / tile_size))
	var bottom_tile = int(floor(leaf_bottom / tile_size))

	var available_tiles_w = max(0, right_tile - left_tile + 1)
	var available_tiles_h = max(0, bottom_tile - top_tile + 1)

	var min_tiles_w = max(1, int(ceil(min_room_width / tile_size)))
	var min_tiles_h = max(1, int(ceil(min_room_height / tile_size)))

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

	var p = Vector2(origin_x_tile * tile_size, origin_y_tile * tile_size)
	var s = Vector2(room_width, room_height)
	room_rect = Rect2(p, s)

	# if caller provided a specific room_rect, prefer it but clamp to leaf bounds
	if room_rect_in != null:
		var rr = room_rect_in
		# clamp position
		if rr.position.x < leaf_rect_in.position.x + margin:
			rr.position.x = leaf_rect_in.position.x + margin
		if rr.position.y < leaf_rect_in.position.y + margin:
			rr.position.y = leaf_rect_in.position.y + margin
		# clamp size so it fits
		if rr.position.x + rr.size.x > leaf_rect_in.position.x + leaf_rect_in.size.x - margin:
			rr.size.x = leaf_rect_in.position.x + leaf_rect_in.size.x - margin - rr.position.x
		if rr.position.y + rr.size.y > leaf_rect_in.position.y + leaf_rect_in.size.y - margin:
			rr.size.y = leaf_rect_in.position.y + leaf_rect_in.size.y - margin - rr.position.y
		# align to tile grid
		rr.position.x = floor(rr.position.x / tile_size) * tile_size
		rr.position.y = floor(rr.position.y / tile_size) * tile_size
		rr.size.x = floor(rr.size.x / tile_size) * tile_size
		rr.size.y = floor(rr.size.y / tile_size) * tile_size
		room_rect = rr

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
	var doors := []
	var r = room_rect
	var half = tile_size * 0.5

	var mid_x = floor((r.position.x + r.size.x * 0.5) / tile_size) * tile_size + half
	var mid_y = floor((r.position.y + r.size.y * 0.5) / tile_size) * tile_size + half

	doors.append(Vector2(mid_x, r.position.y + half))
	doors.append(Vector2(mid_x, r.position.y + r.size.y - half))
	doors.append(Vector2(r.position.x + half, mid_y))
	doors.append(Vector2(r.position.x + r.size.x - half, mid_y))

	return doors

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
