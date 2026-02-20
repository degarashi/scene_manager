@tool
class_name SMgrRemovableItem
extends HBoxContainer

signal on_remove(opt_val: Variant)

var _opt_val: Variant


func prepare(text: String, opt_val: Variant) -> void:
	_opt_val = opt_val
	set_item_string(text)


func set_item_string(text: String) -> void:
	%entry_lineedit.text = text
	name = text


func get_item_string() -> String:
	return %entry_lineedit.text


func _on_remove_button_up() -> void:
	on_remove.emit(_opt_val)
