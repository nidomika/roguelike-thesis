extends Node2D
class_name Room

const ROOM_MARGIN := 8

@export var tile_size: float = 16.0
var room_rect: Rect2

var min_room_width = 144
var min_room_height = 144

func _init(leaf_rect: Rect2):
	var available_width = leaf_rect.size.x - 2 * ROOM_MARGIN
	var available_height = leaf_rect.size.y - 2 * ROOM_MARGIN
	
	if available_width < min_room_width or available_height < min_room_height:
		room_rect = Rect2(leaf_rect.position + Vector2(ROOM_MARGIN, ROOM_MARGIN), Vector2(min_room_width, min_room_height))
		var rect_pos = room_rect.position
		rect_pos.x = floor(rect_pos.x / tile_size) * tile_size
		rect_pos.y = floor(rect_pos.y / tile_size) * tile_size
		var rect_size = room_rect.size
		rect_size.x = floor(rect_size.x / tile_size) * tile_size
		rect_size.y = floor(rect_size.y / tile_size) * tile_size
		room_rect = Rect2(rect_pos, rect_size)
		return
	
	var max_width = floor(available_width / tile_size) * tile_size
	var max_height = floor(available_height / tile_size) * tile_size
	var room_width = floor(randi_range(min_room_width, max_width) / tile_size) * tile_size
	var room_height = floor(randi_range(min_room_height, max_height) / tile_size) * tile_size
	
	var room_x = leaf_rect.position.x + ROOM_MARGIN + (available_width - room_width) / 2.0
	var room_y = leaf_rect.position.y + ROOM_MARGIN + (available_height - room_height) / 2.0
	
	room_x = floor(room_x / 16.0) * 16.0
	room_y = floor(room_y / 16.0) * 16.0

	room_width = max(room_width, 4 * 16)
	room_height = max(room_height, 4 * 16)

	var p = Vector2(room_x, room_y)
	p.x = floor(p.x / tile_size) * tile_size
	p.y = floor(p.y / tile_size) * tile_size
	var s = Vector2(room_width, room_height)
	s.x = floor(s.x / tile_size) * tile_size
	s.y = floor(s.y / tile_size) * tile_size
	room_rect = Rect2(p, s)


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
