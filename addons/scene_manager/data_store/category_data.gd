class_name SMgrCategoryData
extends Resource

@export var name: String
@export var layer_priority: int = 1


func _init(p_name: String = "") -> void:
	name = p_name
