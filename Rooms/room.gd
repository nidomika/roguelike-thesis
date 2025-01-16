extends Node2D

var tile_size: int = 16

var room_position: Vector2i
var room_size: Vector2i
var enemies_alive: int
var center: Vector2i
var type: String

@onready var tilemap = get_parent().get_parent().get_node("NavigationRegion2D/TileMap")

const SPAWN_EXPLOSION_SCENE: PackedScene = preload("res://entities/enemies/spawn_explosion.tscn")
const ENEMY_SCENES: Dictionary = {
	"BAT": preload("res://characters/Enemies/Bat/bat.tscn"),
	"GOBLIN": preload("res://characters/Enemies/Goblin/goblin.tscn")
}

func _ready() -> void:
	if enemies_alive > 0 and type == "normal":
		_create_player_detector()


func init_room(pos: Vector2i, size: Vector2i, enemies: int) -> void:
	room_position = pos
	room_size = size
	enemies_alive = enemies
	center = room_position + room_size / 2

	self.global_position = center * tile_size


func _create_player_detector() -> void:
	var detector_scene = preload("res://rooms/player_detector.tscn")
	var detector = detector_scene.instantiate()
	detector.connect("player_entered", Callable(self, "_on_player_entered"))
	detector.room_size = room_size
	add_child(detector)


func _on_player_entered() -> void:
	close_doors()
	spawn_enemies(enemies_alive)


func spawn_enemies(count: int) -> void:
	enemies_alive = count
	for i in range(count):
		var key = "BAT"
		if randi() % 2 == 0:
			key = "GOBLIN"
		
		var enemy_scene = ENEMY_SCENES[key]
		var enemy = enemy_scene.instantiate()
		enemy.connect("tree_exited", Callable(self, "_on_enemy_died"))

		var rand_x = randi_range(int(-(room_size.x - 2) / 2.0), int((room_size.x - 2) / 2.0)) 
		var rand_y = randi_range(int(-(room_size.y - 2) / 2.0), int((room_size.y - 2) / 2.0))
		enemy.position = Vector2i(rand_x * tile_size, rand_y * tile_size)

		var explosion = SPAWN_EXPLOSION_SCENE.instantiate()
		explosion.position = enemy.position

		get_node("Enemies").call_deferred("add_child", enemy)
		get_node("Enemies").call_deferred("add_child", explosion)


func _on_enemy_died():
	enemies_alive -= 1
	if enemies_alive == 0:
		open_doors()


func close_doors():
	print("zamykamy drzwi")
	pass


func open_doors():
	print("otwieramy drzwi")
	pass
