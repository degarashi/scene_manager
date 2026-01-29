@tool
class_name SMgrMainPanel
extends MarginContainer
## Editor manager for generating necessary files and getting scene information.
##
## Handles UI callbacks for modifying data and writes the scene.gd file which
## stores all the scene information in the project.

# Scene item, include item prefabs
const SCENE_INCLUDE_ITEM = preload("res://addons/scene_manager/editor/deletable_item.tscn")
const SCENE_LIST_ITEM = preload("res://addons/scene_manager/editor/scene_list.tscn")

# Icons
const ICON_CHECKBOX_ON = preload("res://addons/scene_manager/icons/GuiChecked.svg")
const ICON_CHECKBOX_OFF = preload("res://addons/scene_manager/icons/GuiCheckedDisabled.svg")
const ICON_EXPAND_BUTTON = preload("res://addons/scene_manager/icons/Expand.svg")
const ICON_COLLAPSE_BUTTON = preload("res://addons/scene_manager/icons/Collapse.svg")

const ALL_LIST_NAME := "All"  ## Default list that contains all scenes

var _manager_data: SceneManagerData = SceneManagerData.new()
var _save_delay_timer: Timer = null  ## Timer for autosave when the key changes

# UI nodes and items
@onready var _include_path_list: Control = %include_list
# -- buttons (of bottom) ---
@onready var _save_button: Button = %save
@onready var _refresh_button: Button = %refresh
@onready var _auto_save_button: Button = %auto_save
# add list
@onready var _add_section_button: Button = %add_section_button
@onready var _section_name_line_edit: LineEdit = %section_name_to_add
# add include
@onready var _address_line_edit: LineEdit = %address
@onready var _file_dialog: FileDialog = %file_dialog
@onready var _hide_button: Button = %hide
@onready var _hide_unhide_button: Button = %hide_unhide
@onready var _add_button: Button = %add
# containers
@onready var _section_tab_container: TabContainer = %section_tab_container
@onready var _include_container: Container = %includes
@onready var _include_add_panel_container: Container = %include_add_panel


## Create a new Timer node to write to the scenes.gd file when the timer ends
func _init_save_delay_timer() -> void:
	_save_delay_timer = Timer.new()
	_save_delay_timer.wait_time = 0.5
	_save_delay_timer.one_shot = true
	add_child(_save_delay_timer)
	_save_delay_timer.timeout.connect(func() -> void: _handle_data_modification())


func _ready() -> void:
	_manager_data.load()

	# Refreshes the UI with the latest data
	_refresh_ui()
	_change_auto_save_state(_manager_data.auto_save)
	_show_includes_list(_manager_data.includes_visible)

	_init_save_delay_timer()


func item_added_to_list(node: Node, list_name: String) -> void:
	_manager_data.add_scene_to_section(node.get_value(), list_name)
	_update_categorized(node.get_key())
	_handle_data_modification()


func item_removed_from_list(node: Node, list_name: String) -> void:
	_manager_data.remove_scene_from_section(node.get_value(), list_name)
	_update_categorized(node.get_key())
	_handle_data_modification()


#region Signal Callbacks


func _handle_data_modification() -> void:
	if _manager_data.auto_save:
		_manager_data.save()

	# Update the lists to show "unsaved changes" if there's any changes from the scene file.
	_refresh_save_changes()


func section_removed(section_name: String) -> void:
	_manager_data.remove_section(section_name)

	# Loop through the scenes and update the categorized for the "All" list
	for scene in _manager_data.scenes:
		_update_categorized(scene)

	_handle_data_modification()


func _on_scene_renamed(old_scene_name: String, new_scene_name: String) -> void:
	_manager_data.change_scene_name(old_scene_name, new_scene_name)
	_rename_scene_in_lists(old_scene_name, new_scene_name)

	if _manager_data.auto_save:
		_save_delay_timer.start()


# When an include item remove button clicks
func _include_child_deleted(node: Node, address: String) -> void:
	node.queue_free()
	await node.tree_exited
	_manager_data.remove_include_path(address)
	_handle_data_modification()
	_refresh_ui()


#endregion Signal Callbacks


## Retrieves the available sections from the data.
func get_sections(address: String) -> Array:
	return _manager_data.get_scene_sections(address)


func get_section_names(excepts: Array[String] = [""]) -> Array[String]:
	var arr: Array[String] = []
	for i in range(len(excepts)):
		excepts[i] = excepts[i].capitalize()
	for node in _get_section_lists():
		if node.name in excepts:
			continue
		arr.append(node.name)
	return arr


# Clears scenes inside a UI list
func _clear_scenes_list(name: String) -> void:
	var sc_list := _get_scene_list_by_section_name(name)
	if sc_list != null:
		sc_list.clear_list()


# Clears scenes inside all UI lists
# Removes all tabs in scene manager
func _clear_all_section_lists() -> void:
	for sc_list in _get_section_lists():
		sc_list.clear_list()
		sc_list.free()


# Returns nodes of all section lists from UI in `Scene Manager` tool
func _get_section_lists() -> Array[SMgrSceneList]:
	var ret: Array[SMgrSceneList] = []
	for c: SMgrSceneList in _section_tab_container.get_children():
		ret.append(c)
	return ret


# Returns node of a specific list in UI.
# Note that the Node is part of `scene_list.gd` and has access to those functions.
func _get_scene_list_by_section_name(section_name: String) -> SMgrSceneList:
	for sc_list in _get_section_lists():
		if section_name.capitalize() == sc_list.name:
			return sc_list
	return null


# Sorts all the lists in the UI based on the key name.
func _sort_scenes_in_lists() -> void:
	for sc_list in _get_section_lists():
		sc_list.sort_scenes()


# Renames a scene in all the lists.
func _rename_scene_in_lists(old_key: String, new_key: String) -> void:
	for sc_list in _get_section_lists():
		sc_list.update_item_key(old_key, new_key)
		sc_list.sort_scenes()


# Updates the categorized/uncategorized sub section in the "All" list for the scene.
func _update_categorized(key: String) -> void:
	# Get the scene information from the data
	var categorized := _manager_data.has_sections(_manager_data.scenes[key]["value"])

	var sc_list := _get_scene_list_by_section_name(ALL_LIST_NAME)
	sc_list.update_item_categorized(key, categorized)


## Removes a scene from a specific list.
func remove_scene_from_list(
	section_name: String, scene_name: String, scene_address: String
) -> void:
	var sc_list := _get_scene_list_by_section_name(section_name)
	sc_list.remove_item(scene_name, scene_address)


## Adds an item to a list
##
## This function is used in `scene_item.gd` script and plus doing what it is supposed
## to do, removes and again adds the item in `All` section so that it can be placed
## in correct place in correct section.
func add_scene_to_list(
	list_name: String, scene_name: String, scene_address: String, categorized: bool = false
) -> void:
	var sc_list := _get_scene_list_by_section_name(list_name)
	if sc_list == null:
		return
	await sc_list.add_item(scene_name, scene_address, categorized)


# Adds an address to the include list
func _add_include_item(address: String) -> void:
	var item: SMgrDeletableItem = SCENE_INCLUDE_ITEM.instantiate()
	item.set_address(address)
	item.on_remove_request.connect(_include_child_deleted)
	_include_path_list.add_child(item)


# Clears all tabs, UI lists and include list
func _clear_ui_elements() -> void:
	_clear_all_section_lists()
	_clear_include_list()


# Reloads all scenes in UI and in this script
func _reload_ui_scenes() -> void:
	for key in _manager_data.scenes:
		var scene = _manager_data.scenes[key]
		for section in scene["sections"]:
			add_scene_to_list(section, key, scene["value"], true)

		add_scene_to_list(
			ALL_LIST_NAME, key, scene["value"], _manager_data.has_sections(scene["value"])
		)

	_sort_scenes_in_lists()


# Reloads include list in UI
func _reload_ui_includes() -> void:
	_clear_include_list()
	for text in _manager_data.includes:
		_add_include_item(text)


# Reloads tabs in UI
func _reload_ui_tabs() -> void:
	if _get_scene_list_by_section_name(ALL_LIST_NAME) == null:
		_add_section_tab(ALL_LIST_NAME)
	for section in _manager_data.sections:
		var found = false
		for sc_list in _get_section_lists():
			if sc_list.name == section:
				found = true
		if not found:
			_add_section_tab(section)


# Refresh button
func _refresh_ui() -> void:
	_manager_data.load()
	_clear_ui_elements()
	_reload_ui_tabs()
	_reload_ui_scenes()
	_reload_ui_includes()


## Gets called by other nodes in UI
##
## Updates name of all scene_key.
func update_all_scene_with_key(
	scene_key: String, scene_new_key: String, value: String, except_list: Array = []
) -> void:
	for sc_list in _get_section_lists():
		if sc_list not in except_list:
			sc_list.update_scene_with_key(scene_key, scene_new_key, value)


## Checks for duplications in the scene data.[br]
## key is the new key to check against the current scene data to see if there's a duplicate.[br]
## scene_list is the list the item being changed is located.
func check_duplication(key: String, scene_list: SMgrSceneList) -> void:
	if key in _manager_data.scenes:
		scene_list.update_validity(key)


# Save button
func _on_save_button_up() -> void:
	_manager_data.save()
	_refresh_save_changes()


# Loops through the UI lists and updates them with the "unsaved changes"
#   visibility if the data has changed.
func _refresh_save_changes() -> void:
	for list in _get_section_lists():
		list.set_changes_unsaved(_manager_data.has_changes)


# Returns array of include nodes from UI view
func _get_includes_list() -> Array[SMgrDeletableItem]:
	var ret: Array[SMgrDeletableItem] = []
	for c: SMgrDeletableItem in _include_path_list.get_children():
		ret.append(c)
	return ret


# Clears includes from UI
func _clear_include_list() -> void:
	for node in _get_includes_list():
		node.free()


# Returns true if passed address exists in include list
func _include_exists_in_list(address: String) -> bool:
	for ent in _get_includes_list():
		if ent.get_address() == address or address.begins_with(ent.get_address()):
			return true
	return false


# Include list Add button up
func _on_add_button_up():
	if _include_exists_in_list(_address_line_edit.text):
		_address_line_edit.text = ""
		return

	_add_include_item(_address_line_edit.text)
	_manager_data.add_include_path(_address_line_edit.text)

	_address_line_edit.text = ""
	_add_button.disabled = true

	_handle_data_modification()
	_refresh_ui()


# Pops up file dialog to select a folder to include
func _on_file_dialog_button_button_up() -> void:
	_file_dialog.popup_centered(Vector2(600, 600))


# When a file or a dir selects by file dialog
func _on_file_dialog_dir_file_selected(path) -> void:
	_address_line_edit.text = path
	_on_address_text_changed(path)


# When include address bar text changes
func _on_address_text_changed(new_text: String) -> void:
	if new_text != "":
		if (
			DirAccess.dir_exists_absolute(new_text)
			or FileAccess.file_exists(new_text) and new_text.begins_with("res://")
		):
			_add_button.disabled = false
		else:
			_add_button.disabled = true
	else:
		_add_button.disabled = true


# Adds a new list to the section-tab container
func _add_section_tab(text: String) -> void:
	var sc_list: SMgrSceneList = SCENE_LIST_ITEM.instantiate()
	sc_list.name = text.capitalize()
	# --- signal connection ---
	sc_list.section_removed.connect(self.section_removed)
	sc_list.req_check_duplication.connect(self.check_duplication)
	sc_list.on_scene_renamed.connect(self._on_scene_renamed)
	sc_list.remove_scene_from_list.connect(self.remove_scene_from_list)
	sc_list.item_added_to_list.connect(self.item_added_to_list)
	sc_list.item_removed_from_list.connect(self.item_removed_from_list)
	sc_list.add_scene_to_list.connect(self.add_scene_to_list)
	# ---
	_section_tab_container.add_child(sc_list)


# Adds the new section to the tab container and to the manager data
func _on_add_section_button_up() -> void:
	if not _section_name_line_edit.text.is_empty():
		_add_section_tab(_section_name_line_edit.text)
		_manager_data.add_section(_section_name_line_edit.text)

		_section_name_line_edit.text = ""
		_add_section_button.disabled = true

		_handle_data_modification()


func _on_section_name_text_changed(new_text: String) -> void:
	if new_text != "" && !(new_text.capitalize() in get_section_names()):
		_add_section_button.disabled = false
	else:
		_add_section_button.disabled = true


# If set true, then the include list will be shown. If false, the list will be hidden.
func _show_includes_list(value: bool) -> void:
	var icon: Texture2D = ICON_COLLAPSE_BUTTON if value else ICON_EXPAND_BUTTON
	_hide_button.icon = icon
	_hide_unhide_button.icon = icon
	_include_container.visible = value
	_include_add_panel_container.visible = value
	_hide_unhide_button.visible = !value


func _on_hide_button_up() -> void:
	_manager_data.includes_visible = not _manager_data.includes_visible
	_show_includes_list(_manager_data.includes_visible)
	_handle_data_modification()


# Tab changes
func _on_section_tab_changed(_tab: int) -> void:
	_on_section_name_text_changed(_section_name_line_edit.text)


func _change_auto_save_state(value: bool) -> void:
	_auto_save_button.set_meta("enabled", value)
	_auto_save_button.icon = ICON_CHECKBOX_ON if value else ICON_CHECKBOX_OFF
	_save_button.disabled = value


func _on_auto_save_button_up() -> void:
	_manager_data.auto_save = not _manager_data.auto_save
	_change_auto_save_state(_manager_data.auto_save)
	_handle_data_modification()
