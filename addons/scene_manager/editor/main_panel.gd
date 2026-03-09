@tool
class_name SMgrMainPanel
extends MarginContainer

# Scene item, include item prefabs
const _INCLUDE_ITEM_SCENE = preload("uid://ciaqe7l3hugns")
const _PRIMARY_CATEGORY_SCENE = preload("uid://cf1lsul5kbw85")
const _SECONDARY_CATEGORY_SCENE = preload("uid://y7ksk521w5au")
const _C = preload("uid://c3vvdktou45u")
const _AF = preload("uid://dlgh4u64a7qxk")
const _CHK = preload("uid://bfsxxd1vc4jm7")
const _ICON_EXPAND_BUTTON = preload("uid://t6iu67x15d3")
const _ICON_COLLAPSE_BUTTON = preload("uid://bd6ob6pgam1gt")

@export var _ebus_editor: SMgrEbusEditor
@export var _ebus_ins: SMgrEbusInspector
var _ps := preload("uid://dn6eh4s0h8jhi")
var _manager_data: SMgrDataEditor
var _log: SMgrLogBase
## For file monitoring
var _last_modified_time: int = 0
var _connect_ebus: bool = false

@onready var _save_delay_timer: Timer = %SaveDelayTimer

@onready var _category_tab_cont: TabContainer = %CategoryTabContainer

# --- add category ---
@onready var _add_category_button: Button = %AddCategoryButton
@onready var _category_name_edit: LineEdit = %CategoryNameToAdd

# --- include list ---
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _hide_include_button: Button = %HideIncludeButton
@onready var _add_include_button: Button = %AddIncludeButton

@onready var _include_path_list: Control = %IncludeList
@onready var _misc_tab: TabContainer = %MiscTab

@onready var _garbage_bin: Control = %GarbageBin


func _ebus_get_scene_enums_as_string(recv: Array[String]) -> void:
	assert(recv.is_empty())
	var scene_all := _manager_data.get_data().get_scenes_all()
	for scene in scene_all:
		recv.append(SceneManagerUtils.sanitize_as_enum_string(scene.name))


func prepare(conn_ebus: bool) -> void:
	_connect_ebus = conn_ebus


func _ready() -> void:
	if _connect_ebus:
		_do_connect_ebus()

	_reload_data()
	_refresh_ui()

	_show_includes_list(_ps.includes_visible)

	# subscribe to editor file system changes
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		fs.filesystem_changed.connect(_on_filesystem_changed)

	_update_last_modified_time()


func _remove_node_safely(node: Node) -> void:
	node.reparent(_garbage_bin)
	node.queue_free()


func _exit_tree() -> void:
	_disconnect_ebus()
	_cleanup_manager_data()


func _on_filesystem_changed() -> void:
	var current_time := FileAccess.get_modified_time(_ps.scene_path)
	if current_time > _last_modified_time:
		_last_modified_time = current_time
		_reload_data()
		_refresh_ui()


func _update_last_modified_time() -> void:
	if FileAccess.file_exists(_ps.scene_path):
		_last_modified_time = FileAccess.get_modified_time(_ps.scene_path)


func _on_dirty_flag_changed(dirty: bool) -> void:
	if dirty:
		_trigger_save()

	_ebus_editor.on_dirty_flag_changed.emit(dirty)


func _on_save_button_button_up() -> void:
	_manager_data.save_data(_ps.scene_path, _ps.scene_data_path)
	# Update the time immediately after saving as it is a self-initiated change
	_update_last_modified_time()


func _trigger_save() -> void:
	if is_inside_tree():
		_save_delay_timer.start()


func _do_save_when_auto() -> void:
	if _ps.auto_save:
		_do_save()


func _do_save() -> void:
	_manager_data.save_data(_ps.scene_path, _ps.scene_data_path)
	_update_last_modified_time()


func _on_category_tab_container_tab_changed(tab: int) -> void:
	var cat_tab: SMgrCategoryGUIBase = _category_tab_cont.get_child(tab)
	_ebus_editor.on_category_selected.emit(cat_tab.get_category_id())


func _do_connect_ebus() -> void:
	_AF.connect_if_not_connected(
		_ebus_ins.get_scene_enums_as_string, _ebus_get_scene_enums_as_string
	)


func _disconnect_ebus() -> void:
	if not _connect_ebus:
		return
	_AF.disconnect_if_connected(
		_ebus_ins.get_scene_enums_as_string, _ebus_get_scene_enums_as_string
	)
	_connect_ebus = false


func _remove_include_path(item: SMgrRemovableItem) -> void:
	var item_ent := item.get_item_string()
	_remove_node_safely(item)

	_manager_data.remove_include_path(item_ent)


func _add_include_item(path: String) -> void:
	var item: SMgrRemovableItem = _INCLUDE_ITEM_SCENE.instantiate()
	item.prepare(path, item)
	_AF.connect_if_not_connected(item.on_remove, _remove_include_path)
	_include_path_list.add_child(item)


func _reload_ui_includes() -> void:
	for child in _include_path_list.get_children():
		_remove_node_safely(child)

	for path in _manager_data.get_data().get_include_list():
		_add_include_item(path)


func _on_category_remove(category_id: int) -> void:
	_manager_data.remove_category(category_id)


func _reload_ui_scenes() -> void:
	var data := _manager_data.get_data()
	var category_ids: Array[int] = [ResourceUID.INVALID_ID]
	category_ids.append_array(data.get_categories_all_ids())

	# Map existing GUI children for easy lookup by category ID
	var existing_guis: Dictionary[int, SMgrCategoryGUIBase] = {}
	for child in _category_tab_cont.get_children():
		var base := child as SMgrCategoryGUIBase
		if base:
			existing_guis[base.get_category_id()] = base

	# Process categories based on the sorted data order
	for i in category_ids.size():
		var id := category_ids[i]
		var cat_gui: SMgrCategoryGUIBase

		if existing_guis.has(id):
			# Update existing instance
			cat_gui = existing_guis[id]
			existing_guis.erase(id)
		else:
			# Instantiate new instance based on category type
			var scene := (
				_PRIMARY_CATEGORY_SCENE
				if id == ResourceUID.INVALID_ID
				else _SECONDARY_CATEGORY_SCENE
			)
			cat_gui = scene.instantiate()
			_category_tab_cont.add_child(cat_gui)
			cat_gui.activate(id)
			_AF.connect_if_not_connected(cat_gui.on_remove, _on_category_remove)
			# The widget handles its own internal updates, so no explicit refresh command is needed here.

		# Ensure the tab order matches the sorted data order
		_category_tab_cont.move_child(cat_gui, i)

	# Remove orphaned GUI components that no longer exist in data
	for orphan in existing_guis.values():
		_remove_node_safely(orphan)


func _refresh_ui() -> void:
	if not is_inside_tree():
		return

	_reload_ui_scenes()
	_reload_ui_includes()


func _cleanup_manager_data() -> void:
	if _manager_data:
		_AF.disconnect_if_connected(_manager_data.data_changed_debounced, _refresh_ui)
		_AF.disconnect_if_connected(_manager_data.on_dirty_flag_changed, _on_dirty_flag_changed)
		_AF.disconnect_if_connected(_manager_data.data_changed_debounced, _on_data_changed)
		_manager_data.cleanup(_ebus_editor)
		_manager_data = null

	if _ps:
		_AF.disconnect_if_connected(_ps.on_enable_log_changed, _init_logger)

	_log = null


func _on_data_changed() -> void:
	_ebus_editor.on_data_changed.emit()


func _reload_data() -> void:
	_cleanup_manager_data()

	_init_logger(_ps.enable_log)
	# Listen for log setting changes to update the logger instance dynamically
	_AF.connect_if_not_connected(_ps.on_enable_log_changed, _init_logger)

	# Check if the directory exists
	var target_dir := _ps.scene_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)
		_log.info("Created data directory at: " + target_dir)

	var raw_data: SMgrData = ResourceLoader.load(_ps.scene_data_path)
	if not raw_data:
		# Creating for the first time
		raw_data = SMgrData.new()
		# Save as a resource and confirm the path
		ResourceSaver.save(raw_data, _ps.scene_data_path)
		_log.info("Created new SMgrData resource at: " + _ps.scene_data_path)

	_manager_data = SMgrDataEditor.new(raw_data, _ebus_editor, _log)

	_manager_data.sync_with_filesystem()
	_update_last_modified_time()
	_AF.connect_if_not_connected(_manager_data.data_changed_debounced, _refresh_ui)
	_AF.connect_if_not_connected(_manager_data.on_dirty_flag_changed, _on_dirty_flag_changed)
	_AF.connect_if_not_connected(_manager_data.data_changed_debounced, _on_data_changed)
	_ebus_editor.on_dirty_flag_changed.emit(false)


func _init_logger(enable: bool) -> void:
	# Re-create the logger instance
	_log = SMgrLogBase.create(enable)
	_log.debug("Logger updated. Enable: %s" % enable)


func _on_file_dialog_button_button_up() -> void:
	_file_dialog.popup_centered(Vector2(600, 600))


func _on_file_dialog_dir_file_selected(path: String) -> void:
	_address_edit.text = path
	_validate_include_path()


func _on_address_text_changed(_new_text: String) -> void:
	_validate_include_path()


func _on_add_include_button_button_up() -> void:
	_manager_data.add_include_path(_address_edit.text)
	_address_edit.text = ""
	_validate_include_path()


func _validate_include_path() -> void:
	var new_text := _address_edit.text
	if new_text != "":
		if (
			DirAccess.dir_exists_absolute(new_text)
			or FileAccess.file_exists(new_text) and new_text.begins_with("res://")
		):
			_add_include_button.disabled = false
		else:
			_add_include_button.disabled = true
	else:
		_add_include_button.disabled = true


func _on_add_category_button_up() -> void:
	if not _category_name_edit.text.is_empty():
		_manager_data.add_category(_category_name_edit.text)
		_category_name_edit.text = ""
		_validate_category_input()


func _on_category_name_text_changed(_new_text: String) -> void:
	_validate_category_input()


func _validate_category_input() -> void:
	_add_category_button.disabled = _category_name_edit.text.is_empty()


func _show_includes_list(show: bool) -> void:
	var icon: Texture2D = _ICON_COLLAPSE_BUTTON if show else _ICON_EXPAND_BUTTON
	_hide_include_button.icon = icon
	_misc_tab.visible = show


func _on_hide_button_up() -> void:
	_ps.includes_visible = not _ps.includes_visible
	_show_includes_list(_ps.includes_visible)


func _on_refresh_button_up() -> void:
	_reload_data()
	_refresh_ui()


func _on_save_delay_timer_timeout() -> void:
	_do_save_when_auto()


# --- Invalid SceneId Detection ---
func _on_check_invalid_ids_button_button_up() -> void:
	_CHK.check_invalid_ids()


func _on_refresh_uid_button_button_up() -> void:
	# Refresh by physical renaming
	_AF.change_resource_uid(_ps.scene_path)
	_AF.change_resource_uid(_ps.scene_data_path)

	_reload_data()
	_refresh_ui()
