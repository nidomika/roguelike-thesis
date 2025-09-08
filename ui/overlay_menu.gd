extends Control

signal start_pressed
signal resume_pressed
signal restart_pressed
signal exit_pressed
signal menu_opened(kind: int)
signal menu_closed(kind: int)

enum Kind { START, PAUSE, GAME_OVER, VICTORY }
var _kind := Kind.START

@onready var title = $Panel/VBoxContainer/Label
@onready var desc = $Panel/VBoxContainer/Label2
@onready var b1 = $Panel/VBoxContainer/HBoxContainer/Button
@onready var b2 = $Panel/VBoxContainer/HBoxContainer/Button2

func _ready() -> void:
	if not b1.pressed.is_connected(_on_primary):
		b1.pressed.connect(_on_primary)
	if not b2.pressed.is_connected(_on_secondary):
		b2.pressed.connect(_on_secondary)


func show_menu(kind: Kind) -> void:
	_kind = kind
	visible = true
	get_tree().paused = true
	match kind:
		Kind.START:
			title.text = "roguelike"
			desc.text  = "are you ready?"
			_config("start", "exit")
		Kind.PAUSE:
			title.text = "paused"
			desc.text  = "take a break"
			_config("resume", "exit")
		Kind.GAME_OVER:
			title.text = "you died"
			desc.text  = "oh no..."
			_config("restart", "exit")
		Kind.VICTORY:
			title.text = "you win!"
			desc.text  = "congratulations!"
			_config("restart", "exit")
	emit_signal("menu_opened", _kind)


func hide_menu() -> void:
	visible = false
	get_tree().paused = false
	emit_signal("menu_closed", _kind)


func _config(t1:String, t2:String) -> void:
	b1.text = t1
	b2.text = t2


func _on_primary() -> void:
	match _kind:
		Kind.START:   emit_signal("start_pressed")
		Kind.PAUSE:   emit_signal("resume_pressed")
		Kind.GAME_OVER: emit_signal("restart_pressed")
		Kind.VICTORY: emit_signal("restart_pressed")


func _on_secondary() -> void:
	emit_signal("exit_pressed")
