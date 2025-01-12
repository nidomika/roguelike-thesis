extends Area2D

var room_position: Vector2i
var room_size: Vector2i
var tile_size: int = 16
var center: Vector2i
var enemies_count: int

const SPAWN_EXPLOSION_SCENE: PackedScene = preload("res://entities/enemies/spawn_explosion.tscn")
const ENEMY_SCENES: Dictionary = {
	"BAT": preload("res://characters/Enemies/Bat/bat.tscn"),
	"GOBLIN": preload("res://characters/Enemies/Goblin/goblin.tscn")
}

var enemies_alive: int = 0

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	#connect("body_exited", Callable(self, "_on_body_exited"))
	
	var shape = $CollisionShape2D.shape as RectangleShape2D
	$CollisionShape2D.position = Vector2.ZERO
	shape.size = Vector2(room_size.x * tile_size, room_size.y * tile_size)
	global_position = center


func _on_body_entered(body: CharacterBody2D) -> void:
	if body.name == "Player":
		spawn_enemies(enemies_count)
		# zamykamy drzwi
		# usuwamy detektora
		queue_free()


#func _on_body_exited(body: CharacterBody2D) -> void:
	#if body.name == "Player":
		#print("%s opuścił obszar detektora" % body.name)

func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive <= 0:
		_open_doors()

func _open_doors():
	print("Wszyscy wrogowie zginęli, otwieram drzwi!")
	#to do

func spawn_enemies(count: int) -> void:
	enemies_alive = count
	for i in range(count):
		var key = "BAT"
		if randi() % 2 == 0:
			key = "GOBLIN"
		
		var enemy_scene = ENEMY_SCENES[key]
		var enemy = enemy_scene.instantiate()
		enemy.connect("tree_exited", Callable(self, "_on_enemy_died"))

		var rand_x = randi_range(0, room_size.x)
		var rand_y = randi_range(0, room_size.y)

		enemy.global_position = (room_position * tile_size + Vector2i(rand_x * tile_size, rand_y * tile_size))

		var explosion = SPAWN_EXPLOSION_SCENE.instantiate()
		explosion.global_position = enemy.global_position

		get_tree().current_scene.call_deferred("add_child", enemy)
		get_tree().current_scene.call_deferred("add_child", explosion)
