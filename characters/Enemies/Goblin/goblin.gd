extends Enemy

const THROWABLE_SCENE: PackedScene = preload("res://characters/Enemies/Goblin/throwable.tscn")

const MAX_DISTANCE_TO_PLAYER: int = 120
const MIN_DISTANCE_TO_PLAYER: int = 60

@export var projectile_speed: int = 150
@onready var attack_timer: Timer = get_node("AttackTimer")
var can_attack: bool = true
var distance_to_player: float


func _on_path_timer_timeout() -> void:
	if is_instance_valid(player): 
		distance_to_player = (player.position - global_position).length()
		if distance_to_player > MAX_DISTANCE_TO_PLAYER:
			_get_path_to_player()
		elif distance_to_player < MIN_DISTANCE_TO_PLAYER:
			_get_path_to_move_away_from_player()
		else:
			if can_attack:
				can_attack = false
				_throw_throwable()
				attack_timer.start()


func _get_path_to_move_away_from_player() -> void:
	var dir: Vector2 = (global_position - player.position).normalized()
	navigation_agent.target_position = global_position + dir * 100


func _throw_throwable() -> void:
	var projectile: Area2D = THROWABLE_SCENE.instantiate()
	projectile.launch(global_position, (player.position - global_position).normalized(), projectile_speed)
	get_tree().current_scene.add_child(projectile)
	

func _on_attack_timer_timeout() -> void:
	can_attack = true
