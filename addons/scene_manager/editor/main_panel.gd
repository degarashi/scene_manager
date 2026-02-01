@tool
class_name SMgrMainPanel
extends MarginContainer
## Editor manager for generating necessary files and getting scene information.
##
## Handles UI callbacks for modifying data and writes the scene.gd file which
## stores all the scene information in the project.

# Scene item, include item prefabs
const SCENE_INCLUDE_ITEM = preload("uid://ciaqe7l3hugns")
const SCENE_LIST_ITEM = preload("uid://7r0ywsv3ga6g")
const EBUS := preload("uid://ra25t5in8erp")

# Icons
const ICON_CHECKBOX_ON = preload("uid://c1ps4ed6wrx51")
const ICON_CHECKBOX_OFF = preload("uid://bu5cjmgtiiwfp")
const ICON_EXPAND_BUTTON = preload("uid://t6iu67x15d3")
const ICON_COLLAPSE_BUTTON = preload("uid://bd6ob6pgam1gt")

const C = preload("uid://c3vvdktou45u")

var _manager_data: SMgrData
var _save_delay_timer: Timer = null

# UI nodes and items
@onready var _section_tab_cont: TabContainer = %section_tab_container

# --- add section ---
@onready var _add_section_button: Button = %add_section_button
@onready var _section_name_line_edit: LineEdit = %section_name_to_add

# --- include list ---
@onready var _address_line_edit: LineEdit = %address
@onready var _file_dialog: FileDialog = %file_dialog
@onready var _hide_button: Button = %hide
@onready var _hide_unhide_button: Button = %hide_unhide
@onready var _add_button: Button = %add

@onready var _include_path_list: Control = %include_list
@onready var _include_path_cont: Container = %includes
@onready var _include_add_panel_cont: Container = %include_add_panel

# -- buttons (of bottom) ---
@onready var _save_button: Button = %save
@onready var _refresh_button: Button = %refresh
@onready var _auto_save_button: Button = %auto_save


## Create a new Timer node to write to the scenes.gd file when the timer ends
func _init_save_delay_timer() -> void:
	_save_delay_timer = Timer.new()
	_save_delay_timer.wait_time = 0.5
	_save_delay_timer.one_shot = true
	add_child(_save_delay_timer)
	_save_delay_timer.timeout.connect(func() -> void: _handle_data_modification())


func _connect_ebus() -> void:
	EBUS.get_section_names.connect(
		func(recv: Array) -> void:
			recv.clear()
			recv.append_array(get_section_names())
	)
	EBUS.get_sections.connect(
		func(recv: Array, scene_address: String) -> void:
			recv.clear()
			recv.append_array(get_sections(scene_address))
	)
	EBUS.scene_renamed.connect(_on_scene_renamed)
	EBUS.remove_scene_from_section.connect(_remove_scene_from_section)
	EBUS.scene_added_to_section.connect(_scene_added_to_section)
	EBUS.scene_removed_from_section.connect(_item_removed_from_section)
	EBUS.add_scene_to_section.connect(_add_scene_to_section)


func _ready() -> void:
	_manager_data = SMgrData.load_data(SMgrProjectSettings.scene_path)
	_connect_ebus()

	# Refreshes the UI with the latest data
	_refresh_ui()
	_change_auto_save_state(SMgrProjectSettings.auto_save)
	_show_includes_list(SMgrProjectSettings.includes_visible)

	_init_save_delay_timer()


func _scene_added_to_section(item: SMgrSceneItem, section_name: String) -> void:
	_manager_data.add_scene_to_section(item.get_scene_path(), section_name)
	_update_categorized(item.get_scene_name())
	_handle_data_modification()


func _item_removed_from_section(item: SMgrSceneItem, section_name: String) -> void:
	_manager_data.remove_scene_from_section(item.get_scene_path(), section_name)
	_update_categorized(item.get_scene_name())
	_handle_data_modification()


#region Signal Callbacks


func _handle_data_modification() -> void:
	if SMgrProjectSettings.auto_save:
		_manager_data.save_data(SMgrProjectSettings.scene_path)

	# Update the lists to show "unsaved changes" if there's any changes from the scene file.
	_refresh_save_changes()


func _section_removed(section_name: String) -> void:
	_manager_data.remove_section(section_name)

	# Loop through the scenes and update the categorized for the ALL_SECTION_NAME list
	for sc_name in _manager_data.scenes:
		_update_categorized(sc_name)

	_handle_data_modification()


func _on_scene_renamed(old_scene_name: String, new_scene_name: String) -> void:
	_manager_data.change_scene_name(old_scene_name, new_scene_name)
	_rename_scene_in_lists(old_scene_name, new_scene_name)

	if SMgrProjectSettings.auto_save:
		_save_delay_timer.start()


# When an include item remove button clicks
func _include_child_removed(item: SMgrRemovableItem) -> void:
	var item_ent := item.get_item_string()
	item.queue_free()
	await item.tree_exited
	_manager_data.remove_include_path(item_ent)
	_handle_data_modification()
	_refresh_ui()


#endregion Signal Callbacks


## Retrieves the available sections from the data.
func get_sections(scene_address: String) -> Array[String]:
	return _manager_data.get_scene_sections(scene_address)


func get_section_names(excepts: Array[String] = [""]) -> Array[String]:
	var arr: Array[String] = []
	for i in range(len(excepts)):
		excepts[i] = excepts[i].capitalize()
	for sc_list in _get_section_lists():
		if sc_list.name in excepts:
			continue
		arr.append(sc_list.name)
	return arr


# Returns nodes of all section lists from UI in `Scene Manager` tool
func _get_section_lists() -> Array[SMgrSceneList]:
	var ret: Array[SMgrSceneList] = []
	for c: SMgrSceneList in _section_tab_cont.get_children():
		ret.append(c)
	return ret


# Returns node of a specific list in UI.
# Note that the Node is part of `scene_list.gd` and has access to those functions.
func _get_scene_list_by_section_name(section_name: String) -> SMgrSceneList:
	for sc_list in _get_section_lists():
		if section_name.capitalize() == sc_list.name:
			return sc_list
	return null


func _sort_scenes_in_lists() -> void:
	for sc_list in _get_section_lists():
		sc_list.sort_scenes()


# Renames a scene in all the lists.
func _rename_scene_in_lists(old_name: String, new_name: String) -> void:
	for sc_list in _get_section_lists():
		sc_list.update_item_key(old_name, new_name)
		sc_list.sort_scenes()


# Updates the categorized/uncategorized sub section in the ALL_SECTION_NAME list for the scene.
func _update_categorized(sc_name: String) -> void:
	# Get the scene information from the data
	var categorized := _manager_data.has_section(_manager_data.scenes[sc_name].path)

	var sc_list := _get_scene_list_by_section_name(C.ALL_SECTION_NAME)
	sc_list.update_item_categorized(sc_name, categorized)


## Removes a scene from a specific list.
func _remove_scene_from_section(
	section_name: String, scene_name: String, scene_address: String
) -> void:
	var sc_list := _get_scene_list_by_section_name(section_name)
	sc_list.remove_item(scene_name, scene_address)


## Adds an item to a list
##
## This function is used in `scene_item.gd` script and plus doing what it is supposed
## to do, removes and again adds the item in `All` section so that it can be placed
## in correct place in correct section.
func _add_scene_to_section(
	list_name: String, scene_name: String, scene_address: String, categorized: bool = false
) -> void:
	var sc_list := _get_scene_list_by_section_name(list_name)
	if sc_list == null:
		return
	await sc_list.add_item(scene_name, scene_address, categorized)


# Adds an address to the include list
func _add_include_item(address: String) -> void:
	var item: SMgrRemovableItem = SCENE_INCLUDE_ITEM.instantiate()
	item.set_item_string(address)
	item.on_remove.connect(_include_child_removed)
	_include_path_list.add_child(item)


func _reload_ui_scenes() -> void:
	for sc_name in _manager_data.scenes:
		var scene := _manager_data.scenes[sc_name]
		for section in scene.sections:
			_add_scene_to_section(section, sc_name, scene.path, true)

		_add_scene_to_section(
			C.ALL_SECTION_NAME, sc_name, scene.path, _manager_data.has_section(scene.path)
		)

	_sort_scenes_in_lists()


func _reload_ui_includes() -> void:
	for child in _include_path_list.get_children():
		child.free()
	for inc_path in _manager_data.include_list:
		_add_include_item(inc_path)


func _reload_ui_tabs() -> void:
	for child in _section_tab_cont.get_children():
		child.free()
	_add_section_tab(C.ALL_SECTION_NAME)

	for section in _manager_data.sections:
		var found = false
		for sc_list in _get_section_lists():
			if sc_list.name == section:
				found = true
		if not found:
			_add_section_tab(section)


func _refresh_ui() -> void:
	_reload_ui_tabs()
	_reload_ui_scenes()
	_reload_ui_includes()


## Checks for scene_name duplications in the scene data.
func _check_duplication(sc_name: String, scene_list: SMgrSceneList) -> void:
	if sc_name in _manager_data.scenes:
		scene_list.check_duplication(sc_name)


func _on_save_button_up() -> void:
	_manager_data.save(SMgrProjectSettings.scene_path)
	_refresh_save_changes()


# Loops through the UI lists and updates them with the "unsaved changes"
#   visibility if the data has changed.
func _refresh_save_changes() -> void:
	for list in _get_section_lists():
		list.set_changes_unsaved(_manager_data.has_changes)


# Returns array of include nodes from UI view
func _get_includes_list() -> Array[SMgrRemovableItem]:
	var ret: Array[SMgrRemovableItem] = []
	for c: SMgrRemovableItem in _include_path_list.get_children():
		ret.append(c)
	return ret


# Returns true if passed address exists in include list
func _include_exists_in_list(address: String) -> bool:
	for ent in _get_includes_list():
		if ent.get_item_string() == address or address.begins_with(ent.get_item_string()):
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
func _add_section_tab(section_name: String) -> void:
	var sc_list: SMgrSceneList = SCENE_LIST_ITEM.instantiate()
	sc_list.setup(section_name)
	# --- signal connection ---
	sc_list.section_removed.connect(self._section_removed)
	sc_list.req_check_duplication.connect(self._check_duplication)
	# ---
	_section_tab_cont.add_child(sc_list)


# Adds the new section to the tab container and to the manager data
func _on_add_section_button_up() -> void:
	if not _section_name_line_edit.text.is_empty():
		_add_section_tab(_section_name_line_edit.text)
		_manager_data.add_section(_section_name_line_edit.text)

		_section_name_line_edit.text = ""
		_add_section_button.disabled = true

		_handle_data_modification()


func _on_section_name_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		_add_section_button.disabled = true
		return

	var is_duplicate: bool = new_text.capitalize() in get_section_names()
	_add_section_button.disabled = is_duplicate


# If set true, then the include list will be shown. If false, the list will be hidden.
func _show_includes_list(value: bool) -> void:
	var icon: Texture2D = ICON_COLLAPSE_BUTTON if value else ICON_EXPAND_BUTTON
	_hide_button.icon = icon
	_hide_unhide_button.icon = icon
	_include_path_cont.visible = value
	_include_add_panel_cont.visible = value
	_hide_unhide_button.visible = !value


func _on_hide_button_up() -> void:
	SMgrProjectSettings.includes_visible = not SMgrProjectSettings.includes_visible
	_show_includes_list(SMgrProjectSettings.includes_visible)
	_handle_data_modification()


# Tab changes
func _on_section_tab_changed(_tab: int) -> void:
	_on_section_name_text_changed(_section_name_line_edit.text)


func _change_auto_save_state(value: bool) -> void:
	_auto_save_button.set_meta("enabled", value)
	_auto_save_button.icon = ICON_CHECKBOX_ON if value else ICON_CHECKBOX_OFF
	_save_button.disabled = value


func _on_auto_save_button_up() -> void:
	SMgrProjectSettings.auto_save = not SMgrProjectSettings.auto_save
	_change_auto_save_state(SMgrProjectSettings.auto_save)
	_handle_data_modification()


func _on_refresh_button_up() -> void:
	_manager_data = SMgrData.load_data(SMgrProjectSettings.scene_path)
	_refresh_ui()
