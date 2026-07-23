@tool
class_name SMgrCategoryData
extends DebouncedResource

# ------------- [Exports] -------------

@export var name: String:
	set(value):
		if name != value:
			name = value
			emit_changed()

@export var layer_name: String:
	set(value):
		if layer_name != value:
			layer_name = value
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

@export var follow_viewport: bool = false:
	set(value):
		if follow_viewport != value:
			follow_viewport = value
			emit_changed()


# ------------- [Public Method] -------------

func _init(p_name: String = "") -> void:
	# Initialize the debouncer inherited from DebouncedResource
	_init_debouncer(DEFAULT_DEBOUNCE_TIME)

	# The property name's setter triggers emit_changed(),
	# which in turn triggers the debouncer.
	name = p_name
