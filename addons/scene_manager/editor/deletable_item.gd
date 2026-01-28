@tool
class_name SMgrDeletableItem
extends HBoxContainer

signal on_remove_request(node: Node, addr: String)
const F = preload("uid://cpxe18s2130m8")


## Set address and update node name
func set_address(addr: String) -> void:
	%address.text = addr
	name = addr


## Return the current address text
func get_address() -> String:
	return %address.text


## Notify the root manager to handle deletion via signal
func _on_remove_button_up() -> void:
	on_remove_request.emit(self, get_address())
