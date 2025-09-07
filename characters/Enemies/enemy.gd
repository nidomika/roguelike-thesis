extends Character
class_name Enemy

var path: PackedVector2Array

@onready var navigation_agent: NavigationAgent2D = get_node("NavigationAgent2D")
@onready var path_timer: Timer = get_node("PathTimer")
var player: CharacterBody2D = null

func _ready() -> void:
	var __ = connect("tree_exited", Callable(get_parent(), "_on_enemy_killed"))
	var root_scene = get_tree().get_current_scene()
	if root_scene != null:
		if root_scene.has_node("Player"):
			player = root_scene.get_node("Player")

func chase() -> void:
	if not navigation_agent.is_target_reached():
		var vector_to_next_point: Vector2 = navigation_agent.get_next_path_position() - global_position
		mov_direction = vector_to_next_point
		
		if vector_to_next_point.x > 0 and animated_sprite.flip_h:
			animated_sprite.flip_h = false
		
		if vector_to_next_point.x < 0 and not animated_sprite.flip_h:
			animated_sprite.flip_h = true


func _on_path_timer_timeout() -> void:
	if is_instance_valid(player):
		_get_path_to_player()
	else:
		path_timer.stop()
		mov_direction = Vector2.ZERO


func _get_path_to_player() -> void:
	navigation_agent.target_position = player.position
