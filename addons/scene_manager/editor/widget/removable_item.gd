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
	_validate_path(text)


func _validate_path(path: String) -> void:
	var is_valid := (
		DirAccess.dir_exists_absolute(path)
		or (FileAccess.file_exists(path) and path.begins_with("res://"))
	)
	if is_valid:
		%entry_lineedit.remove_theme_color_override("font_color")
	else:
		%entry_lineedit.add_theme_color_override("font_color", Color.RED)


func get_item_string() -> String:
	return %entry_lineedit.text


func set_count(count: int) -> void:
	%count_label.text = "(%d)" % count


func _on_remove_button_up() -> void:
	on_remove.emit(_opt_val)


func _on_jump_button_up() -> void:
	_jump_to_path()


func _jump_to_path() -> void:
	var path := get_item_string()
	if path == "":
		return

	if Engine.is_editor_hint():
		EditorInterface.get_file_system_dock().navigate_to_path(path)
