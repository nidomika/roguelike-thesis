extends Object
class_name MapGenerator

var leaves = []
var rooms = []

@export var tile_size: int = 16
@export var min_leaf_tiles: Vector2i = Vector2i(10, 10)
@export var split_min_factor: float = 0.3
@export var split_max_factor: float = 0.7
@export var max_depth: int = 4

func generate_map(map_rect: Rect2) -> Dictionary:
	rooms.clear()
	
	var bsp_root = BSPGenerator.new().generate_tree(map_rect)
	var all_leaves = bsp_root.get_leaves()
	for leaf in all_leaves:
		leaf.has_room = false

	var candidates := []
	var min_px = min_leaf_tiles * tile_size
	for leaf in all_leaves:
		if leaf.rect.size.x >= min_px.x and leaf.rect.size.y >= min_px.y:
			leaf.has_room = true
			candidates.append(leaf)

	for leaf in candidates:
		var room = Room.new(leaf.rect)
		rooms.append(room)

	for leaf in all_leaves:
		print(leaf.rect, leaf.has_room, leaf.parent, leaf.sibling)
		
	var connections = CorridorGenerator.new().generate(rooms, bsp_root, tile_size)
	
	return {
		"root": bsp_root,
		"rooms": rooms,
		"connections": connections,
		"leaves": all_leaves
	}
