extends Node2D

var tile_size: int = 16
var root_node: Branch
var spikes: PackedScene = preload("res://rooms/spikes.tscn")

@export var world_size: Vector2i = Vector2i(80, 60)

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")


func _ready():
	generate_dungeon()
	queue_redraw()


func paint_world(source_id: int, atlas_coords: Vector2i, area: Vector2i) -> void:
	for x in range(area.x):
		for y in range(area.y):
			tilemap.set_cell(0, Vector2i(x, y), source_id, atlas_coords)


func paint_floor() -> void:
	var target_cells = tilemap.get_used_cells_by_id(0, 1, Vector2i(2, 1))
	tilemap.set_cells_terrain_connect(0, target_cells, 0, 1, false)


func generate_dungeon() -> void:
	paint_world(1, Vector2i(0, 3), Vector2i(100, 100))
	root_node = Branch.new(Vector2i(0, 0), world_size)
	root_node.split(10)

	root_node.assign_monsters(1, 3)
	
	for leaf in root_node.get_leaves():
		if leaf.position != Vector2i(0, 0) and leaf.room_size > leaf.min_monster_spawn_size:
			place_player_detector_for_room(leaf)
		for x in range(leaf.room_size.x):
			for y in range(leaf.room_size.y):
				tilemap.set_cells_terrain_connect(0, [Vector2i(x + leaf.room_position.x, y + leaf.room_position.y)], 1, 0, false)

	var mst_connections = root_node.generate_mst_connections()

	for connection in mst_connections:
		create_corridor(connection['start'], connection['end'])

	paint_floor()


func create_corridor(start: Vector2i, end: Vector2i) -> void:
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


func place_player_detector_for_room(leaf: Branch) -> void:
	var player_detector: PackedScene = preload("res://rooms/player_detector.tscn")
	var detector = player_detector.instantiate()
	
	detector.room_position = leaf.room_position
	detector.room_size = leaf.room_size
	detector.tile_size = tile_size
	detector.position = leaf.room_position * tile_size
	detector.center = leaf.get_center() * tile_size
	detector.enemies_count = leaf.enemies_count
	add_child(detector)


func place_spikes(_tile_pos: Vector2i) -> void:
	var spikes_instance = spikes.instantiate()
	get_node("Traps").add_child(spikes_instance)
	pass
