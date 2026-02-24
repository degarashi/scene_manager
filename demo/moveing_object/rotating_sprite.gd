extends Node2D

## Degrees of rotation per second (negative values for counter-clockwise)
@export var rotation_speed: float = 90.0

@onready var view_sprite: Sprite2D = %ViewSprite


func _process(delta: float) -> void:
	var amount := deg_to_rad(rotation_speed) * delta
	view_sprite.rotation += amount
