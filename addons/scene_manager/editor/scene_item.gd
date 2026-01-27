@tool
extends HBoxContainer

signal key_changed(key: String)
signal key_reset

const F = preload("uid://cpxe18s2130m8")
const DUPLICATE_LINE_EDIT: StyleBox = preload(
	"res://addons/scene_manager/themes/line_edit_duplicate.tres"
)
const INVALID_KEY_NAME: String = "none"

## Returns whether or not the key in the scene item is valid
var is_valid: bool:
	get:
		return is_valid
	set(value):
		is_valid = value
		if value:
			remove_custom_theme()
		else:
			custom_set_theme(DUPLICATE_LINE_EDIT)

var _sub_section: Control
var _list: Control
var _mouse_is_over_value: bool

# Used when comparing the user typed key
var _previous_key: String

# Nodes
@onready var _root: Node = self
@onready var _popup_menu: PopupMenu = %popup_menu
@onready var _key_edit: LineEdit = %key
@onready var _key: String = %key.text


# Finds and fills `_root` variable properly
func _ready() -> void:
	_previous_key = _key
	_root = F.find_manager_root(self)


## Directly set the key. Called by other UI elements
##   when updating as this bypases the text normalization.
func set_key(text: String) -> void:
	_previous_key = text
	_key = text
	%key.text = text


## Sets value of `value`
func set_value(text: String) -> void:
	%value.text = text


## Return `key` string value
func get_key() -> String:
	return %key.text


## Return `value` string value
func get_value() -> String:
	return %value.text


## Returns `key` node
func get_key_node() -> Node:
	return %key


## Sets subsection for current item
func set_subsection(node: Control) -> void:
	_sub_section = node


## Sets passed theme to normal theme of `key` LineEdit
func custom_set_theme(theme: StyleBox) -> void:
	get_key_node().add_theme_stylebox_override("normal", theme)


## Removes added custom theme for `key` LineEdit
func remove_custom_theme() -> void:
	get_key_node().remove_theme_stylebox_override("normal")


# Popup Button
func _on_popup_button_button_up():
	var i: int = 0
	var sections: Array = _root.get_all_lists_names_except()
	_popup_menu.clear()
	_popup_menu.add_separator("Categories")
	i += 1

	# Categories have id of 0
	for section in sections:
		if section == "All":
			continue
		_popup_menu.add_check_item(section)
		_popup_menu.set_item_id(i, 0)
		_popup_menu.set_item_checked(i, section in _root.get_sections(get_value()))
		i += 1

	# Recalculate size since menu content changed
	_popup_menu.reset_size()

	# Get mouse screen coordinates (global coordinates)
	# Get window position via get_screen_transform().origin and add local mouse position
	var popup_pos := get_screen_transform().origin + get_local_mouse_position()

	_popup_menu.set_position(popup_pos)
	_popup_menu.popup()


# Happens when open scene button clicks
func _on_open_scene_button_up():
	# Open it
	EditorInterface.open_scene_from_path(get_value())
	# Show in FileSystem
	EditorInterface.get_file_system_dock().navigate_to_path(get_value())


# Happens on input on the value element
func _on_value_gui_input(event: InputEvent):
	if (
		event is InputEventMouseButton
		and event.is_released()
		and event.button_index == MOUSE_BUTTON_LEFT
		and _mouse_is_over_value
	):
		EditorInterface.get_file_system_dock().navigate_to_path(get_value())


# Happens when mouse is over value input
func _on_value_mouse_entered():
	_mouse_is_over_value = true


# Happens when mouse is out of value input
func _on_value_mouse_exited():
	_mouse_is_over_value = false


# Happens when an item is selected
func _on_popup_menu_index_pressed(index: int):
	var id = _popup_menu.get_item_id(index)
	var checked = _popup_menu.is_item_checked(index)
	var text = _popup_menu.get_item_text(index)
	_popup_menu.set_item_checked(index, !checked)

	if id == 0:
		if !checked:
			_root.add_scene_to_list(text, get_key(), get_value())
			_root.item_added_to_list.emit(self, text)
		else:
			_root.remove_scene_from_list(text, get_key(), get_value())
			_root.item_removed_from_list.emit(self, text)


# Updates the value of `key` when the user is typing it in.
func _update_key(text: String) -> void:
	# Normalize the key to be lower case without symbols and replacing spaces with underscores
	text = SceneManagerUtils.normalize_key_string(text)
	%key.text = text
	name = text
	_key = text


# Runs by hand in `_on_key_gui_input` function when text of key LineEdit
# changes and key event of it was released
func _on_key_value_text_changed() -> void:
	_root.update_all_scene_with_key(_key, get_key(), get_value(), [get_parent().get_parent()])


# Called by the UI when the text changes
func _on_key_text_changed(new_text: String) -> void:
	_update_key(new_text)
	_key_edit.caret_column = _key.length()


# Called by the UI when focus is off of the line edit
func _on_key_focus_exited() -> void:
	_submit_key()


func _on_key_text_submitted(_new_text: String) -> void:
	_submit_key()


# When a gui_input happens on LineEdit, this function triggers
func _on_key_gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.is_pressed():
			return

		# Runs when InputEventKey is released
		if _previous_key != _key:
			key_changed.emit(_key)
		is_valid = is_valid and not _key.is_empty() and _key != INVALID_KEY_NAME


# Emits a signal if the key value is different than it was at the start
func _submit_key() -> void:
	if _previous_key != _key:
		if is_valid:
			_root.item_renamed.emit(self, _previous_key, _key)
			_previous_key = _key
		else:
			set_key(_previous_key)
			key_reset.emit()
