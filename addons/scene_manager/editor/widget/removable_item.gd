@tool
class_name SMgrRemovableItem
extends HBoxContainer

# ------------- [Signal] -------------
signal on_remove(opt_val: Variant)
signal on_category_changed(path: String, category_id: int)

# ------------- [Private Variable] -------------
var _opt_val: Variant
var _category_id: int = ResourceUID.INVALID_ID


func prepare(text: String, opt_val: Variant) -> void:
	_opt_val = opt_val
	set_item_string(text)


func set_item_string(text: String) -> void:
	%entry_lineedit.text = text
	name = text
	_validate_path(text)


func _validate_path(path: String) -> void:
	var is_valid := SMgrUtil.is_valid_resource_path(path)
	if is_valid:
		%entry_lineedit.remove_theme_color_override("font_color")
	else:
		%entry_lineedit.add_theme_color_override("font_color", Color.RED)


func get_item_string() -> String:
	return %entry_lineedit.text


func set_count(count: int) -> void:
	%count_label.text = "(%d)" % count


## Sets up the category dropdown with available categories
## @param categories Array of category data to populate the dropdown
## @param current_category_id The currently assigned category ID (ResourceUID.INVALID_ID for none)
func setup_category_dropdown(categories: Array[SMgrCategoryData], current_category_id: int) -> void:
	_category_id = current_category_id
	%category_option.clear()
	%category_option.add_item("None", ResourceUID.INVALID_ID)

	for cat in categories:
		%category_option.add_item(cat.name, cat.name.hash())

	# Select the current category
	if current_category_id != ResourceUID.INVALID_ID:
		for i in %category_option.item_count:
			if %category_option.get_item_id(i) == current_category_id:
				%category_option.select(i)
				break
	else:
		%category_option.select(0)


func get_selected_category_id() -> int:
	return _category_id


# ------------- [Callbacks] -------------
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


func _on_category_option_selected(index: int) -> void:
	var new_category_id: int = %category_option.get_item_id(index)
	if new_category_id != _category_id:
		_category_id = new_category_id
		on_category_changed.emit(get_item_string(), _category_id)
