@tool
class_name SMgrRemovableItem
extends HBoxContainer

signal on_remove(node: SMgrRemovableItem)


func set_item_string(text: String) -> void:
	%entry_lineedit.text = text
	name = text


func get_item_string() -> String:
	return %entry_lineedit.text


func _on_remove_button_up() -> void:
	on_remove.emit(self)
