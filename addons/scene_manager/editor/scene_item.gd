@tool
class_name SMgrSceneItem
extends HBoxContainer

signal key_changed(key: String)
signal key_reset

const CATEGORY_ID = 0
const DUPLICATE_LINE_EDIT: StyleBox = preload(
	"res://addons/scene_manager/themes/line_edit_duplicate.tres"
)
const INVALID_SCENE_NAME: String = "none"
const EBUS = preload("uid://ra25t5in8erp")

## Returns whether or not the key in the scene item is valid
var is_valid: bool:
	set(valid):
		is_valid = valid
		if is_inside_tree():
			if valid:
				remove_custom_theme()
			else:
				_custom_set_theme(DUPLICATE_LINE_EDIT)

var _sub_section: Control
var _list: Control
var _mouse_is_over_value: bool

## Used when comparing the user typed key to detect changes
var _previous_key: String

# Nodes
@onready var _popup_menu: PopupMenu = %popup_menu
@onready var _key_edit: LineEdit = %key
@onready var _key: String = %key.text


func _ready() -> void:
	_previous_key = _key


## Directly set the key. Called by other UI elements
##   when updating as this bypases the text normalization.
func set_key(text: String) -> void:
	_previous_key = text
	_key = text
	get_key_node().text = text


## Sets value of `value`
func set_value(text: String) -> void:
	%value.text = text


## Return `key` string value
func get_key() -> String:
	return get_key_node().text


## Return `value` string value
func get_value() -> String:
	return %value.text


## Returns `key` node
func get_key_node() -> LineEdit:
	return %key


## Sets subsection for current item
func set_subsection(node: Control) -> void:
	_sub_section = node


## Sets passed theme to normal theme of `key` LineEdit
func _custom_set_theme(theme: StyleBox) -> void:
	get_key_node().add_theme_stylebox_override("normal", theme)


## Removes added custom theme for `key` LineEdit
func remove_custom_theme() -> void:
	get_key_node().remove_theme_stylebox_override("normal")


# Popup Button
func _on_popup_button_button_up() -> void:
	var i: int = 0
	var sections: Array
	EBUS.get_section_names.emit(sections)
	_popup_menu.clear()
	_popup_menu.add_separator("Categories")
	i += 1

	# Categories have id of CATEGORY_ID
	for section in sections:
		if section == "All":
			continue
		_popup_menu.add_check_item(section)
		_popup_menu.set_item_id(i, CATEGORY_ID)

		var sect: Array
		EBUS.get_sections.emit(sect, get_value())
		_popup_menu.set_item_checked(i, section in sect)
		i += 1

	# Recalculate size since menu content changed
	_popup_menu.reset_size()

	# Get mouse screen coordinates (global coordinates)
	# Get window position via get_screen_transform().origin and add local mouse position
	var popup_pos := get_screen_transform().origin + get_local_mouse_position()

	_popup_menu.set_position(popup_pos)
	_popup_menu.popup()


# Happens when open scene button clicks
func _on_open_scene_button_up() -> void:
	# Open it
	EditorInterface.open_scene_from_path(get_value())
	# Show in FileSystem
	EditorInterface.select_file(get_value())


# Happens on input on the value element
func _on_value_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_released()
		and event.button_index == MOUSE_BUTTON_LEFT
		and _mouse_is_over_value
	):
		EditorInterface.select_file(get_value())


# Happens when mouse is over value input
func _on_value_mouse_entered() -> void:
	_mouse_is_over_value = true


# Happens when mouse is out of value input
func _on_value_mouse_exited() -> void:
	_mouse_is_over_value = false


# Happens when an item is selected
func _on_popup_menu_index_pressed(index: int) -> void:
	var id := _popup_menu.get_item_id(index)
	var checked := _popup_menu.is_item_checked(index)
	var text := _popup_menu.get_item_text(index)
	_popup_menu.set_item_checked(index, !checked)

	if id == CATEGORY_ID:
		if !checked:
			EBUS.add_scene_to_list.emit(text, get_key(), get_value(), false)
			EBUS.item_added_to_list.emit(self, text)
		else:
			EBUS.remove_scene_from_list.emit(text, get_key(), get_value())
			EBUS.item_removed_from_list.emit(self, text)


## Updates the key internal value and normalizes the UI text
func _update_key(text: String) -> void:
	# Normalize the key to be lower case without symbols and replacing spaces with underscores
	text = SceneManagerUtils.sanitize_scene_name(text)
	get_key_node().text = text
	name = text
	_key = text


# Triggered when LineEdit text changes
func _on_key_text_changed(new_text: String) -> void:
	# Store current text and notify manager for real-time validation (e.g., duplicate check)
	_key = new_text
	key_changed.emit(new_text)


func _on_key_text_submitted(_new_text: String) -> void:
	_submit_key()


## Finalizes the key change and notifies the root manager
func _submit_key() -> void:
	# Sanitize key only on submission to avoid cursor jumping issues
	var sanitized_name := SceneManagerUtils.sanitize_scene_name(get_key())

	# Basic validation
	var valid_name := not sanitized_name.is_empty() and sanitized_name != INVALID_SCENE_NAME

	if _previous_key != sanitized_name:
		if is_valid and valid_name:
			# Successfully renamed
			_update_key(sanitized_name)
			EBUS.scene_renamed.emit(_previous_key, _key)
			_previous_key = _key
		else:
			# Revert to previous valid key if invalid or duplicate
			set_key(_previous_key)
			is_valid = true
			key_reset.emit()
