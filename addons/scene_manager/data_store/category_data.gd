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

@export var pauses_lower_priority_layers: bool = false:
	set(value):
		if pauses_lower_priority_layers != value:
			pauses_lower_priority_layers = value
			emit_changed()

@export var always_process: bool = false:
	set(value):
		if always_process != value:
			always_process = value
			emit_changed()


func _init(p_name: String = "") -> void:
	name = p_name
