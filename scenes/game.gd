extends Node2D

var root_node: Branch
var tile_size: int = 16
var world_size = Vector2i(60, 30)

var tilemap: TileMap
var paths: Array = []

func _ready():
	tilemap = get_node("Rooms/Room2/NavigationRegion2D/TileMap2")
	
	root_node = Branch.new(Vector2i(0, 0), world_size)
	root_node.split(2, paths)
	var path = root_node.generate_path()
	root_node.assign_room_types(path)
	for room in path:
		print("Room type: ", room.type, " at position: ", room.get_center())
	queue_redraw()
	pass

func _draw():
	var rng = RandomNumberGenerator.new()
	for leaf in root_node.get_leaves():
		var padding = Vector4i(
			rng.randi_range(2,3),
			rng.randi_range(2,3),
			rng.randi_range(2,3),
			rng.randi_range(2,3)
		)
		
		for x in range(leaf.size.x):
			for y in range(leaf.size.y):
				if not is_inside_padding(x,y, leaf, padding):
					tilemap.set_cells_terrain_connect(0, [Vector2i(x + leaf.position.x,y + leaf.position.y)], 1, 0, false)
					
		for path in paths:
			if path['left'].y == path['right'].y:
				# horizontal
				for i in range(path['right'].x - path['left'].x):
					for offset in range(-1, 3):
						tilemap.set_cells_terrain_connect(0, [Vector2i(path['left'].x + i, path['left'].y + offset)], 1, 0, false)
			else:
				# vertical
				for i in range(path['right'].y - path['left'].y):
					for offset in range(-1, 3):
						tilemap.set_cells_terrain_connect(0, [Vector2i(path['left'].x + offset, path['left'].y + i)], 1, 0, false)
						
	# Iterujemy po wszystkich kafelkach TileMap
	for x in range(world_size.x):
		for y in range(world_size.y):
			var cell_id = tilemap.get_cell_source_id(0, Vector2i(x, y))
			var cell_atlas_coords = tilemap.get_cell_atlas_coords(0, Vector2i(x,y))
			
			# Sprawdzamy, czy kafelek ma ID pseudopodłogi (np. 1)
			if cell_id == 1 and cell_atlas_coords == Vector2i(2,1):  # Zamień 1 na ID pseudopodłogi w Twoim TileSet
				# Podmieniamy pseudopodłogę na docelowy terrain (np. 0)
				tilemap.set_cells_terrain_connect(0, [Vector2i(x, y)], 0, 1)
	pass


func is_inside_padding(x, y, leaf, padding):
	return x <= padding.x or y <= padding.y or x >= leaf.size.x - padding.z or y >= leaf.size.y - padding.w
