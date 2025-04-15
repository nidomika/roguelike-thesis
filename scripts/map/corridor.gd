extends Node2D
class_name Corridor

var corridors = []

func set_corridors(connections: Array):
	corridors.clear()
	for conn in connections:
		var pair = get_aligned_door_points(conn["a"], conn["b"])
		var door_a = pair.door_a
		var door_b = pair.door_b
		corridors.append([door_a, door_b])
	queue_redraw()

func _draw():
	for points in corridors:
		draw_polyline(points, Color(1, 0, 0), 2)

func get_aligned_door_points(room_a, room_b) -> Dictionary:
	var center_a = room_a.room_rect.position + room_a.room_rect.size * 0.5
	var center_b = room_b.room_rect.position + room_b.room_rect.size * 0.5
	var dx = center_b.x - center_a.x
	var dy = center_b.y - center_a.y

	var door_a: Vector2
	var door_b: Vector2
	var margin = 8.0

	if abs(dx) > abs(dy):
		var avg_y = (center_a.y + center_b.y) / 2.0

		var room_a_min_y = room_a.room_rect.position.y + margin
		var room_a_max_y = room_a.room_rect.position.y + room_a.room_rect.size.y - margin
		var room_b_min_y = room_b.room_rect.position.y + margin
		var room_b_max_y = room_b.room_rect.position.y + room_b.room_rect.size.y - margin
		var lower_bound = max(room_a_min_y, room_b_min_y)
		var upper_bound = min(room_a_max_y, room_b_max_y)
		var final_y = clamp(avg_y, lower_bound, upper_bound)

		if dx > 0:
			door_a = Vector2(room_a.room_rect.position.x + room_a.room_rect.size.x, final_y)
			door_b = Vector2(room_b.room_rect.position.x, final_y)
		else:
			door_a = Vector2(room_a.room_rect.position.x, final_y)
			door_b = Vector2(room_b.room_rect.position.x + room_b.room_rect.size.x, final_y)
		return {"door_a": door_a, "door_b": door_b}
	else:
		var avg_x = (center_a.x + center_b.x) / 2.0
		var room_a_min_x = room_a.room_rect.position.x + margin
		var room_a_max_x = room_a.room_rect.position.x + room_a.room_rect.size.x - margin
		var room_b_min_x = room_b.room_rect.position.x + margin
		var room_b_max_x = room_b.room_rect.position.x + room_b.room_rect.size.x - margin
		var lower_bound = max(room_a_min_x, room_b_min_x)
		var upper_bound = min(room_a_max_x, room_b_max_x)
		var final_x = clamp(avg_x, lower_bound, upper_bound)

		if dy > 0:
			door_a = Vector2(final_x, room_a.room_rect.position.y + room_a.room_rect.size.y)
			door_b = Vector2(final_x, room_b.room_rect.position.y)
		else:
			door_a = Vector2(final_x, room_a.room_rect.position.y)
			door_b = Vector2(final_x, room_b.room_rect.position.y + room_b.room_rect.size.y)
		return {"door_a": door_a, "door_b": door_b}
