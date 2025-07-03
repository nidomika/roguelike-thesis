extends Area2D

@export var tex_closed: Texture = load("res://assets/sgq/SGQ_Dungeon/doors/door_closed.png")
@export var tex_open: Texture = load("res://assets/sgq/SGQ_Dungeon/doors/door_open.png")
@export var normal: Vector2 = Vector2.RIGHT
@onready var sprite: Sprite2D = $Sprite2D

var is_open := false

func _ready():
	sprite.texture = tex_closed
	sprite.rotation = normal.angle()
	$CollisionShape2D.disabled = false

func open():
	if not is_open:
		is_open = true
		sprite.texture = tex_open
		$CollisionShape2D.disabled = true

func close():
	if is_open:
		is_open = false
		sprite.texture = tex_closed
		$CollisionShape2D.disabled = false
