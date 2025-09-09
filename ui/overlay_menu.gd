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
@onready var button = $Panel/VBoxContainer/HBoxContainer/Button

func _ready() -> void:
	if not button.pressed.is_connected(_on_primary):
		button.pressed.connect(_on_primary)


func show_menu(kind: Kind) -> void:
	_kind = kind
	visible = true
	match kind:
		Kind.START:
			title.text = "roguelike"
			desc.text  = "are you ready?"
			button.text = "start"

		Kind.PAUSE:
			title.text = "paused"
			desc.text  = "take a break"
			button.text = "resume"
		Kind.GAME_OVER:
			title.text = "you died"
			desc.text  = "oh no..."
			button.text = "restart"
		Kind.VICTORY:
			title.text = "you win!"
			desc.text  = "congratulations!"
			button.text = "restart"
	emit_signal("menu_opened", _kind)


func hide_menu() -> void:
	visible = false
	get_tree().paused = false
	emit_signal("menu_closed", _kind)


func _on_primary() -> void:
	match _kind:
		Kind.START:   emit_signal("start_pressed")
		Kind.PAUSE:   emit_signal("resume_pressed")
		Kind.GAME_OVER: emit_signal("restart_pressed")
		Kind.VICTORY: emit_signal("restart_pressed")
