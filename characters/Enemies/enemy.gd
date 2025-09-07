extends Character
class_name Enemy

var path: PackedVector2Array

@onready var navigation_agent: NavigationAgent2D = get_node("NavigationAgent2D")
var player: CharacterBody2D = null
@onready var path_timer: Timer = get_node("PathTimer")

func _ready() -> void:
	# Try to find the Player node at runtime; during scene switches the current
	# scene may not yet be the map, so avoid using get_tree().current_scene inside
	# onready initializers.
	# Some Godot versions don't provide has_current_scene(); use get_current_scene()
	var root_scene = get_tree().get_current_scene()
	if root_scene != null:
		if root_scene.has_node("Player"):
			player = root_scene.get_node("Player")
	# as a fallback, search from the root
	if player == null:
		if get_tree().get_root().has_node("Game/Player"):
			player = get_tree().get_root().get_node("Game/Player")

func chase() -> void:
	if not navigation_agent.is_target_reached():
		var vector_to_next_point: Vector2 = navigation_agent.get_next_path_position() - global_position
		mov_direction = vector_to_next_point
		
		if vector_to_next_point.x > 0 and animated_sprite.flip_h:
			animated_sprite.flip_h = false
		
		if vector_to_next_point.x < 0 and not animated_sprite.flip_h:
			animated_sprite.flip_h = true
			


func _on_path_timer_timeout() -> void:
	if player != null and is_instance_valid(player):
		_get_path_to_player()
	else:
		path_timer.stop()
		mov_direction = Vector2.ZERO
		

func _get_path_to_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	navigation_agent.target_position = player.position
