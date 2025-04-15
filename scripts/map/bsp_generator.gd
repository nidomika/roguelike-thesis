extends Node
class_name BSPGenerator

var min_width = 25
var min_height = 20
var max_depth = 4

class Partition:
	var rect: Rect2
	var left: Partition = null
	var right: Partition = null

	func _init(r: Rect2):
		rect = r

func generate(rect: Rect2, depth: int = 0) -> Array:
	var root = Partition.new(rect)
	_split(root, depth)
	var leaves = []
	_get_leaves(root, leaves)
	return leaves

func _split(node: Partition, depth: int):
	if depth >= max_depth or node.rect.size.x < min_width * 2 or node.rect.size.y < min_height * 2:
		return

	var split_horizontally = randf() < 0.5
	if node.rect.size.x > node.rect.size.y:
		split_horizontally = false
	elif node.rect.size.y > node.rect.size.x:
		split_horizontally = true

	var rect1: Rect2
	var rect2: Rect2

	if split_horizontally:
		var min_split = min_height
		var max_split = int(node.rect.size.y) - min_height

		var lower_bound = float(min_split) / node.rect.size.y
		var upper_bound = float(max_split) / node.rect.size.y
		var split_factor = randf_range(0.4, 0.6)

		split_factor = clamp(split_factor, lower_bound, upper_bound)
		var split = int(node.rect.size.y * split_factor)
		rect1 = Rect2(node.rect.position, Vector2(node.rect.size.x, split))
		rect2 = Rect2(node.rect.position + Vector2(0, split), Vector2(node.rect.size.x, node.rect.size.y - split))
	else:
		var min_split = min_width
		var max_split = int(node.rect.size.x) - min_width
		
		var lower_bound = float(min_split) / node.rect.size.x
		var upper_bound = float(max_split) / node.rect.size.x
		var split_factor = randf_range(0.4, 0.6)
		
		split_factor = clamp(split_factor, lower_bound, upper_bound)
		var split = int(node.rect.size.x * split_factor)
		rect1 = Rect2(node.rect.position, Vector2(split, node.rect.size.y))
		rect2 = Rect2(node.rect.position + Vector2(split, 0), Vector2(node.rect.size.x - split, node.rect.size.y))

	node.left = Partition.new(rect1)
	node.right = Partition.new(rect2)
	
	_split(node.left, depth + 1)
	_split(node.right, depth + 1)

func _get_leaves(node: Partition, leaves: Array):
	if node.left == null and node.right == null:
		leaves.append(node.rect)
	else:
		if node.left:
			_get_leaves(node.left, leaves)
		if node.right:
			_get_leaves(node.right, leaves)
