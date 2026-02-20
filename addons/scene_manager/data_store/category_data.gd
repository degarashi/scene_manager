@tool
class_name SMgrCategoryData
extends Resource

@export var name: String:
	set(value):
		if name != value:
			name = value
			emit_changed()

@export var layer_priority: int = 1:
	set(value):
		if layer_priority != value:
			layer_priority = value
			emit_changed()


func _init(p_name: String = "") -> void:
	name = p_name
