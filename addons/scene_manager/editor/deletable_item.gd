@tool
class_name SMgrDeletableItem
extends HBoxContainer

const F = preload("uid://cpxe18s2130m8")

## Reference to the manager root node
var _root: Node = null

## Internal node references
@onready var _address_label: LineEdit = %address


func _ready() -> void:
	_root = F.find_manager_root(self)


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
