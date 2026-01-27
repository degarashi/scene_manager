@tool
class_name SMgrSceneItem
extends HBoxContainer

const _MENU_ID_CATEGORY = 0
const _THEME_DUPLICATE_LINE_EDIT: StyleBox = preload("uid://21mjw515mptn")
const _EBUS = preload("uid://ra25t5in8erp")
const _C = preload("uid://c3vvdktou45u")

var _mouse_is_over_path: bool
var _scene_uid: int
var _previous_name: String

# Dictionary to hold the state when the menu was opened { "SectionName": bool (checked) }
var _initial_sections_state: Dictionary = {}

@onready var _popup_menu: PopupMenu = %popup_menu
@onready var _scene_name_edit: LineEdit = %scene_name_edit
@onready var _scene_path_edit: LineEdit = %scene_path


func setup(sc_uid: int) -> void:
	_scene_uid = sc_uid

	var recv: Array[SMgrDataScene]
	_EBUS.get_scene_info.emit(recv, sc_uid)
	var info: SMgrDataScene = recv[0]
	_scene_name_edit.text = info.name

	_scene_path_edit.text = info.path
	_scene_path_edit.tooltip_text = info.path
	# Move caret to the end so the end of the string is visible
	_scene_path_edit.caret_column = _scene_path_edit.text.length()


func get_scene_name() -> String:
	return _scene_name_edit.text


func get_scene_path() -> String:
	return _scene_path_edit.text


func _on_open_scene_button_up() -> void:
	# Open scene
	EditorInterface.open_scene_from_path(get_scene_path())
	# Show in FileSystem
	EditorInterface.select_file(get_scene_path())


func _on_scene_path_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_released()
		and event.button_index == MOUSE_BUTTON_LEFT
		and _mouse_is_over_path
	):
		EditorInterface.select_file(get_scene_path())


func _on_scene_path_mouse_entered() -> void:
	_mouse_is_over_path = true


func _on_scene_path_mouse_exited() -> void:
	_mouse_is_over_path = false


func _on_popup_button_button_up() -> void:
	var idx: int = 0
	var sections: Array[String]
	_EBUS.get_section_names.emit(sections)

	_popup_menu.clear()
	_initial_sections_state.clear()

	_popup_menu.add_separator("Categories")
	idx += 1

	# Get which sections the current path belongs to
	var recv: Array[SMgrDataScene]
	_EBUS.get_scene_info.emit(recv, _scene_uid)
	var current_sects := recv[0].sections

	for section_name in sections:
		_popup_menu.add_check_item(section_name)
		_popup_menu.set_item_id(idx, _MENU_ID_CATEGORY)

		var is_checked: bool = section_name in current_sects
		_popup_menu.set_item_checked(idx, is_checked)

		# Save the state when opened
		_initial_sections_state[section_name] = is_checked
		idx += 1

	_popup_menu.reset_size()
	var popup_pos := get_screen_transform().origin + get_local_mouse_position()
	_popup_menu.set_position(popup_pos)
	_popup_menu.popup()


func _on_popup_menu_index_pressed(index: int) -> void:
	# Toggle the check state of the clicked item (UI update only)
	if _popup_menu.get_item_id(index) == _MENU_ID_CATEGORY:
		var checked := _popup_menu.is_item_checked(index)
		_popup_menu.set_item_checked(index, !checked)


func _on_popup_menu_popup_hide() -> void:
	# Apply changes by comparing with initial state when the menu closes
	for i in _popup_menu.item_count:
		if _popup_menu.get_item_id(i) != _MENU_ID_CATEGORY:
			continue

		var section_name := _popup_menu.get_item_text(i)
		var is_now_checked := _popup_menu.is_item_checked(i)
		var was_checked: bool = _initial_sections_state.get(section_name, false)

		if is_now_checked == was_checked:
			# No change
			continue

		if is_now_checked:
			# OFF -> ON: Add to section
			_EBUS.add_scene_to_section.emit(_scene_uid, section_name)
		else:
			# ON -> OFF: Remove from section
			_EBUS.remove_scene_from_section.emit(_scene_uid, section_name)


func _on_scene_name_changed(new_name: String) -> void:
	if _check_name_duplication(new_name):
		_custom_set_theme(_THEME_DUPLICATE_LINE_EDIT)
	else:
		_remove_custom_theme()


func _check_name_duplication(name_str: String) -> bool:
	var recv: Array[bool]
	_EBUS.has_scene_by_name.emit(recv, name_str)
	return recv[0]


func _custom_set_theme(theme: StyleBox) -> void:
	_scene_name_edit.add_theme_stylebox_override("normal", theme)


func _remove_custom_theme() -> void:
	_scene_name_edit.remove_theme_stylebox_override("normal")


func _on_scene_name_submitted(_new_name: String) -> void:
	_submit_scene_name()


func _submit_scene_name() -> void:
	var new_name := _scene_name_edit.text
	new_name = SceneManagerUtils.sanitize_scene_name(new_name)
	if _previous_name == new_name:
		return

	if new_name.is_empty() or _check_name_duplication(new_name):
		_scene_name_edit.text = _previous_name
	else:
		_scene_name_edit.text = new_name
		_previous_name = new_name
		_EBUS.change_scene_name.emit(_scene_uid, new_name)
	_remove_custom_theme()


func _on_scene_name_edit_focus_entered() -> void:
	_previous_name = _scene_name_edit.text
