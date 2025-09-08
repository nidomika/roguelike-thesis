extends Node2D
class_name Map

var data 
var world_pos = Vector2.ZERO
var world_size = Vector2(900, 600)

var rooms

@export var tile_size: int = 16
@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@export var detector_min_dim: int = 6 
@export var detector_min_area: int = 12
@export var door_tile_layer: int = 1
@export var door_tile_id: int = 3
@export var door_tile_coord: Vector2i = Vector2i(0, 2)

signal map_ready(start_pos)
signal boss_triggered(player)
var _boss_triggered: bool = false

var PotionScene = preload("res://objects/potion.tscn")

func _ready():
	var map_rect = Rect2(world_pos, world_size)
	var map_generator = MapGenerator.new()
	data = map_generator.generate_map(map_rect)
	rooms = data["rooms"]

	if data != null:
		var gu = GraphUtils.new()
		var path = gu.get_longest_path_from_data(data)
		if path.size() >= 2:
			data["longest_path"] = path
			data["start_room_index"] = path[0]
			data["end_room_index"] = path[path.size() - 1]
		else:
			data["start_room_index"] = 0 if rooms.size() > 0 else -1
			data["end_room_index"] = data["start_room_index"]

	if data.has("connections"):
		for c in data["connections"]:
			if not c.has("door_open"):
				c["door_open"] = true
		for i in range(data["connections"].size()):
			var c2 = data["connections"][i]
			if not c2.get("door_open", true):
				_paint_connection_doors(i, false)

	for ri in range(rooms.size()):
		var entrances = get_room_entrances(ri)
		var dpos := []
		for e in entrances:
			var conn = data["connections"][e["conn_index"]]
			var entry = {"pos": e["pos"], "conn_index": e["conn_index"], "side": e["side"], "tile_index": e["tile_index"]}
			if conn.has("door_a_tiles"):
				if conn.get("room_a_index", -1) == ri:
					entry["tiles"] = conn["door_a_tiles"]
					entry["tile_index_range"] = conn.get("door_a_tile_index_range", entry["tile_index"])
			if conn.has("door_b_tiles"):
				if conn.get("room_b_index", -1) == ri:
					entry["tiles"] = conn["door_b_tiles"]
					entry["tile_index_range"] = conn.get("door_b_tile_index_range", entry["tile_index"])
			dpos.append(entry)
		rooms[ri].door_positions = dpos

	var start_room_idx = data.get("start_room_index", -1)
	var end_room_idx = data.get("end_room_index", -1)
	for ri in range(rooms.size()):
		var room = rooms[ri]
		add_child(room)
		room.position = room.room_rect.position
		
		var size_tiles = room.get_size_tiles()
		var area_tiles = size_tiles.x * size_tiles.y
		if ri != start_room_idx and ri != end_room_idx:
			if size_tiles.x >= detector_min_dim and size_tiles.y >= detector_min_dim and area_tiles >= detector_min_area:
				room.setup_detector(tile_size, ri)
				var spn = room.get_node("Spawner")
				spn.connect("cleared", Callable(self, "_on_room_cleared"))
			else:
				if randi() % 5 == 0:
					var potion = PotionScene.instantiate()
					room.add_child(potion)
					potion.global_position = room.get_center()

		room.connect("player_entered", Callable(self, "_on_player_entered_room"))

	generate_tiles()
	place_boss_trigger_center()
	
	var si = data.get("start_room_index", -1)

	var centers = GraphUtils.new().get_room_centers(rooms)
	if si >= 0 and si < centers.size():
		emit_signal("map_ready", centers[si])


func set_door_state(conn_index: int, open: bool) -> void:
	data["connections"][conn_index]["door_open"] = open
	_paint_connection_doors(conn_index, open)


func _paint_connection_doors(conn_index: int, open: bool) -> void:
	var conn = data["connections"][conn_index]
	var door_cells := []

	if conn.has("door_a_tiles"):
		door_cells.append_array(conn["door_a_tiles"])
	if conn.has("door_b_tiles"):
		door_cells.append_array(conn["door_b_tiles"])

	var cells_vec := []
	for c in door_cells:
		cells_vec.append(c)

	if open:
		tilemap.set_cells_terrain_connect(0, cells_vec, 0, 1, false)
		for pos in cells_vec:
			tilemap.set_cell(door_tile_layer, pos, -1)
	else:
		tilemap.set_cells_terrain_connect(0, cells_vec, 1, 0, false)
		for pos in cells_vec:
			tilemap.set_cell(door_tile_layer, pos, door_tile_id, door_tile_coord)


func _on_player_entered_room(room_index: int) -> void:
	call_deferred("_handle_player_entered_room", room_index)


func _handle_player_entered_room(room_index: int) -> void:
	var room = rooms[room_index]

	for entry in room.door_positions:
		var conn_idx = entry.get("conn_index", -1)
		if conn_idx != -1:
			set_door_state(conn_idx, false)

	var spn = room.get_node("Spawner")
	var inner_rect = room.room_rect.grow(-tile_size)
	spn.spawn_in_room(room, room_index, inner_rect, tile_size)


func _on_room_cleared(room_index: int) -> void:
	var room = rooms[room_index]
	room.is_cleared = true
	for entry in room.door_positions:
		var conn_idx = entry.get("conn_index", -1)
		if conn_idx != -1:
			set_door_state(conn_idx, true)


func generate_tiles():
	tilemap.clear()
	
	var floor_cells_set = {}
	
	for room in rooms:
		var start_x = int(room.room_rect.position.x / tile_size)
		var start_y = int(room.room_rect.position.y / tile_size)
		var room_width = int(room.room_rect.size.x / tile_size)
		var room_height = int(room.room_rect.size.y / tile_size)
		
		for x in range(start_x, start_x + room_width):
			for y in range(start_y, start_y + room_height):
				floor_cells_set[Vector2i(x, y)] = true

	for conn in data["connections"]:
		var fr: Rect2 = conn["floor_rect"]
		var sx = int(fr.position.x / tile_size)
		var sy = int(fr.position.y / tile_size)
		var w = int(fr.size.x / tile_size)
		var h = int(fr.size.y / tile_size)
		for x in range(sx, sx + w):
			for y in range(sy, sy + h):
				floor_cells_set[Vector2i(x, y)] = true

	var wall_cells_set = {}
	
	var total_bbox = data.leaves[0].rect
	for i in range(1, data.leaves.size()):
		total_bbox = total_bbox.merge(data.leaves[i].rect)
	
	var min_x = int(total_bbox.position.x / tile_size)
	var max_x = int(total_bbox.end.x / tile_size)
	var min_y = int(total_bbox.position.y / tile_size)
	var max_y = int(total_bbox.end.y / tile_size)

	for x in range(min_x, max_x):
		for y in range(min_y, max_y):
			var cell = Vector2i(x, y)
			if not floor_cells_set.has(cell):
				wall_cells_set[cell] = true
	
	for x in range(min_x - 1, max_x + 1):
		wall_cells_set[Vector2i(x, min_y - 1)] = true
		wall_cells_set[Vector2i(x, max_y)] = true
	for y in range(min_y - 1, max_y + 1):
		wall_cells_set[Vector2i(min_x - 1, y)] = true
		wall_cells_set[Vector2i(max_x, y)] = true

	var wall_cells_array = wall_cells_set.keys()
	tilemap.set_cells_terrain_connect(0, wall_cells_array, 1, 0)
	
	var all_floor_cells = floor_cells_set.keys()
	tilemap.set_cells_terrain_connect(0, all_floor_cells, 0, 1)


func get_room_entrances(room_index: int) -> Array:
	var entrances := []
	for i in range(data["connections"].size()):
		var c = data["connections"][i]
		if c.get("room_a_index", -1) == room_index:
			var tile_info = null
			if c.has("door_a_tiles") and not c["door_a_tiles"].is_empty():
				tile_info = c["door_a_tiles"][0]
			elif c.has("door_a_tile"):
				tile_info = c["door_a_tile"]

			entrances.append({"pos": tile_info, "conn_index": i, "side": "a", "tile_index": tile_info})

		if c.get("room_b_index", -1) == room_index:
			var tile_info = null
			if c.has("door_b_tiles") and not c["door_b_tiles"].is_empty():
				tile_info = c["door_b_tiles"][0]
			elif c.has("door_b_tile"):
				tile_info = c["door_b_tile"]
				
			entrances.append({"pos": tile_info, "conn_index": i, "side": "b", "tile_index": tile_info})
	return entrances


func place_boss_trigger_center() -> void:
	var ei = int(data.get("end_room_index", -1))
	
	var room = rooms[ei]
	var trigger_pos = room.get_center()
	var tile = tilemap.local_to_map(trigger_pos)
	
	tilemap.set_cell(door_tile_layer, tile, 3, Vector2i(0, 0))

	var local_world = tilemap.map_to_local(tile)
	var world = tilemap.to_global(local_world)

	var a = Area2D.new()
	a.collision_layer = 1
	a.collision_mask = 2
	a.name = "BossTrigger"

	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(tile_size, tile_size)
	col.shape = rect
	a.add_child(col)

	add_child(a)
	a.global_position = world
	a.connect("body_entered", Callable(self, "_on_boss_trigger_body_entered"))


func _on_boss_trigger_body_entered(body: Node) -> void:
	if _boss_triggered:
		return

	_boss_triggered = true

	var trigger_node = get_node("BossTrigger")
	var trigger_tile = tilemap.local_to_map(trigger_node.position)
	tilemap.set_cell(door_tile_layer, trigger_tile, -1)
	trigger_node.queue_free()

	emit_signal("boss_triggered", body)
