@tool
class_name SMgrSceneItem
extends HBoxContainer

const _MENU_ID_CATEGORY = 0
const _THEME_DUPLICATE_LINE_EDIT: StyleBox = preload("uid://21mjw515mptn")  # line_edit_duplicate.tres
const _C = preload("uid://c3vvdktou45u")  # scene_manager_constants.gd

@export var _ebus_editor: SMgrEbusEditor
var _mouse_is_over_path: bool
var _scene_uid: int
var _previous_name: String

# Dictionary to hold the state when the menu was opened
var _initial_categories_state: Dictionary[int, bool] = {}

@onready var _popup_menu: PopupMenu = %popup_menu
@onready var _scene_name_edit: LineEdit = %scene_name_edit
@onready var _scene_path_edit: LineEdit = %scene_path
@onready var _thumbnail: TextureRect = %thumbnail


func activate(sc_uid: int) -> void:
	_scene_uid = sc_uid
	if is_node_ready():
		_refresh_ui_from_uid()


func _refresh_ui_from_uid() -> void:
	if _scene_uid == ResourceUID.INVALID_ID:
		return

	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scene_info.emit(recv, _scene_uid)
	if recv.is_empty():
		return

	var info: SMgrDataScene = recv[0]
	_scene_name_edit.text = info.name

	_scene_path_edit.text = info.path
	_scene_path_edit.tooltip_text = info.path
	# Move caret to the end so the end of the string is visible
	_scene_path_edit.caret_column = _scene_path_edit.text.length()

	_request_thumbnail(info.path)


func _request_thumbnail(path: String) -> void:
	if not Engine.is_editor_hint():
		return

	var previewer := EditorInterface.get_resource_previewer()
	previewer.queue_resource_preview(path, self, "_on_thumbnail_ready", null)


func _on_thumbnail_ready(
	path: String, preview: Texture2D, _thumbnail_preview: Texture2D, _userdata: Variant
) -> void:
	if path == get_scene_path() and preview:
		_thumbnail.texture = preview


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


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_pressed()
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		_ebus_editor.on_scene_selected.emit(_scene_uid)


func _on_popup_button_button_up() -> void:
	_popup_menu.clear()
	_initial_categories_state.clear()

	var idx: int = 0
	_popup_menu.add_separator("Categories")
	idx += 1

	# Get which categories the current path belongs to
	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scene_info.emit(recv, _scene_uid)
	if recv.is_empty():
		return
	var current_categories := recv[0].categories

	var all_categories_id: Array[int]
	_ebus_editor.get_categories.emit(all_categories_id)
	for category_id in all_categories_id:
		var recv2: Array[SMgrCategoryData]
		_ebus_editor.get_category_by_id.emit(recv2, category_id)
		if recv2.is_empty():
			continue
		var cat := recv2[0]

		_popup_menu.add_check_item(cat.name)
		_popup_menu.set_item_id(idx, _MENU_ID_CATEGORY)
		_popup_menu.set_item_metadata(idx, category_id)

		var is_checked: bool = category_id in current_categories
		_popup_menu.set_item_checked(idx, is_checked)

		# Save the state when opened
		_initial_categories_state[category_id] = is_checked
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

		var category_id: int = _popup_menu.get_item_metadata(i)
		var recv: Array[SMgrCategoryData]
		_ebus_editor.get_category_by_id.emit(recv, category_id)
		if recv.is_empty():
			continue
		var cat := recv[0]

		var is_now_checked := _popup_menu.is_item_checked(i)
		var was_checked: bool = _initial_categories_state.get(category_id, false)

		if is_now_checked == was_checked:
			# No change
			continue

		if is_now_checked:
			# OFF -> ON: Add to category
			_ebus_editor.add_scene_to_category.emit(_scene_uid, category_id)
		else:
			# ON -> OFF: Remove from category
			_ebus_editor.remove_scene_from_category.emit(_scene_uid, category_id)


func _on_scene_name_changed(new_name: String) -> void:
	if _check_name_duplication(new_name):
		_custom_set_theme(_THEME_DUPLICATE_LINE_EDIT)
	else:
		_remove_custom_theme()


func _check_name_duplication(name_str: String) -> bool:
	var recv: Array[bool]
	_ebus_editor.scene_name_duplication_check.emit(recv, name_str)
	return false if recv.is_empty() else recv[0]


func _custom_set_theme(theme: StyleBox) -> void:
	_scene_name_edit.add_theme_stylebox_override("normal", theme)


func _remove_custom_theme() -> void:
	_scene_name_edit.remove_theme_stylebox_override("normal")


func _on_scene_name_submitted(_new_name: String) -> void:
	_submit_scene_name()


func _submit_scene_name() -> void:
	var new_name := _scene_name_edit.text
	new_name = SMgrUtil.sanitize_scene_name(new_name)
	if _previous_name == new_name:
		return

	if new_name.is_empty() or _check_name_duplication(new_name):
		_scene_name_edit.text = _previous_name
	else:
		_scene_name_edit.text = new_name
		_previous_name = new_name
		_ebus_editor.change_scene_name.emit(_scene_uid, new_name)
	_remove_custom_theme()


func _on_scene_name_edit_focus_entered() -> void:
	_previous_name = _scene_name_edit.text


func _ready() -> void:
	_refresh_ui_from_uid()
