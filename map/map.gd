extends Node2D
class_name Map

var data 
var world_pos = Vector2.ZERO
var world_size = Vector2(900, 600) # docelowo (1280,90)

var rooms

@export var tile_size: int = 16
@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")

func _ready():
	var map_rect = Rect2(world_pos, world_size)
	var map_generator = MapGenerator.new()
	data = map_generator.generate_map(map_rect)
	rooms = data["rooms"]
	# ensure every connection has a door_open flag (default: true = open)
	if data.has("connections"):
		for i in range(data["connections"].size()):
			var c = data["connections"][i]
			if not c.has("door_open"):
				c["door_open"] = true
	generate_tiles()


func set_door_state(conn_index: int, open: bool) -> void:
	if not data or not data.has("connections"):
		return
	if conn_index < 0 or conn_index >= data["connections"].size():
		return
	data["connections"][conn_index]["door_open"] = open
	call_deferred("_deferred_redraw")


func open_door(conn_index: int) -> void:
	set_door_state(conn_index, true)


func close_door(conn_index: int) -> void:
	set_door_state(conn_index, false)


func toggle_door(conn_index: int) -> void:
	if not data or not data.has("connections"):
		return
	if conn_index < 0 or conn_index >= data["connections"].size():
		return
	var c = data["connections"][conn_index]
	c["door_open"] = not c.get("door_open", true)
	call_deferred("_deferred_redraw")

func generate_tiles():
	# Temporarily disable painting tiles. We only want to see outlines + corridor lines.
	# tilemap.clear()
	# var corridor_cells := []
	#
	# for room in rooms:
	# 	var start_x = int(room.room_rect.position.x / tile_size)
	# 	var start_y = int(room.room_rect.position.y / tile_size)
	# 	var room_width = int(room.room_rect.size.x / tile_size)
	# 	var room_height = int(room.room_rect.size.y / tile_size)
	# 	
	# 	for x in range(start_x, start_x + room_width):
	# 		for y in range(start_y, start_y + room_height):
	# 			tilemap.set_cells_terrain_connect(0, [Vector2i(x, y)], 1, 0, false)
	#
	# for conn in data["connections"]:
	# 	var a = conn["door_a"]
	# 	var b = conn["door_b"]
	# 	var cell_a = Vector2i(int(a.x / tile_size), int(a.y / tile_size))
	# 	var cell_b = Vector2i(int(b.x / tile_size), int(b.y / tile_size))
	# 	if cell_a.x == cell_b.x:
	# 		for y in range(min(cell_a.y, cell_b.y), max(cell_a.y, cell_b.y) + 1):
	# 			corridor_cells.append(Vector2i(cell_a.x, y))
	# 	elif cell_a.y == cell_b.y:
	# 		for x in range(min(cell_a.x, cell_b.x), max(cell_a.x, cell_b.x) + 1):
	# 			corridor_cells.append(Vector2i(x, cell_a.y))
	# 	else:
	# 		var corner = Vector2i(cell_b.x, cell_a.y)
	# 		for x in range(min(cell_a.x, corner.x), max(cell_a.x, corner.x) + 1):
	# 			corridor_cells.append(Vector2i(x, cell_a.y))
	# 		for y in range(min(corner.y, cell_b.y), max(corner.y, cell_b.y) + 1):
	# 			corridor_cells.append(Vector2i(corner.x, y))
	#
	# print(data)
	#
	# tilemap.set_cells_terrain_connect(0, corridor_cells, 1, 0, false)

	# Trigger redraw so outlines and corridor lines are visible via a safe deferred wrapper
	call_deferred("_deferred_redraw")


func _deferred_redraw() -> void:
	# no-op: avoid calling engine update methods here (some builds raised "Method not found")
	# The engine will schedule a redraw automatically on next frame.
	pass

func get_room_cell_rect(room: Room) -> Rect2:
	var start_x = int(room.room_rect.position.x / tile_size)
	var start_y = int(room.room_rect.position.y / tile_size)
	var room_width = int(room.room_rect.size.x / tile_size)
	var room_height = int(room.room_rect.size.y / tile_size)
	
	return Rect2(start_x * tile_size, start_y * tile_size, room_width * tile_size, room_height * tile_size)
	
func _draw():
	for r in data["leaves"]:
		draw_rect(r.rect, Color(1, 1, 1), false, 2)
	
	for room in rooms:
		var cell_rect = get_room_cell_rect(room)
		draw_rect(cell_rect, Color(0, 1, 0), false, 2)

	# draw corridor connections as orthogonal segments (no tiles)
	# This avoids misleading diagonal lines when corridors are L-shaped on the grid.
	if data.has("connections"):
		for conn in data["connections"]:
			var a = conn["door_a"]
			var b = conn["door_b"]
			# find the room rects that contain each door point (if available)
			var room_a = null
			var room_b = null
			for room in rooms:
				var rrect = get_room_cell_rect(room)
				if rrect.has_point(a):
					room_a = rrect
					break
			for room in rooms:
				var rrect2 = get_room_cell_rect(room)
				if rrect2.has_point(b):
					room_b = rrect2
					break

			# helper lambda: snap a point to the nearest edge of a rect
			var snap_to_edge = func(p, rect):
				var left_x = rect.position.x
				var right_x = rect.position.x + rect.size.x
				var top_y = rect.position.y
				var bottom_y = rect.position.y + rect.size.y
				var d_left = abs(p.x - left_x)
				var d_right = abs(p.x - right_x)
				var d_top = abs(p.y - top_y)
				var d_bottom = abs(p.y - bottom_y)
				var min_h = min(d_left, d_right)
				var min_v = min(d_top, d_bottom)
				if min_h <= min_v:
					# snap horizontally to left or right edge
					if d_left <= d_right:
						return Vector2(left_x, clamp(p.y, top_y, bottom_y))
					else:
						return Vector2(right_x, clamp(p.y, top_y, bottom_y))
				else:
					# snap vertically to top or bottom edge
					if d_top <= d_bottom:
						return Vector2(clamp(p.x, left_x, right_x), top_y)
					else:
						return Vector2(clamp(p.x, left_x, right_x), bottom_y)

			var snapped_a = a
			var snapped_b = b
			if room_a != null:
				snapped_a = snap_to_edge.call(a, room_a)
			if room_b != null:
				snapped_b = snap_to_edge.call(b, room_b)

			# store snapped edge points for future (door state) usage
			conn["door_a_edge"] = snapped_a
			conn["door_b_edge"] = snapped_b

			# draw door markers as small filled rectangles centered on the edge (only if open)
			var door_size = tile_size * 0.6
			var door_open = true
			if conn.has("door_open"):
				door_open = conn["door_open"]
			if door_open:
				draw_rect(Rect2(snapped_a - Vector2(door_size/2, door_size/2), Vector2(door_size, door_size)), Color(1, 0.5, 0), true)
				draw_rect(Rect2(snapped_b - Vector2(door_size/2, door_size/2), Vector2(door_size, door_size)), Color(1, 0.5, 0), true)
			else:
				# closed door: draw a small blocking bar across the wall (perpendicular to wall)
				# determine wall orientation for each door by comparing to room rect
				var draw_closed = func(edge_point, room_rect):
					# if edge x is on vertical wall (left/right), draw short horizontal bar
					if is_equal_approx(edge_point.x, room_rect.position.x) or is_equal_approx(edge_point.x, room_rect.position.x + room_rect.size.x):
						var bar_w = tile_size * 0.6
						draw_line(edge_point - Vector2(bar_w/2, 0), edge_point + Vector2(bar_w/2, 0), Color(0.8, 0.2, 0.2), 4)
					else:
						var bar_h = tile_size * 0.6
						draw_line(edge_point - Vector2(0, bar_h/2), edge_point + Vector2(0, bar_h/2), Color(0.8, 0.2, 0.2), 4)
				# draw closed bars for each door (use room rect if available, else draw small cross)
				if room_a != null:
					draw_closed.call(snapped_a, room_a)
				else:
					draw_line(snapped_a - Vector2(door_size/2, 0), snapped_a + Vector2(door_size/2, 0), Color(0.8, 0.2, 0.2), 4)
				if room_b != null:
					draw_closed.call(snapped_b, room_b)
				else:
					draw_line(snapped_b - Vector2(door_size/2, 0), snapped_b + Vector2(door_size/2, 0), Color(0.8, 0.2, 0.2), 4)
			# highlight left/right leaf rects if provided
			if conn.has("left_leaf") and conn.has("right_leaf"):
				draw_rect(conn["left_leaf"], Color(0, 0, 1, 0.15), true)
				draw_rect(conn["right_leaf"], Color(1, 0, 1, 0.15), true)
			# draw axis-aligned corridor: straight if aligned, otherwise L-shaped via a corner
			# Draw a central straight corridor segment (horizontal or vertical) and short perpendicular stubs from doors
			# prefer explicit geometry when present
			if conn.has("floor_rect"):
				# draw floor (semi-transparent)
				draw_rect(conn["floor_rect"], Color(1, 0.6, 0.6, 0.5), true)
				# draw walls
				if conn.has("wall_rects"):
					for w in conn["wall_rects"]:
						draw_rect(w, Color(0.2, 0.2, 0.2, 1), true)
			else:
				# fallback to old line drawing
				var a_edge = snapped_a
				var b_edge = snapped_b
				var dx = abs(a_edge.x - b_edge.x)
				var dy = abs(a_edge.y - b_edge.y)
				if is_equal_approx(a_edge.x, b_edge.x) or is_equal_approx(a_edge.y, b_edge.y):
					# already aligned; draw direct segment
					draw_line(a_edge, b_edge, Color(1, 0, 0), 2)
				else:
					# decide main axis by larger separation (prefer the longer span)
					var half = tile_size * 0.5
					if dx >= dy:
						# horizontal main corridor: y snapped to tile-center midpoint
						var raw_y = (a_edge.y + b_edge.y) * 0.5
						var main_y = floor(raw_y / tile_size) * tile_size + half
						var x1 = min(a_edge.x, b_edge.x)
						var x2 = max(a_edge.x, b_edge.x)
						# draw main horizontal line
						draw_line(Vector2(x1, main_y), Vector2(x2, main_y), Color(1, 0, 0), 2)
						# draw short perpendicular stubs from each door to main line
						draw_line(a_edge, Vector2(a_edge.x, main_y), Color(1, 0.5, 0), 2)
						draw_line(b_edge, Vector2(b_edge.x, main_y), Color(1, 0.5, 0), 2)
					else:
						# vertical main corridor: x snapped to tile-center midpoint
						var raw_x = (a_edge.x + b_edge.x) * 0.5
						var main_x = floor(raw_x / tile_size) * tile_size + half
						var y1 = min(a_edge.y, b_edge.y)
						var y2 = max(a_edge.y, b_edge.y)
						# draw main vertical line
						draw_line(Vector2(main_x, y1), Vector2(main_x, y2), Color(1, 0, 0), 2)
						# draw short perpendicular stubs from each door to main line
						draw_line(a_edge, Vector2(main_x, a_edge.y), Color(1, 0.5, 0), 2)
						draw_line(b_edge, Vector2(main_x, b_edge.y), Color(1, 0.5, 0), 2)
