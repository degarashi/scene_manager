@tool
class_name SMgrMainPanel
extends MarginContainer

# Scene item, include item prefabs
const _INCLUDE_ITEM_SCENE = preload("uid://ciaqe7l3hugns")
const _PRIMARY_SECTION_SCENE = preload("uid://cf1lsul5kbw85")
const _SECONDARY_SECTION_SCENE = preload("uid://y7ksk521w5au")
const _EBUS = preload("uid://ra25t5in8erp")
const _EBUS_I = preload("uid://bnwpfojr6e0dh")
const _C = preload("uid://c3vvdktou45u")
const _ICON_EXPAND_BUTTON = preload("uid://t6iu67x15d3")
const _ICON_COLLAPSE_BUTTON = preload("uid://bd6ob6pgam1gt")

var _ps := preload("uid://dn6eh4s0h8jhi")
var _manager_data: SMgrData
## For file monitoring
var _last_modified_time: int = 0

@onready var _refresh_delay_timer: Timer = %RefreshDelayTimer
@onready var _save_delay_timer: Timer = %SaveDelayTimer

@onready var _section_tab_cont: TabContainer = %section_tab_container

# --- add section ---
@onready var _add_section_button: Button = %add_section_button
@onready var _section_name_edit: LineEdit = %section_name_to_add

# --- include list ---
@onready var _address_edit: LineEdit = %address_edit
@onready var _file_dialog: FileDialog = %file_dialog
@onready var _hide_include_button: Button = %hide_include_button
@onready var _unhide_include_button: Button = %unhide_include_button
@onready var _add_include_button: Button = %add_include_button

@onready var _include_path_list: Control = %include_list
@onready var _include_list_scroll: Container = %include_list_scroll
@onready var _include_add_panel: Container = %include_add_panel

# -- buttons (of bottom) ---
@onready var _refresh_button: Button = %refresh_button
@onready var _garbage_bin: Control = %garbage_bin


func _ready() -> void:
	_reload_data()
	_refresh_ui()

	_show_includes_list(_ps.includes_visible)

	# subscribe to editor file system changes
	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		fs.filesystem_changed.connect(_on_filesystem_changed)

	_update_last_modified_time()


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

	_EBUS.on_dirty_flag_changed.emit(dirty)


func _get_dirty_flag(recv: Array[bool]) -> void:
	assert(recv.is_empty())
	recv.append(_manager_data.get_dirty_flag())


func _on_save_button_button_up() -> void:
	_manager_data.save_data(_ps.scene_path, _ps.scene_data_path)
	# Update the time immediately after saving as it is a self-initiated change
	_update_last_modified_time()


func _trigger_refresh() -> void:
	if is_inside_tree():
		_refresh_delay_timer.start()


func _trigger_save() -> void:
	if is_inside_tree():
		_save_delay_timer.start()


func _do_save_when_auto() -> void:
	if _ps.auto_save:
		_do_save()


func _do_save() -> void:
	_manager_data.save_data(_ps.scene_path, _ps.scene_data_path)
	_update_last_modified_time()


func _get_scenes(recv: Array[SMgrDataScene], section_name: String) -> void:
	assert(recv.is_empty())
	recv.append_array(_manager_data.get_scenes_with_section(section_name))


func _get_scenes_by_type(recv: Array[SMgrDataScene], type: int) -> void:
	assert(recv.is_empty())

	# Sort according to internal data structure,
	# such as 0: all, 1: categorized, 2: uncategorized, etc.
	match type:
		0:
			recv.append_array(_manager_data.get_scenes_all())
		1:
			recv.append_array(_manager_data.get_scenes_categorized())
		2:
			recv.append_array(_manager_data.get_scenes_uncategorized())


func _get_scene_info(recv: Array[SMgrDataScene], uid: int) -> void:
	assert(recv.is_empty())
	recv.append(_manager_data.get_scene_from_uid(uid))


func _has_scene_by_name(recv: Array[bool], scene_name: String) -> void:
	assert(recv.is_empty())
	recv.append(_manager_data.get_scene_by_name(scene_name) != null)


func _change_scene_name(uid: int, scene_name: String) -> void:
	_manager_data.change_scene_name(uid, scene_name)


func _get_scene_enums(recv: Array[String]) -> void:
	assert(recv.is_empty())
	var tmp := _manager_data.get_scenes_all()
	for scene in tmp:
		recv.append(SceneManagerUtils.sanitize_as_enum_string(scene.name))


func connect_ebus() -> void:
	_EBUS.get_scenes.connect(_get_scenes)
	_EBUS.get_scene_info.connect(_get_scene_info)
	# Bind arguments to common methods and connect
	_EBUS.get_scenes_all.connect(_get_scenes_by_type.bind(0))
	_EBUS.get_scenes_categorized.connect(_get_scenes_by_type.bind(1))
	_EBUS.get_scenes_uncategorized.connect(_get_scenes_by_type.bind(2))

	_EBUS.get_section_names.connect(
		func(recv: Array) -> void:
			assert(recv.is_empty())
			recv.append_array(_manager_data.get_sections_list())
	)
	_EBUS.add_scene_to_section.connect(
		func(uid: int, section_name: String) -> void:
			_manager_data.add_scene_to_section(uid, section_name)
	)
	_EBUS.remove_scene_from_section.connect(
		func(uid: int, section_name: String) -> void:
			_manager_data.remove_scene_from_section(uid, section_name)
	)
	_EBUS.has_scene_by_name.connect(_has_scene_by_name)
	_EBUS.change_scene_name.connect(_change_scene_name)
	_EBUS.get_dirty_flag.connect(_get_dirty_flag)
	_EBUS_I.get_scene_enums.connect(_get_scene_enums)


func _remove_include_path(item: SMgrRemovableItem) -> void:
	var item_ent := item.get_item_string()
	item.reparent(_garbage_bin)
	item.queue_free()

	_manager_data.remove_include_path(item_ent)
	_trigger_refresh()


func _add_include_item(path: String) -> void:
	var item: SMgrRemovableItem = _INCLUDE_ITEM_SCENE.instantiate()
	_include_path_list.add_child(item)

	item.set_item_string(path)
	item.on_remove.connect(_remove_include_path)


func _reload_ui_includes() -> void:
	for child in _include_path_list.get_children():
		child.reparent(_garbage_bin)
		child.queue_free()

	for path in _manager_data.get_include_list():
		_add_include_item(path)


func _on_section_remove(section_name: String) -> void:
	_manager_data.remove_section(section_name)


func _reload_ui_scenes() -> void:
	# --- Tabs ---
	for child in _section_tab_cont.get_children():
		child.reparent(_garbage_bin)
		child.queue_free()

	# Obtain and update the scene internally via EventBus
	var prim_sec: SMgrSection = _PRIMARY_SECTION_SCENE.instantiate()
	_section_tab_cont.add_child(prim_sec)
	prim_sec.setup(_C.ALL_SECTION_NAME)
	prim_sec.on_remove.connect(_on_section_remove)

	for section in _manager_data.get_sections_list():
		var sec: SMgrSection = _SECONDARY_SECTION_SCENE.instantiate()
		_section_tab_cont.add_child(sec)
		sec.setup(section)
		sec.on_remove.connect(_on_section_remove)


func _refresh_ui() -> void:
	_reload_ui_scenes()
	_reload_ui_includes()


func _reload_data() -> void:
	if _manager_data:
		_manager_data.data_changed.disconnect(_trigger_refresh)
		_manager_data.on_dirty_flag_changed.disconnect(_on_dirty_flag_changed)

	var path := _ps.scene_data_path
	if ResourceLoader.exists(path):
		_manager_data = ResourceLoader.load(path)
	else:
		# If the file is missing or invalid as a resource
		_manager_data = SMgrData.new()
		_manager_data.save_data(_ps.scene_path, _ps.scene_data_path)

	_update_last_modified_time()

	_manager_data.data_changed.connect(_trigger_refresh)
	_manager_data.on_dirty_flag_changed.connect(_on_dirty_flag_changed)
	_EBUS.on_dirty_flag_changed.emit(false)


func _on_file_dialog_button_button_up() -> void:
	_file_dialog.popup_centered(Vector2(600, 600))


func _on_file_dialog_dir_file_selected(path: String) -> void:
	_address_edit.text = path
	_validate_include_path()


func _on_address_text_changed(_new_text: String) -> void:
	_validate_include_path()


func _on_add_include_button_button_up() -> void:
	if _manager_data.add_include_path(_address_edit.text):
		_trigger_refresh()
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


func _on_add_section_button_up() -> void:
	if not _section_name_edit.text.is_empty():
		_manager_data.add_section(_section_name_edit.text)
		_section_name_edit.text = ""
		_validate_section_input()


func _on_section_name_text_changed(_new_text: String) -> void:
	_validate_section_input()


func _validate_section_input() -> void:
	_add_section_button.disabled = _section_name_edit.text.is_empty()


func _show_includes_list(value: bool) -> void:
	var icon: Texture2D = _ICON_COLLAPSE_BUTTON if value else _ICON_EXPAND_BUTTON
	_hide_include_button.icon = icon
	_unhide_include_button.icon = icon
	_include_list_scroll.visible = value
	_include_add_panel.visible = value
	_unhide_include_button.visible = !value


func _on_hide_button_up() -> void:
	_ps.includes_visible = not _ps.includes_visible
	_show_includes_list(_ps.includes_visible)


func _on_refresh_button_up() -> void:
	_reload_data()
	_refresh_ui()


func _on_save_delay_timer_timeout() -> void:
	_do_save_when_auto()


func _on_refresh_delay_timer_timeout() -> void:
	_refresh_ui()
