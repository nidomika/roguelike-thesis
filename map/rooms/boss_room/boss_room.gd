extends Node2D

signal killed_all

var alive := 0

func _process(_delta) -> void:
	var any_left := false
	for c in get_children():
		if c.is_in_group("slime_enemy") or c.name == "SlimeBoss":
			any_left = true
			break
	if not any_left:
		killed_all.emit()
		set_process(false)
