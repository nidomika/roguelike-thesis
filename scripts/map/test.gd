extends Node2D

var leaves = []
var rooms = []
var corridor_node

func _ready():
	scale = Vector2(0.5, 0.5)
	var map_rect = Rect2(0, 0, 500, 350)
	
	leaves = BSPGenerator.new().generate(map_rect)
	print("Wygenerowane regiony:", leaves)
	
	for leaf in leaves:
		var room = Room.new(leaf, 6)
		rooms.append(room)
	
	var connections = MSTConnector.new().build(rooms)
	corridor_node = Corridor.new()
	add_child(corridor_node)
	corridor_node.set_corridors(connections)
	
	queue_redraw()

func _draw():
	for r in leaves:
		draw_rect(r, Color(1, 1, 1), false, 2)
	for room in rooms:
		draw_rect(room.room_rect, Color(0, 1, 0), false, 2)
