extends Node2D

var tile_size: int = 16
var root_node: Branch
var spikes: PackedScene = preload("res://rooms/spikes.tscn")

@export var world_size: Vector2i = Vector2i(100, 60)

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var player: Character = get_node("Player")


var spawn_room_coords: Vector2i
var boss_room_coords: Vector2i

func _ready():
	generate_dungeon()
	player.global_position = spawn_room_coords * tile_size
	queue_redraw()


func paint_world(source_id: int, atlas_coords: Vector2i, area: Vector2i, offset: Vector2i = Vector2i(0, 0)) -> void:
	for x in range(area.x):
		for y in range(area.y):
			tilemap.set_cell(0, Vector2i(x + offset.x, y + offset.y), source_id, atlas_coords)


func paint_floor() -> void:
	var target_cells = tilemap.get_used_cells_by_id(0, 1, Vector2i(2, 1))
	tilemap.set_cells_terrain_connect(0, target_cells, 0, 1, false)


func generate_dungeon() -> void:
	paint_world(1, Vector2i(0, 3), Vector2i(150, 150), Vector2i(-20,-20))
	root_node = Branch.new(Vector2i(0, 0), world_size)
	root_node.split(12)

	root_node.assign_monsters(1, 7)
	
	var leaves = root_node.get_leaves()
	var mst_connections = root_node.generate_mst_connections()
	var farthest_data = root_node.find_two_farthest_rooms(leaves, mst_connections)

	for leaf in leaves:
		var room_scene = preload("res://rooms/Room.tscn")
		var room_instance = room_scene.instantiate()
		room_instance.init_room(leaf.room_position, leaf.room_size, leaf.enemies_count)
		
		if leaf.get_corridor_entrance() == farthest_data["start"]: 
			room_instance.type = "spawn"
			spawn_room_coords = leaf.get_center()
		elif leaf.get_corridor_entrance() == farthest_data["end"]: 
			room_instance.type = "boss"
		else: 
			room_instance.type = "normal"
		
		get_node("Rooms").add_child(room_instance)
		room_instance.add_to_group("rooms")

		for x in range(leaf.room_size.x):
			for y in range(leaf.room_size.y):
				tilemap.set_cells_terrain_connect(0, [Vector2i(x + leaf.room_position.x, y + leaf.room_position.y)], 1, 0, false)

	for connection in mst_connections:
		create_corridor(connection['start'], connection['end'])
	
	#var rooms = get_tree().get_nodes_in_group("rooms")
	#for room in rooms:
		#print(room.room_size)
	paint_floor()
	print(farthest_data)


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


func place_spikes(_tile_pos: Vector2i) -> void:
	var spikes_instance = spikes.instantiate()
	get_node("Traps").add_child(spikes_instance)
	pass
