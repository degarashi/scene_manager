@tool
class_name SMgrDeletableItem
extends HBoxContainer

const F = preload("uid://cpxe18s2130m8")

## Reference to the manager root node
var _root: SMgrManager


func _ready() -> void:
	_root = F.find_manager_root(self)


## Set address and update node name
func set_address(addr: String) -> void:
	%address.text = addr
	name = addr


## Return the current address text
func get_address() -> String:
	return %address.text


## Notify the root manager to handle deletion via signal
func _on_remove_button_up() -> void:
	_root.include_child_deleted.emit(self, get_address())
