@tool
class_name SMgrSceneItem
extends HBoxContainer

signal on_scene_name_changed(scene_name: String)
signal on_reset

const MENU_ID_CATEGORY = 0
const THEME_DUPLICATE_LINE_EDIT: StyleBox = preload("uid://21mjw515mptn")
const INVALID_SCENE_NAME: String = "none"
const EBUS = preload("uid://ra25t5in8erp")
const C = preload("uid://c3vvdktou45u")

## Returns whether or not the scene_name in the scene item is valid
var is_valid: bool:
	set(valid):
		is_valid = valid
		if is_inside_tree():
			if valid:
				remove_custom_theme()
			else:
				_custom_set_theme(THEME_DUPLICATE_LINE_EDIT)

var _mouse_is_over_path: bool

## Used when comparing the user typed scene_name to detect changes
var _previous_name: String

@onready var _popup_menu: PopupMenu = %popup_menu
@onready var _scene_name_edit: LineEdit = %scene_name_edit
@onready var _scene_name: String = %scene_name_edit.text
@onready var _scene_path: LineEdit = %scene_path


func _ready() -> void:
	_previous_name = _scene_name


## Directly set the scene_name. Called by other UI elements
##   when updating as this bypases the text normalization.
func set_scene_name(sc_name: String) -> void:
	_previous_name = sc_name
	_scene_name = sc_name
	_scene_name_edit.text = sc_name


func set_scene_path(path: String) -> void:
	_scene_path.text = path


func get_scene_name() -> String:
	return _scene_name_edit.text


func get_scene_path() -> String:
	return _scene_path.text


## Sets passed theme to normal theme of `scene_name` LineEdit
func _custom_set_theme(theme: StyleBox) -> void:
	_scene_name_edit.add_theme_stylebox_override("normal", theme)


## Removes added custom theme for `scene_name` LineEdit
func remove_custom_theme() -> void:
	_scene_name_edit.remove_theme_stylebox_override("normal")


func _on_popup_button_button_up() -> void:
	var i: int = 0
	var sections: Array
	EBUS.get_section_names.emit(sections)
	_popup_menu.clear()
	_popup_menu.add_separator("Categories")
	i += 1

	# Categories have id of MENU_ID_CATEGORY
	for section_name in sections:
		if section_name == C.ALL_SECTION_NAME:
			continue
		_popup_menu.add_check_item(section_name)
		_popup_menu.set_item_id(i, MENU_ID_CATEGORY)

		var sect: Array
		EBUS.get_sections.emit(sect, get_scene_path())
		_popup_menu.set_item_checked(i, section_name in sect)
		i += 1

	# Recalculate size since menu content changed
	_popup_menu.reset_size()

	# Get mouse screen coordinates (global coordinates)
	# Get window position via get_screen_transform().origin and add local mouse position
	var popup_pos := get_screen_transform().origin + get_local_mouse_position()

	_popup_menu.set_position(popup_pos)
	_popup_menu.popup()


func _on_open_scene_button_up() -> void:
	# Open scene
	EditorInterface.open_scene_from_path(get_scene_path())
	# Show in FileSystem
	EditorInterface.select_file(get_scene_path())


# Happens on input on the scene_path element
func _on_scene_path_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_released()
		and event.button_index == MOUSE_BUTTON_LEFT
		and _mouse_is_over_path
	):
		EditorInterface.select_file(get_scene_path())


# Happens when mouse is over scene_path input
func _on_scene_path_mouse_entered() -> void:
	_mouse_is_over_path = true


# Happens when mouse is out of scene_path input
func _on_scene_path_mouse_exited() -> void:
	_mouse_is_over_path = false


func _on_popup_menu_index_pressed(index: int) -> void:
	var checked := _popup_menu.is_item_checked(index)
	_popup_menu.set_item_checked(index, !checked)

	var section_name := _popup_menu.get_item_text(index)
	if _popup_menu.get_item_id(index) == MENU_ID_CATEGORY:
		if !checked:
			EBUS.add_scene_to_section.emit(section_name, get_scene_name(), get_scene_path(), false)
			EBUS.scene_added_to_section.emit(self, section_name)
		else:
			EBUS.remove_scene_from_section.emit(section_name, get_scene_name(), get_scene_path())
			EBUS.scene_removed_from_section.emit(self, section_name)


## Updates the scene_name internal value and normalizes the UI text
func _update_scene_name(sc_name: String) -> void:
	# Normalize the scene_name to be lower case without symbols and replacing spaces with underscores
	sc_name = SceneManagerUtils.sanitize_scene_name(sc_name)
	_scene_name_edit.text = sc_name
	name = sc_name
	_scene_name = sc_name


# Triggered when LineEdit text changes
func _on_scene_name_changed(new_name: String) -> void:
	# Store current text and notify manager for real-time validation (e.g., duplicate check)
	_scene_name = new_name
	on_scene_name_changed.emit(new_name)


func _on_scene_name_submitted(_new_text: String) -> void:
	_submit_scene_name()


## Finalizes the scene_name change and notifies the root manager
func _submit_scene_name() -> void:
	# Sanitize scene_name only on submission to avoid cursor jumping issues
	var sanitized_name := SceneManagerUtils.sanitize_scene_name(get_scene_name())

	# Basic validation
	var valid_name := not sanitized_name.is_empty() and sanitized_name != INVALID_SCENE_NAME

	if _previous_name != sanitized_name:
		if is_valid and valid_name:
			# Successfully renamed
			_update_scene_name(sanitized_name)
			EBUS.scene_renamed.emit(_previous_name, _scene_name)
			_previous_name = _scene_name
		else:
			# Revert to previous valid scene_name if invalid or duplicate
			set_scene_name(_previous_name)
			is_valid = true
			on_reset.emit()
