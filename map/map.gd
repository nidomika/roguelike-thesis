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
	generate_tiles()

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
		var a = conn["door_a"]
		var b = conn["door_b"]
		var cell_a = Vector2i(int(a.x / tile_size), int(a.y / tile_size))
		var cell_b = Vector2i(int(b.x / tile_size), int(b.y / tile_size))
		if cell_a.x == cell_b.x:
			for y in range(min(cell_a.y, cell_b.y), max(cell_a.y, cell_b.y) + 1):
				corridor_cells.append(Vector2i(cell_a.x, y))
		elif cell_a.y == cell_b.y:
			for x in range(min(cell_a.x, cell_b.x), max(cell_a.x, cell_b.x) + 1):
				corridor_cells.append(Vector2i(x, cell_a.y))
		else:
			var corner = Vector2i(cell_b.x, cell_a.y)
			for x in range(min(cell_a.x, corner.x), max(cell_a.x, corner.x) + 1):
				corridor_cells.append(Vector2i(x, cell_a.y))
			for y in range(min(corner.y, cell_b.y), max(corner.y, cell_b.y) + 1):
				corridor_cells.append(Vector2i(corner.x, y))
		
	print(data)

	tilemap.set_cells_terrain_connect(0, corridor_cells, 1, 0, false)

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
