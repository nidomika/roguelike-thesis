extends Node
class_name BSPGenerator

var min_width = 16
var min_height = 20
var max_depth = 4

@export var tile_size: int = 16

@export var split_min_factor: float = 0.3
@export var split_max_factor: float = 0.7

class BSPNode:
	var rect: Rect2
	var left: BSPNode = null
	var right: BSPNode = null
	var is_vertical_split: bool = false
	var parent: BSPNode = null
	var sibling: BSPNode = null
	var has_room: bool = false

	func _init(r: Rect2):
		rect = r

	func get_leaves() -> Array:
		var leaves := []
		if left == null and right == null:
			leaves.append(self)
		else:
			if left:
				leaves += left.get_leaves()
			if right:
				leaves += right.get_leaves()
		return leaves

func generate_tree(rect: Rect2, depth: int = 0) -> BSPNode:
	var root = BSPNode.new(rect)
	root.parent = null
	root.sibling = null
	_split(root, depth)
	return root

func _split(node: BSPNode, depth: int):
	if depth >= max_depth or node.rect.size.x < min_width * 2 or node.rect.size.y < min_height * 2:
		return

	var split_horizontally = randf() < 0.5
	if node.rect.size.x > node.rect.size.y:
		split_horizontally = false
	elif node.rect.size.y > node.rect.size.x:
		split_horizontally = true

	node.is_vertical_split = not split_horizontally

	var rect1: Rect2
	var rect2: Rect2

	if split_horizontally:
		var min_split = min_height
		var max_split = int(node.rect.size.y) - min_height

		var lower_bound = float(min_split) / node.rect.size.y
		var upper_bound = float(max_split) / node.rect.size.y
		var split_factor = randf_range(split_min_factor, split_max_factor)

		split_factor = clamp(split_factor, lower_bound, upper_bound)
		var split = int(node.rect.size.y * split_factor)
		split = floor(split / float(tile_size)) * tile_size
		rect1 = Rect2(node.rect.position, Vector2(node.rect.size.x, split))
		rect2 = Rect2(node.rect.position + Vector2(0, split), Vector2(node.rect.size.x, node.rect.size.y - split))
	else:
		var min_split = min_width
		var max_split = int(node.rect.size.x) - min_width
		
		var lower_bound = float(min_split) / node.rect.size.x
		var upper_bound = float(max_split) / node.rect.size.x
		var split_factor = randf_range(split_min_factor, split_max_factor)

		split_factor = clamp(split_factor, lower_bound, upper_bound)
		var split = int(node.rect.size.x * split_factor)
		split = floor(split / float(tile_size)) * tile_size
		rect1 = Rect2(node.rect.position, Vector2(split, node.rect.size.y))
		rect2 = Rect2(node.rect.position + Vector2(split, 0), Vector2(node.rect.size.x - split, node.rect.size.y))

	node.left = BSPNode.new(rect1)
	node.right = BSPNode.new(rect2)
	node.left.parent = node
	node.right.parent = node
	node.left.sibling = node.right
	node.right.sibling = node.left
	
	_split(node.left, depth + 1)
	_split(node.right, depth + 1)
