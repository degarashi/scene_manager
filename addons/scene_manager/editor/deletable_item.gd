@tool
extends HBoxContainer

## Reference to the manager root node
var _root: Node = null

## Internal node references
@onready var _address_label: LineEdit = %address


func _ready() -> void:
	_root = _find_manager_root()


## Safely traverse parents to find the root manager node using match
func _find_manager_root() -> Node:
	var current: Node = get_parent()
	while current != null:
		match current.name:
			"Scene Manager", "menu":
				return current
		current = current.get_parent()
	return null


## Set address and update node name
func set_address(addr: String) -> void:
	get_node("%address").text = addr
	name = addr


## Return the current address text
func get_address() -> String:
	return _address_label.text


## Notify the root manager to handle deletion via signal
func _on_remove_button_up() -> void:
	const SIG_NAME = "include_child_deleted"
	if _root and _root.has_signal(SIG_NAME):
		_root.emit_signal(SIG_NAME, self, get_address())
	else:
		# Fallback if root is not found
		queue_free()
