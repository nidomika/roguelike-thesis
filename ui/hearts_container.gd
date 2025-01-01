extends HBoxContainer

@export var full_heart_texture: Texture2D
@export var half_heart_texture: Texture2D
@export var empty_heart_texture: Texture2D

@export var max_hp: int = 6
var current_hp: int = max_hp

func _ready():
	update_hearts()

func set_hp(hp: int) -> void:
	current_hp = clamp(hp, 0, max_hp)
	update_hearts()

func update_hearts() -> void:
	for i in range(get_child_count()):
		var heart = get_child(i) as TextureRect
		var heart_hp = current_hp - i * 2

		if heart_hp >= 2:
			heart.texture = full_heart_texture
		elif heart_hp == 1:
			heart.texture = half_heart_texture
		else:
			heart.texture = empty_heart_texture


func _on_player_hp_changed(new_hp: int) -> void:
	set_hp(new_hp)
