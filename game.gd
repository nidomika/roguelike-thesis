extends Node2D

var tile_size: int = 16
var root_node: Branch

@export var world_size: Vector2i = Vector2i(80, 60)

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")

func _ready():
	generate_dungeon()
	queue_redraw()

func generate_dungeon():
	paint_world(1, Vector2i(0, 3), Vector2i(100, 100))
	root_node = Branch.new(Vector2i(0, 0), world_size)
	root_node.split(4)
	for leaf in root_node.get_leaves():
		#draw_rect(Rect2(leaf.position * tile_size, leaf.size * tile_size), Color.GREEN, false)
		var padding = Vector4i(
			randi_range(1,2),
			randi_range(1,2),
			randi_range(1,2),
			randi_range(1,2)
		)
	
		for x in range(leaf.size.x):
			for y in range(leaf.size.y):
				if not is_inside_padding(x, y, leaf, padding):
					tilemap.set_cells_terrain_connect(0, [Vector2i(x + leaf.position.x, y + leaf.position.y)], 1, 0, false)
	
	var mst_connections = root_node.generate_mst_connections()
	for connection in mst_connections:
		create_corridor(connection['start'], connection['end'])
	paint_floor()

func is_inside_padding(x, y, leaf, padding):
	return x <= padding.x or y <= padding.y or x >= leaf.size.x - padding.z or y >= leaf.size.y - padding.w

func paint_world(source_id: int, atlas_coords: Vector2i, area: Vector2i):
	for x in range(area.x):
		for y in range(area.y):
			tilemap.set_cell(0, Vector2i(x, y), source_id, atlas_coords)

func create_corridor(start: Vector2i, end: Vector2i):
	var corridor_tiles = []

	if randf() < 0.5:
		for x in range(min(start.x, end.x), max(start.x, end.x) + 1):
			for t in range(-1, 1):
				corridor_tiles.append(Vector2i(x, start.y + t))
		for y in range(min(start.y, end.y), max(start.y, end.y) + 1):
			for t in range(-1, 1):
				corridor_tiles.append(Vector2i(end.x + t, y))
	else:
		for y in range(min(start.y, end.y), max(start.y, end.y) + 1):
			for t in range(-1, 1):
				corridor_tiles.append(Vector2i(start.x + t, y))
		for x in range(min(start.x, end.x), max(start.x, end.x) + 1):
			for t in range(-1, 1):
				corridor_tiles.append(Vector2i(x, end.y + t))

	tilemap.set_cells_terrain_connect(0, corridor_tiles, 1, 0, false)

func paint_floor():
	var target_cells = tilemap.get_used_cells_by_id(0, 1, Vector2i(2, 1))
	for pos in target_cells:
		tilemap.set_cells_terrain_connect(0, [pos], 0, 1, false)
