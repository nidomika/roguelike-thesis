extends Node

class_name Branch

class Vector2iDistanceComparer:
	static func _new():
		return Vector2iDistanceComparer
	
	static func compare(a, b):
		var dist_a = a.position.distance_to(Vector2.ZERO)
		var dist_b = b.position.distance_to(Vector2.ZERO)
		return int(dist_a - dist_b)

var left_child: Branch
var right_child: Branch
var position: Vector2i
var size: Vector2i

var type: String = ""

func _init(starting_position, starting_size):
	self.position = starting_position
	self.size = starting_size

func split(remaining, paths):
	var rng = RandomNumberGenerator.new()
	var split_percent = rng.randf_range(0.3, 0.7)
	var split_horizontal = size.y >= size.x

	if (split_horizontal):
		# horizontal
		var left_height = int(size.y * split_percent)
		left_child = Branch.new(position, Vector2i(size.x, left_height))
		right_child = Branch.new(
			Vector2i(position.x, position.y + left_height),
			Vector2i(size.x, size.y - left_height)
		)
	else:
		# vertical
		var left_width = int(size.x * split_percent)
		left_child = Branch.new(position, Vector2i(left_width, size.y))
		right_child = Branch.new(
			Vector2i(position.x + left_width, position.y),
			Vector2i(size.x - left_width, size.y)
		)
		
	paths.push_back({'left': left_child.get_center(), 'right': right_child.get_center()})
	
	if (remaining > 0):
		left_child.split(remaining - 1, paths)
		right_child.split(remaining - 1, paths)
	pass
	
func get_leaves():
	if not (left_child && right_child):
		return [self]
	else:
		return left_child.get_leaves() + right_child.get_leaves()
		
func get_center():
	return Vector2i(position.x + int(size.x / 2.0), position.y + int(size.y / 2.0))

func generate_path():
	var leaves = get_leaves()
	leaves.sort_custom(func(a, b): return a.get_center().distance_to(Vector2i.ZERO) < b.get_center().distance_to(Vector2i.ZERO))

	return leaves

# Nowa funkcja: Przypisanie typów pokojów
func assign_room_types(path):
	path[0].type = "start" # Pierwszy pokój
	path[-1].type = "boss" # Ostatni pokój
	for i in range(1, path.size() - 1):
		path[i].type = "intermediate" # Pokoje pośrednie
