extends Object
class_name MapGenerator

@export var tile_size: int = 16
@export var min_leaf_tiles: Vector2i = Vector2i(6, 6)
@export var split_min_factor: float = 0.4
@export var split_max_factor: float = 0.6
@export var max_depth: int = 6
@export var use_mst: bool = true
@export var min_room_tiles: Vector2i = Vector2i(2, 2)
@export var max_room_aspect: float = 3.0
@export var min_room_area_tiles: int = 8
@export var enable_room_filter: bool = true

func generate_map(map_rect: Rect2) -> Dictionary:
	var bsp = BSPGenerator.new()
	bsp.min_width = int(min_leaf_tiles.x * tile_size)
	bsp.min_height = int(min_leaf_tiles.y * tile_size)
	bsp.split_min_factor = split_min_factor
	bsp.split_max_factor = split_max_factor
	bsp.max_depth = max_depth
	var bsp_root = bsp.generate_tree(map_rect)
	var all_leaves = bsp_root.get_leaves()

	var rooms = create_rooms_from_leaves(all_leaves)

	var connections = []
	var cg_script = load("res://map/corridor_generator.gd")
	if cg_script != null:
		var cg = cg_script.new()
		if use_mst and cg.has_method("generate_mst"):
			connections = cg.generate_mst(rooms, bsp_root, tile_size)
		elif cg.has_method("generate"):
			connections = cg.generate(rooms, bsp_root, tile_size)

	return {
		"root": bsp_root,
		"rooms": rooms,
		"connections": connections,
		"leaves": all_leaves
	}

func create_rooms_from_leaves(leaves: Array) -> Array:
	var created_rooms = []
	var min_px = min_leaf_tiles * tile_size
	for leaf in leaves:
		if leaf.rect.size.x < min_px.x or leaf.rect.size.y < min_px.y:
			continue

		var room_rect = get_inner_rect(leaf.rect, tile_size)
		if not room_rect:
			continue

		var w_tiles = int(room_rect.size.x / tile_size)
		var h_tiles = int(room_rect.size.y / tile_size)

		if enable_room_filter:
			if w_tiles < min_room_tiles.x or h_tiles < min_room_tiles.y:
				continue
			
			var area_tiles = w_tiles * h_tiles
			if area_tiles < min_room_area_tiles:
				continue
			
			var aspect = 1.0
			if w_tiles > 0 and h_tiles > 0:
				var longer = max(w_tiles, h_tiles)
				var shorter = min(w_tiles, h_tiles)
				aspect = float(longer) / float(max(1, shorter))
			
			if aspect > max_room_aspect:
				continue

		var room = Room.new(room_rect)
		created_rooms.append(room)
	return created_rooms

func get_inner_rect(rect: Rect2, tile_size_in: int) -> Rect2:
	var margin = 2 * tile_size_in
	var inner_left = rect.position.x + margin
	var inner_top = rect.position.y + margin
	var inner_right = rect.position.x + rect.size.x - margin
	var inner_bottom = rect.position.y + rect.size.y - margin

	var left_tile = int(ceil(inner_left / tile_size_in))
	var top_tile = int(ceil(inner_top / tile_size_in))
	var right_tile = int(floor(inner_right / tile_size_in))
	var bottom_tile = int(floor(inner_bottom / tile_size_in))

	var tiles_w = right_tile - left_tile + 1
	var tiles_h = bottom_tile - top_tile + 1

	if tiles_w <= 0 or tiles_h <= 0:
		return Rect2()

	var pos = Vector2(left_tile * tile_size_in, top_tile * tile_size_in)
	var size = Vector2(tiles_w * tile_size_in, tiles_h * tile_size_in)
	return Rect2(pos, size)
