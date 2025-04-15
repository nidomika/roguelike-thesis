extends Node2D
class_name Room

var room_rect: Rect2

var min_room_width = 50
var min_room_height = 50

func _init(leaf_rect: Rect2, margin: int = 4):
	var available_width = leaf_rect.size.x - 2 * margin
	var available_height = leaf_rect.size.y - 2 * margin
	
	if available_width < min_room_width or available_height < min_room_height:
		room_rect = Rect2(leaf_rect.position + Vector2(margin, margin), Vector2(min_room_width, min_room_height))
		return
	
	var width_percent = randf_range(0.7, 0.9)
	var height_percent = randf_range(0.7, 0.9)
	
	var room_width = available_width * width_percent
	var room_height = available_height * height_percent
	
	room_width = max(room_width, min_room_width)
	room_height = max(room_height, min_room_height)
	
	var room_x = leaf_rect.position.x + margin + randf() * (available_width - room_width)
	var room_y = leaf_rect.position.y + margin + randf() * (available_height - room_height)
	
	room_rect = Rect2(room_x, room_y, room_width, room_height)
