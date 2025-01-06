extends Node2D

const SPAWN_EXPLOSION_SCENE: PackedScene = preload("res://entities/enemies/spawn_explosion.tscn")

const ENEMY_SCENES: Dictionary = {
	"BAT": preload("res://characters/Enemies/Bat/bat.tscn")
}

var num_enemies: int

@onready var tilemap: TileMap = get_node("NavigationRegion2D/TileMap")
@onready var door_container: Node2D = get_node("Doors")
@onready var entrance: Node2D = get_node("Entrance")
@onready var enemy_positions_container: Node2D = get_node("EnemyPositions")
@onready var player_detector: Area2D = get_node("PlayerDetector")

func _ready() -> void:
	num_enemies = enemy_positions_container.get_child_count()
	
func _on_enemy_killed() -> void:
	num_enemies -= 1
	if num_enemies == 0:
		_open_doors()
	
	
func _open_doors() -> void:
	for door in door_container.get_children():
		door.open()


func _close_entrance() -> void:
	for entry_position in entrance.get_children():
		tilemap.set_cell(1, tilemap.local_to_map(entry_position.position), 0, Vector2i(2,6))
		tilemap.set_cell(0, tilemap.local_to_map(entry_position.position) + Vector2i.DOWN, 0, Vector2i(3,3))


func _spawn_enemies() -> void:
	for enemy_position in enemy_positions_container.get_children():
		var enemy: CharacterBody2D = ENEMY_SCENES.BAT.instantiate()
		enemy.position = enemy_position.position
		var __ = enemy.connect("tree_exited",self._on_enemy_killed)
		call_deferred("add_child", enemy)

		var spawn_explosion: AnimatedSprite2D = SPAWN_EXPLOSION_SCENE.instantiate()
		spawn_explosion.position = enemy_position.position
		call_deferred("add_child", spawn_explosion)


func _on_player_detector_body_entered(_body: Node2D) -> void: # node or characterbody??
	player_detector.queue_free()
	_close_entrance()
	if num_enemies > 0:
		_spawn_enemies()
	else:
		_open_doors()
