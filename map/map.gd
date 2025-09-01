extends Node2D
class_name Map

var data 
var world_pos = Vector2.ZERO
var world_size = Vector2(900, 600) # docelowo (1280,720)

var rooms
var door_blockers := {} # conn_index -> Array of StaticBody2D nodes
var _door_blockers_node: Node = null

@export var tile_size: int = 16
@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@export var debug_draw_corridors: bool = false
@export var highlighted_room_index: int = -1 # set to room index to visually mark its entrances
@export var debug_draw_door_tiles: bool = false
@export var detector_min_dim: int = 6 # min width/height in tiles to create a detector
@export var detector_min_area: int = 12 # min area in tiles to create a detector

signal map_ready(start_pos)

func highlight_room_entrances(index: int) -> void:
	# external API to set which room's entrances should be highlighted
	highlighted_room_index = index
	call_deferred("_deferred_redraw")


func log_room_doors(room_index: int = -1) -> void:
	# Debug helper: print door entries for one room or all rooms when room_index < 0
	if rooms == null:
		print("[Map] rooms not generated")
		return
	var indices := []
	if room_index < 0:
		for i in range(rooms.size()):
			indices.append(i)
	else:
		if room_index >= 0 and room_index < rooms.size():
			indices.append(room_index)
		else:
			print("[Map] invalid room_index", room_index)
			return

	for ri in indices:
		var r = rooms[ri]
		var entries = r.get_door_entries()
		print("--- Room ", ri, " rect=", r.room_rect)
		if entries.size() == 0:
			# no stored entries; show computed entrances as fallback
			var comp = get_room_entrances(ri)
			print("  stored: none; computed entrances count=", comp.size())
			for e in comp:
				print("    conn=", e["conn_index"], " pos=", e["pos"], " side=", e["side"], " tile_idx=", e["tile_index"])
		else:
			for e in entries:
				print("  door pos=", e.get("pos"), " conn=", e.get("conn_index"), " side=", e.get("side"), " tile_idx=", e.get("tile_index"))

func _ready():
	var map_rect = Rect2(world_pos, world_size)
	var map_generator = MapGenerator.new()
	data = map_generator.generate_map(map_rect)
	rooms = data["rooms"]
	# determine start/end rooms using longest path (tree diameter)
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
	# ensure every connection has a door_open flag (default: true = open)
	if data.has("connections"):
		for i in range(data["connections"].size()):
			var c = data["connections"][i]
			if not c.has("door_open"):
				c["door_open"] = true
		# initialize blockers for any doors that are closed by default
		for i2 in range(data["connections"].size()):
			var c2 = data["connections"][i2]
			if not c2.get("door_open", true):
				_paint_connection_doors(i2, false)
				_add_door_blockers(i2)
		# optional single debug print of counts
		if debug_draw_door_tiles:
			var cnt_a = 0
			var cnt_b = 0
			for cdebug in data["connections"]:
				if cdebug.has("door_a_tiles"):
					cnt_a += 1
				if cdebug.has("door_b_tiles"):
					cnt_b += 1
			print("[Map] door tile entries - connections=", data["connections"].size(), " with door_a_tiles=", cnt_a, " door_b_tiles=", cnt_b)

	# populate precise door positions on each room (so Room.get_door_positions() can return them)
	for ri in range(rooms.size()):
		var entrances = get_room_entrances(ri)
		var dpos := []
		# store rich entrance dicts on the Room for downstream use
		for e in entrances:
			var conn = data["connections"][e["conn_index"]]
			var entry = {"pos": e["pos"], "conn_index": e["conn_index"], "side": e["side"], "tile_index": e["tile_index"]}
			# if connection provides two-tile opening info, include it
			if conn.has("door_a_tiles"):
				if conn.get("room_a_index", -1) == ri:
					entry["tiles"] = conn["door_a_tiles"]
					entry["tile_index_range"] = conn.get("door_a_tile_index_range", Vector2i(entry["tile_index"], entry["tile_index"]))
			if conn.has("door_b_tiles"):
				if conn.get("room_b_index", -1) == ri:
					entry["tiles"] = conn["door_b_tiles"]
					entry["tile_index_range"] = conn.get("door_b_tile_index_range", Vector2i(entry["tile_index"], entry["tile_index"]))
			dpos.append(entry)
		rooms[ri].door_positions = dpos

	# attach each Room Node as a child and let the Room own its detector
	var start_room_idx = data.get("start_room_index", -1)
	for ri in range(rooms.size()):
		var room = rooms[ri]
		# make sure room is a Node so it can own children (rooms are Room instances)
		add_child(room)
		# position the Room node to its room_rect origin so local detector position works
		room.position = room.room_rect.position
		# Do not create a detector for the room where the player will spawn
		var size_tiles = room.get_size_tiles()
		var area_tiles = size_tiles.x * size_tiles.y
		if ri == start_room_idx:
			print("[Map] skipping detector for start room index=", ri)
			# explicit skip for start room
		elif size_tiles.x < detector_min_dim or size_tiles.y < detector_min_dim or area_tiles < detector_min_area:
			print("[Map] skipping detector for room index=", ri, " size_tiles=", size_tiles, " area=", area_tiles)
		else:
			room.setup_detector("res://miscellaneous/player_detector.tscn", tile_size, ri)
		# connect room-level player_entered to Map handler
		room.connect("player_entered", Callable(self, "_on_player_entered_room"))
	generate_tiles()

	# emit map_ready with start position so game.gd can place the player
	var si = data.get("start_room_index", -1)
	var centers = GraphUtils.new().get_room_centers(rooms)
	if si >= 0 and si < centers.size():
		emit_signal("map_ready", centers[si])


func set_door_state(conn_index: int, open: bool) -> void:
	if not data or not data.has("connections"):
		return
	if conn_index < 0 or conn_index >= data["connections"].size():
		return
	data["connections"][conn_index]["door_open"] = open
	# paint tiles to represent open/closed state
	_paint_connection_doors(conn_index, open)
	# add/remove collision blockers for closed doors
	if open:
		_remove_door_blockers(conn_index)
	else:
		_add_door_blockers(conn_index)
	call_deferred("_deferred_redraw")


func _paint_connection_side(conn_index: int, side: String, open: bool) -> void:
	# Paint only one side ("a" or "b") of a connection's door tiles
	if not data or not data.has("connections"):
		return
	if conn_index < 0 or conn_index >= data["connections"].size():
		return
	var conn = data["connections"][conn_index]
	var door_cells := []
	if side == "a":
		if conn.has("door_a_tiles"):
			for t in conn["door_a_tiles"]:
				door_cells.append(t)
		elif conn.has("door_a_tile"):
			door_cells.append(conn["door_a_tile"])
	elif side == "b":
		if conn.has("door_b_tiles"):
			for t2 in conn["door_b_tiles"]:
				door_cells.append(t2)
		elif conn.has("door_b_tile"):
			door_cells.append(conn["door_b_tile"])
	else:
		return
	if door_cells.size() == 0:
		return
	var terrain_set_idx = 0
	var terrain_idx = 1
	if not open:
		terrain_set_idx = 1
		terrain_idx = 0
	tilemap.set_cells_terrain_connect(0, door_cells, terrain_idx, terrain_set_idx, false)


func _add_door_blockers_for(conn_index: int, side: String) -> void:
	# Spawn blockers for one side of the connection only
	if not data or not data.has("connections"):
		return
	var conn = data["connections"][conn_index]
	var cells := []
	if side == "a":
		if conn.has("door_a_tiles"):
			for t in conn["door_a_tiles"]:
				cells.append(t)
		elif conn.has("door_a_tile"):
			cells.append(conn["door_a_tile"])
	elif side == "b":
		if conn.has("door_b_tiles"):
			for t2 in conn["door_b_tiles"]:
				cells.append(t2)
		elif conn.has("door_b_tile"):
			cells.append(conn["door_b_tile"])
	if cells.size() == 0:
		return
	var key = str(conn_index) + "_" + side
	# remove existing if present
	if door_blockers.has(key):
		_remove_door_blockers_for(conn_index, side)

	# ensure parent node
	if _door_blockers_node == null or not is_instance_valid(_door_blockers_node):
		_door_blockers_node = Node2D.new()
		_door_blockers_node.name = "DoorBlockers"
		add_child(_door_blockers_node)

	var created := []
	for cell in cells:
		var cx := -1
		var cy := -1
		if typeof(cell) == TYPE_DICTIONARY and cell.has("x") and cell.has("y"):
			cx = int(cell["x"])
			cy = int(cell["y"])
		elif cell is Vector2 or cell is Vector2i:
			cx = int(cell.x)
			cy = int(cell.y)
		else:
			print("[Map] door blocker (side): unsupported cell value:", cell)
			continue

		var sb = StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask = 1
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.extents = Vector2(tile_size * 0.5, tile_size * 0.5)
		col.shape = rect
		col.position = Vector2.ZERO
		sb.add_child(col)
		# compute world origin from tile coordinates
		var origin = tilemap.to_global(Vector2(cx * tile_size, cy * tile_size))
		sb.position = origin + Vector2(tile_size * 0.5, tile_size * 0.5)
		_door_blockers_node.add_child(sb)
		created.append(sb)

	door_blockers[key] = created


func _remove_door_blockers_for(conn_index: int, side: String) -> void:
	var key = str(conn_index) + "_" + side
	if not door_blockers.has(key):
		return
	for n in door_blockers[key]:
		if is_instance_valid(n):
			n.queue_free()
	door_blockers.erase(key)


func open_door(conn_index: int) -> void:
	set_door_state(conn_index, true)


func close_door(conn_index: int) -> void:
	set_door_state(conn_index, false)


func _paint_connection_doors(conn_index: int, open: bool) -> void:
	# Paint the door tiles using terrain_set index: 0 = ground/corridor, 1 = wall
	if not data or not data.has("connections"):
		return
	if conn_index < 0 or conn_index >= data["connections"].size():
		return
	var conn = data["connections"][conn_index]
	var door_cells := []
	# collect door tile Vector2i cells from new multi-tile fields or legacy single tile
	if conn.has("door_a_tiles"):
		for t in conn["door_a_tiles"]:
			door_cells.append(t)
	elif conn.has("door_a_tile"):
		door_cells.append(conn["door_a_tile"])
	if conn.has("door_b_tiles"):
		for t2 in conn["door_b_tiles"]:
			door_cells.append(t2)
	elif conn.has("door_b_tile"):
		door_cells.append(conn["door_b_tile"])
	# Choose terrain set/index:
	# - open doors should match rooms/corridors: terrain_set=0, terrain_idx=1
	# - closed doors should use wall terrain: terrain_set=1, terrain_idx=0
	if door_cells.size() == 0:
		return
	var terrain_set_idx = 0
	var terrain_idx = 1
	if not open:
		terrain_set_idx = 1
		terrain_idx = 0
	# Call set_cells_terrain_connect on the tiles (layer 0)
	tilemap.set_cells_terrain_connect(0, door_cells, terrain_idx, terrain_set_idx, false)


func _add_door_blockers(conn_index: int) -> void:
	# Spawn StaticBody2D + CollisionShape2D at each door tile to block movement
	if not data or not data.has("connections"):
		return
	var conn = data["connections"][conn_index]
	var cells := []
	if conn.has("door_a_tiles"):
		for t in conn["door_a_tiles"]:
			cells.append(t)
	elif conn.has("door_a_tile"):
		cells.append(conn["door_a_tile"])
	if conn.has("door_b_tiles"):
		for t2 in conn["door_b_tiles"]:
			cells.append(t2)
	elif conn.has("door_b_tile"):
		cells.append(conn["door_b_tile"])
	if cells.size() == 0:
		return
	# ensure we don't create duplicate blockers for the same connection
	var key = str(conn_index)
	if door_blockers.has(key):
		_remove_door_blockers(conn_index)

	# ensure we have a parent node for blockers
	if _door_blockers_node == null or not is_instance_valid(_door_blockers_node):
		_door_blockers_node = Node2D.new()
		_door_blockers_node.name = "DoorBlockers"
		add_child(_door_blockers_node)

	var created := []
	for cell in cells:
		# accept either a Vector2/Vector2i or a Dictionary {"x":..., "y":...}
		var cx := -1
		var cy := -1
		if typeof(cell) == TYPE_DICTIONARY and cell.has("x") and cell.has("y"):
			cx = int(cell["x"])
			cy = int(cell["y"])
		elif cell is Vector2 or cell is Vector2i:
			cx = int(cell.x)
			cy = int(cell.y)
		else:
			print("[Map] door blocker: unsupported cell value:", cell)
			continue

		var sb = StaticBody2D.new()
		sb.collision_layer = 1
		sb.collision_mask = 1
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.extents = Vector2(tile_size * 0.5, tile_size * 0.5)
		col.shape = rect
		col.position = Vector2.ZERO
		sb.add_child(col)
		# compute world origin from tile coordinates
		var origin = tilemap.to_global(Vector2(cx * tile_size, cy * tile_size))
		sb.position = origin + Vector2(tile_size * 0.5, tile_size * 0.5)
		_door_blockers_node.add_child(sb)
		created.append(sb)

	door_blockers[key] = created


func _remove_door_blockers(conn_index: int) -> void:
	var key = str(conn_index)
	if not door_blockers.has(key):
		return
	for n in door_blockers[key]:
		if is_instance_valid(n):
			n.queue_free()
	door_blockers.erase(key)



func toggle_door(conn_index: int) -> void:
	if not data or not data.has("connections"):
		return
	if conn_index < 0 or conn_index >= data["connections"].size():
		return
	var c = data["connections"][conn_index]
	var new_state = not c.get("door_open", true)
	set_door_state(conn_index, new_state)


func _on_player_entered_room(room_index: int) -> void:
	# Close all doors connected to this room (set door_open=false)
	if not data or not data.has("connections"):
		return
	for i in range(data["connections"].size()):
		var c = data["connections"][i]
		# only close the door side that belongs to the entered room
		if c.get("room_a_index", -1) == room_index:
			# close side A only
			call_deferred("_paint_connection_side", i, "a", false)
			call_deferred("_add_door_blockers_for", i, "a")
			c["door_a_open"] = false
		elif c.get("room_b_index", -1) == room_index:
			call_deferred("_paint_connection_side", i, "b", false)
			call_deferred("_add_door_blockers_for", i, "b")
			c["door_b_open"] = false
	# redraw to reflect closed doors
	call_deferred("_deferred_redraw")

func generate_tiles():
	tilemap.clear()
	var corridor_cells := []
	
	for room in rooms:
		var start_x = int(room.room_rect.position.x / tile_size)
		var start_y = int(room.room_rect.position.y / tile_size)
		var room_width = int(room.room_rect.size.x / tile_size)
		var room_height = int(room.room_rect.size.y / tile_size)
		
		for x in range(start_x, start_x + room_width):
			for y in range(start_y, start_y + room_height):
				tilemap.set_cells_terrain_connect(0, [Vector2i(x, y)], 1, 0, false)
	
	for conn in data["connections"]:
		# prefer explicit geometry when present
		var fr: Rect2 = conn["floor_rect"]
		var sx = int(fr.position.x / tile_size)
		var sy = int(fr.position.y / tile_size)
		var w = int(fr.size.x / tile_size)
		var h = int(fr.size.y / tile_size)
		for x in range(sx, sx + w):
			for y in range(sy, sy + h):
				corridor_cells.append(Vector2i(x, y))
		# add wall tiles (if any)
		if conn.has("wall_rects"):
			for wr in conn["wall_rects"]:
				var wsx = int(wr.position.x / tile_size)
				var wsy = int(wr.position.y / tile_size)
				var ww = int(wr.size.x / tile_size)
				var wh = int(wr.size.y / tile_size)
				for wx in range(wsx, wsx + max(1, ww)):
					for wy in range(wsy, wsy + max(1, wh)):
						# walls we place on the same terrain layer; autotile will handle visuals
						corridor_cells.append(Vector2i(wx, wy))
	
	if debug_draw_corridors:
		print(data)
	
	tilemap.set_cells_terrain_connect(0, corridor_cells, 1, 0, false)

	# Trigger redraw so outlines and corridor lines are visible via a safe deferred wrapper
	call_deferred("_deferred_redraw")

	# Paint door tiles according to door_open flags so initial map shows closed/open doors
	if data and data.has("connections"):
		for i in range(data["connections"].size()):
			var c = data["connections"][i]
			var open_state = c.get("door_open", true)
			_paint_connection_doors(i, open_state)
			if not open_state:
				_add_door_blockers(i)


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
	
func get_room_entrances(room_index: int) -> Array:
	var res := []
	if room_index < 0 or room_index >= rooms.size():
		return res
	var room = rooms[room_index]
	var _rrect = room.room_rect
	for i in range(data.get("connections", []).size()):
		var c = data["connections"][i]
		# fast path: if connection stores room indices, check them directly
		var ra_idx = c.get("room_a_index", null)
		var rb_idx = c.get("room_b_index", null)
		if ra_idx != null and rb_idx != null:
			if ra_idx == room_index:
				# prefer precomputed snapped edge stored on connection
				if c.has("door_a_edge"):
					var tidx = c.get("door_a_tile_index", null)
					res.append({"conn_index": i, "pos": c["door_a_edge"], "side": c.get("door_a_side", "unknown"), "tile_index": tidx})
				else:
					var da = c.get("door_a", null)
					if da != null:
						var info_a = room.get_edge_info(da)
						res.append({"conn_index": i, "pos": info_a["edge_point"], "side": info_a["side"], "tile_index": info_a["tile_index"]})
				continue
			elif rb_idx == room_index:
				if c.has("door_b_edge"):
					var tidx2 = c.get("door_b_tile_index", null)
					if tidx2 == null:
						var cell2 = c.get("door_b_tile", Vector2i(-1, -1))
						tidx2 = cell2.x
					res.append({"conn_index": i, "pos": c["door_b_edge"], "side": c.get("door_b_side", "unknown"), "tile_index": tidx2})
				else:
					var db = c.get("door_b", null)
					if db != null:
						var info_b = room.get_edge_info(db)
						res.append({"conn_index": i, "pos": info_b["edge_point"], "side": info_b["side"], "tile_index": info_b["tile_index"]})
				continue
		# fallback: previous spatial checks (containment / proximity)
		var a = c.get("door_a", null)
		var b = c.get("door_b", null)
		# Fallback spatial checks: only accept a/b if they're close to this room's edge
		# Use Room.get_edge_info to snap to the edge and require the original point to be within one tile
		if a != null:
			var info_a_fb = room.get_edge_info(a)
			var dist_a = a.distance_to(info_a_fb["edge_point"])
			if dist_a <= tile_size * 1.0:
				res.append({"conn_index": i, "pos": info_a_fb["edge_point"], "side": info_a_fb["side"], "tile_index": info_a_fb["tile_index"]})
				continue
		if b != null:
			var info_b_fb = room.get_edge_info(b)
			var dist_b = b.distance_to(info_b_fb["edge_point"])
			if dist_b <= tile_size * 1.0:
				res.append({"conn_index": i, "pos": info_b_fb["edge_point"], "side": info_b_fb["side"], "tile_index": info_b_fb["tile_index"]})
				continue
	return res

func _draw():
	for r in data["leaves"]:
		draw_rect(r.rect, Color(1, 1, 1), false, 2)
	
	for room in rooms:
		var cell_rect = get_room_cell_rect(room)
		draw_rect(cell_rect, Color(0, 1, 0), false, 2)

	# draw start/end room markers (if available)
	if data != null and data.has("start_room_index"):
		var si = int(data["start_room_index"])
		if si >= 0 and si < rooms.size():
			var centers = GraphUtils.new().get_room_centers(rooms)
			var c = centers[si]
			draw_circle(c, tile_size * 0.6, Color(0.2, 1, 0.2, 0.9))
	if data != null and data.has("end_room_index"):
		var ei = int(data["end_room_index"])
		if ei >= 0 and ei < rooms.size():
			var centers2 = GraphUtils.new().get_room_centers(rooms)
			var c2 = centers2[ei]
			var s = tile_size * 1.2
			draw_rect(Rect2(c2 - Vector2(s/2, s/2), Vector2(s, s)), Color(1, 0.2, 0.2, 0.9), true)

	# draw door tiles overlays when requested
	if debug_draw_door_tiles:
		for conn in data["connections"]:
			# door A (new multi-tile format or legacy single)
			if conn.has("door_a_tiles"):
				for t in conn["door_a_tiles"]:
					var origin_a = Vector2(t.x * tile_size, t.y * tile_size)
					draw_rect(Rect2(origin_a, Vector2(tile_size, tile_size)), Color(0.1, 0.4, 1, 0.6), true)
			elif conn.has("door_a_tile"):
				var t_a = conn["door_a_tile"]
				var origin_a2 = Vector2(t_a.x * tile_size, t_a.y * tile_size)
				draw_rect(Rect2(origin_a2, Vector2(tile_size, tile_size)), Color(0.1, 0.4, 1, 0.6), true)

			# door B
			if conn.has("door_b_tiles"):
				for t2 in conn["door_b_tiles"]:
					var origin_b = Vector2(t2.x * tile_size, t2.y * tile_size)
					draw_rect(Rect2(origin_b, Vector2(tile_size, tile_size)), Color(0.1, 0.4, 1, 0.6), true)
			elif conn.has("door_b_tile"):
				var t_b = conn["door_b_tile"]
				var origin_b2 = Vector2(t_b.x * tile_size, t_b.y * tile_size)
				draw_rect(Rect2(origin_b2, Vector2(tile_size, tile_size)), Color(0.1, 0.4, 1, 0.6), true)
