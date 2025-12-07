extends FiniteStateMachine

@export var attack_range: float = 10.0
@export var attack_cooldown: float = 1.5

var attack_timer: float = 1.5

func _init() -> void:
	_add_state("chase")
	_add_state("attack")
	_add_state("hurt")
	_add_state("dead")
	
func _ready() -> void:
	set_state(states.chase)

func _state_logic(delta: float) -> void:
	if state == states.chase:
		if parent.player and parent.global_position.distance_to(parent.player.global_position) >= attack_range:
			parent.chase()
			parent.move()
		else:
			parent.mov_direction = Vector2.ZERO
	elif state == states.attack:
		parent.mov_direction = Vector2.ZERO
		attack_timer -= delta
		
func _get_transition() -> int:
	match state:
		states.chase:
			if parent.player and parent.global_position.distance_to(parent.player.global_position) < attack_range:
				return states.attack
		states.attack:
			if attack_timer <= 0:
				return states.chase
		states.hurt:
			if not animation_player.is_playing():
				return states.chase
	return -1

func _enter_state(_previous_state: int, new_state: int) -> void:
	match new_state:
		states.chase:
			animation_player.play("fly")
		states.attack:
			animation_player.play("fly")
			attack_timer = attack_cooldown
		states.hurt:
			animation_player.play("hurt")
		states.dead:
			animation_player.play("dead")
