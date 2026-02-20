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
## For file monitoring
var _last_modified_time: int = 0
var _connect_ebus: bool = false
var _reg_ent: Array[RegEnt]

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


func _ebus_cb_base(recv: Array, proc: Callable) -> void:
	assert(recv.is_empty())
	recv.append_array(proc.call(_manager_data.get_data()))


func _ebus_get_scenes_all(recv: Array[SMgrDataScene]) -> void:
	_ebus_cb_base(recv, func(mgr): return mgr.get_scenes_all())


func _ebus_get_scenes_categorized(recv: Array[SMgrDataScene]) -> void:
	_ebus_cb_base(recv, func(mgr): return mgr.get_scenes_categorized())


func _ebus_get_scenes_uncategorized(recv: Array[SMgrDataScene]) -> void:
	_ebus_cb_base(recv, func(mgr): return mgr.get_scenes_uncategorized())


func _ebus_get_categories(recv: Array[int]) -> void:
	_ebus_cb_base(recv, func(mgr): return mgr.get_categories_all_ids())


func _ebus_get_category_by_id(recv: Array[SMgrCategoryData], category_id: int) -> void:
	_ebus_cb_base(recv, func(mgr): return [mgr.get_category_from_id(category_id)])


func _ebus_add_scene_to_category(scene_id: int, category_id: int) -> void:
	_manager_data.add_scene_to_category(scene_id, category_id)


func _ebus_remove_scene_from_category(scene_id: int, category_id: int) -> void:
	_manager_data.remove_scene_from_category(scene_id, category_id)


func _ebus_get_scenes(recv: Array[SMgrDataScene], category_id: int) -> void:
	_ebus_cb_base(recv, func(mgr): return mgr.get_scenes_by_category_id(category_id))


func _ebus_get_scene_info(recv: Array[SMgrDataScene], scene_id: int) -> void:
	_ebus_cb_base(recv, func(mgr): return [mgr.get_scene_from_uid(scene_id)])


func _ebus_duplicate_name_check(recv: Array[bool], scene_name: String) -> void:
	_ebus_cb_base(recv, func(mgr): return [mgr.get_scene_by_name(scene_name) != null])


func _ebus_change_scene_name(scene_id: int, scene_name: String) -> void:
	_manager_data.change_scene_name(scene_id, scene_name)


func _ebus_get_scene_enums_as_string(recv: Array[String]) -> void:
	assert(recv.is_empty())
	var scene_all := _manager_data.get_data().get_scenes_all()
	for scene in scene_all:
		recv.append(SceneManagerUtils.sanitize_as_enum_string(scene.name))


func _ebus_get_dirty_flag(recv: Array[bool]) -> void:
	assert(recv.is_empty())
	recv.append(_manager_data.get_dirty_flag())


func _ready() -> void:
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


class RegEnt:
	var sig: Signal
	var proc: Callable

	func _init(p_sig: Signal, p_proc: Callable) -> void:
		sig = p_sig
		proc = p_proc

	func connect_it() -> void:
		sig.connect(proc)

	func disconnect_it() -> void:
		sig.disconnect(proc)


func connect_ebus() -> void:
	_connect_ebus = true
	_reg_ent = [
		RegEnt.new(_ebus_editor.get_scenes, _ebus_get_scenes),
		RegEnt.new(_ebus_editor.get_scene_info, _ebus_get_scene_info),
		RegEnt.new(_ebus_editor.get_scenes_all, _ebus_get_scenes_all),
		RegEnt.new(_ebus_editor.get_scenes_categorized, _ebus_get_scenes_categorized),
		RegEnt.new(_ebus_editor.get_scenes_uncategorized, _ebus_get_scenes_uncategorized),
		RegEnt.new(_ebus_editor.get_categories, _ebus_get_categories),
		RegEnt.new(_ebus_editor.get_category_by_id, _ebus_get_category_by_id),
		RegEnt.new(_ebus_editor.add_scene_to_category, _ebus_add_scene_to_category),
		RegEnt.new(_ebus_editor.remove_scene_from_category, _ebus_remove_scene_from_category),
		RegEnt.new(_ebus_editor.scene_name_duplication_check, _ebus_duplicate_name_check),
		RegEnt.new(_ebus_editor.change_scene_name, _ebus_change_scene_name),
		RegEnt.new(_ebus_editor.get_dirty_flag, _ebus_get_dirty_flag),
		RegEnt.new(_ebus_ins.get_scene_enums_as_string, _ebus_get_scene_enums_as_string)
	]
	for ent in _reg_ent:
		ent.connect_it()


func _disconnect_ebus() -> void:
	if not _connect_ebus:
		return
	for ent in _reg_ent:
		ent.disconnect_it()
	_connect_ebus = false


func _remove_include_path(item: SMgrRemovableItem) -> void:
	var item_ent := item.get_item_string()
	_remove_node_safely(item)

	_manager_data.remove_include_path(item_ent)


func _add_include_item(path: String) -> void:
	var item: SMgrRemovableItem = _INCLUDE_ITEM_SCENE.instantiate()
	item.prepare(path, item)
	item.on_remove.connect(_remove_include_path)
	_include_path_list.add_child(item)


func _reload_ui_includes() -> void:
	for child in _include_path_list.get_children():
		_remove_node_safely(child)

	for path in _manager_data.get_data().get_include_list():
		_add_include_item(path)


func _on_category_remove(category_id: int) -> void:
	_manager_data.remove_category(category_id)


func _reload_ui_scenes() -> void:
	# --- Tabs ---
	for child in _category_tab_cont.get_children():
		_remove_node_safely(child)

	var prim_cat: SMgrCategoryGUIBase = _PRIMARY_CATEGORY_SCENE.instantiate()
	_category_tab_cont.add_child(prim_cat)
	prim_cat.activate(ResourceUID.INVALID_ID)
	prim_cat.on_remove.connect(_on_category_remove)

	for category_id in _manager_data.get_data().get_categories_all_ids():
		var cat: SMgrCategoryGUIBase = _SECONDARY_CATEGORY_SCENE.instantiate()
		_category_tab_cont.add_child(cat)
		cat.activate(category_id)
		cat.on_remove.connect(_on_category_remove)


func _refresh_ui() -> void:
	_reload_ui_scenes()
	_reload_ui_includes()


func _cleanup_manager_data() -> void:
	if _manager_data:
		_manager_data.data_changed_debounced.disconnect(_refresh_ui)
		_manager_data.on_dirty_flag_changed.disconnect(_on_dirty_flag_changed)
		_manager_data.cleanup()
		_manager_data = null


func _reload_data() -> void:
	_cleanup_manager_data()

	var raw_data: SMgrData = ResourceLoader.load(_ps.scene_data_path)
	if not raw_data:
		raw_data = SMgrData.new()
	_manager_data = SMgrDataEditor.new(raw_data)

	_manager_data.sync_with_filesystem()
	_update_last_modified_time()
	_manager_data.data_changed_debounced.connect(_refresh_ui)
	_manager_data.on_dirty_flag_changed.connect(_on_dirty_flag_changed)
	_ebus_editor.on_dirty_flag_changed.emit(false)


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
