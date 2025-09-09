extends Node2D

@onready var world := $World
@onready var player: Character = get_node("Player")
@onready var menu := $UI/OverlayMenu


func _ready():
	connect_menu()

	var map_scene = preload("res://map/map.tscn").instantiate()
	map_scene.connect("map_ready", Callable(self, "_on_map_ready"))
	map_scene.connect("boss_triggered", Callable(self, "_on_boss_triggered"))
	world.add_child(map_scene)
	
	player.connect("died", Callable(self, "_on_player_died"))


func _process(_delta) -> void:
	if Input.is_action_pressed("ui_cancel"):
		_toggle_pause()


func connect_menu():
	menu.start_pressed.connect(_on_start)
	menu.resume_pressed.connect(_on_resume)
	menu.restart_pressed.connect(_on_restart)
	menu.exit_pressed.connect(_on_exit)
	
	menu.menu_opened.connect(_on_menu_opened)
	menu.menu_closed.connect(_on_menu_closed)
	
	menu.show_menu(menu.Kind.START)


func _on_map_ready(start_pos: Vector2) -> void:
	player.global_position = start_pos


func _on_boss_triggered(triggering_player: Node) -> void:
	var boss_scene = preload("res://map/rooms/boss_room/boss_room.tscn")
	var boss_room = boss_scene.instantiate()
	boss_room.connect("killed_all", Callable(self, "_on_killed_all"))

	
	if not is_instance_valid(boss_room):
		return

	var existing_map = world.get_node("Map")
	existing_map.queue_free()

	world.call_deferred("add_child", boss_room)
	
	var spawn_pos = triggering_player.global_position
	boss_room.global_position = spawn_pos 
	triggering_player.global_position = boss_room.get_node("PlayerStart").global_position
	player.get_node("Camera2D").set_zoom(Vector2(4, 4))
	

func _toggle_pause() -> void:
	if get_tree().paused:
		menu.hide_menu()
	else:
		menu.show_menu(menu.Kind.PAUSE)


func _on_player_died() -> void:
	menu.show_menu(menu.Kind.GAME_OVER)


func _on_start() -> void:
	menu.hide_menu()


func _on_resume() -> void:
	menu.hide_menu()


func _on_restart() -> void:
	get_tree().change_scene_to_file("res://game.tscn")


func _on_exit() -> void:
	get_tree().quit()

func _on_killed_all() -> void:
	menu.show_menu(menu.Kind.VICTORY)


func _set_gameplay_frozen(frozen: bool) -> void:
	if frozen:
		world.process_mode  = Node.PROCESS_MODE_DISABLED
		player.process_mode = Node.PROCESS_MODE_DISABLED

	else:
		world.process_mode  = Node.PROCESS_MODE_INHERIT
		player.process_mode = Node.PROCESS_MODE_INHERIT


func _on_menu_opened(_kind: int) -> void:
	_set_gameplay_frozen(true)


func _on_menu_closed(_kind: int) -> void:
	_set_gameplay_frozen(false)
