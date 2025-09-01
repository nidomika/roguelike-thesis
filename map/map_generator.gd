extends Object
class_name MapGenerator

var leaves = []
var rooms = []

@export var tile_size: int = 16
@export var min_leaf_tiles: Vector2i = Vector2i(6, 6)
@export var split_min_factor: float = 0.4
@export var split_max_factor: float = 0.6
@export var max_depth: int = 6
@export var use_mst: bool = true
@export var min_room_tiles: Vector2i = Vector2i(2, 2) # minimum room size in tiles (w, h) — lowered so small rooms are allowed during tuning
@export var max_room_aspect: float = 3.0 # max(length/width) (longer/shorter); raised to be less strict so borderline skinny rooms are kept
@export var min_room_area_tiles: int = 8 # minimum area in tiles — lowered to keep more rooms
@export var enable_room_filter: bool = true # toggle to disable room filtering during tuning

func generate_map(map_rect: Rect2) -> Dictionary:
	rooms.clear()
	
	var bsp = BSPGenerator.new()
	# sync BSP params with map generator settings so splits respect tile and leaf size
	bsp.min_width = int(min_leaf_tiles.x * tile_size)
	bsp.min_height = int(min_leaf_tiles.y * tile_size)
	bsp.split_min_factor = split_min_factor
	bsp.split_max_factor = split_max_factor
	bsp.max_depth = max_depth
	var bsp_root = bsp.generate_tree(map_rect)
	var all_leaves = bsp_root.get_leaves()
	for leaf in all_leaves:
		leaf.has_room = false

	var candidates := []
	var min_px = min_leaf_tiles * tile_size
	for leaf in all_leaves:
		if leaf.rect.size.x >= min_px.x and leaf.rect.size.y >= min_px.y:
			leaf.has_room = true
			candidates.append(leaf)

	# place rooms with collision avoidance
	for leaf in candidates:
		var placed = false
		var tries = 5
		for i in range(tries):
			var room_rect = try_place_room(leaf, tile_size)
			if room_rect != null:
				var room = Room.new(leaf.rect, null, min_room_tiles, tile_size)
				room.set_room_rect(room_rect)
				rooms.append(room)
				placed = true
				break
		if not placed:
			leaf.has_room = false

	for leaf in all_leaves:
		print(leaf.rect, leaf.has_room, leaf.parent, leaf.sibling)
		
	# Filter out rooms that are too small or have extreme aspect ratios so they won't be connected
	if rooms.size() > 0 and enable_room_filter:
		var kept := []
		var dropped := []
		print("[MapGenerator] prefilter rooms=", rooms.size(), " thresholds: min_tiles=", min_room_tiles, " min_area=", min_room_area_tiles, " max_aspect=", max_room_aspect)
		for room in rooms:
			var w_tiles = int(room.room_rect.size.x / tile_size)
			var h_tiles = int(room.room_rect.size.y / tile_size)
			var bad_size = (w_tiles < min_room_tiles.x) or (h_tiles < min_room_tiles.y)
			var area_tiles = w_tiles * h_tiles
			var bad_area = area_tiles < min_room_area_tiles
			# aspect: ratio of longer side to shorter side
			var aspect = 1.0
			if w_tiles > 0 and h_tiles > 0:
				var longer = max(w_tiles, h_tiles)
				var shorter = min(w_tiles, h_tiles)
				aspect = float(longer) / float(max(1, shorter))
			var bad_ratio = aspect > max_room_aspect
			var drop = bad_size or bad_area or bad_ratio
			print("[MapGenerator] room size tiles=", w_tiles, "x", h_tiles, " area=", area_tiles, " aspect=", aspect, " bad_size=", bad_size, " bad_area=", bad_area, " bad_ratio=", bad_ratio, " => drop=", drop)
			if drop:
				# mark leaf as having no room and drop
				if room.leaf_rect:
					# find corresponding leaf and mark
					# leaves contain rects; iterate all_leaves to unset
					for lf in all_leaves:
						if lf.rect == room.leaf_rect:
							lf.has_room = false
					dropped.append(room)
			else:
				kept.append(room)
		rooms = kept
		print("[MapGenerator] dropped rooms=", dropped.size(), " kept=", rooms.size())
	# attempt to load corridor generator at runtime to avoid static parse/class-resolution issues
	var connections := []
	var cg_script = load("res://map/corridor_generator.gd")
	if cg_script != null:
		var cg = cg_script.new()
		if cg != null:
			if use_mst and cg.has_method("generate_mst"):
				connections = cg.generate_mst(rooms, bsp_root, tile_size)
			elif cg.has_method("generate"):
				# sibling-only or generic generator that may need the bsp_root
				connections = cg.generate(rooms, bsp_root, tile_size)
			else:
				connections = []
	else:
		# leave empty if not available
		connections = []
	
	print("[MapGenerator] final rooms=", rooms.size(), " connections=", connections.size())
	return {
		"root": bsp_root,
		"rooms": rooms,
		"connections": connections,
		"leaves": all_leaves
	}

func try_place_room(leaf, _tile_size: int) -> Variant:
	# return the inner rect of the leaf (leaf minus 1 tile margin), aligned to tile grid
	var margin_tiles = 1
	var margin = margin_tiles * _tile_size

	var inner_left = leaf.rect.position.x + margin
	var inner_top = leaf.rect.position.y + margin
	var inner_right = leaf.rect.position.x + leaf.rect.size.x - margin
	var inner_bottom = leaf.rect.position.y + leaf.rect.size.y - margin

	# tile-aligned bounds (inclusive)
	var left_tile = int(ceil(inner_left / _tile_size))
	var top_tile = int(ceil(inner_top / _tile_size))
	var right_tile = int(floor(inner_right / _tile_size))
	var bottom_tile = int(floor(inner_bottom / _tile_size))

	var tiles_w = right_tile - left_tile + 1
	var tiles_h = bottom_tile - top_tile + 1

	if tiles_w <= 0 or tiles_h <= 0:
		return null

	var pos = Vector2(left_tile * _tile_size, top_tile * _tile_size)
	var size = Vector2(tiles_w * _tile_size, tiles_h * _tile_size)
	return Rect2(pos, size)
