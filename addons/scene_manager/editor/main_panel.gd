@tool
class_name SMgrMainPanel
extends MarginContainer

# Scene item, include item prefabs
const _INCLUDE_ITEM_SCENE = preload("uid://ciaqe7l3hugns")  # removable_item.tscn
const _PRIMARY_CATEGORY_SCENE = preload("uid://cf1lsul5kbw85")  # primary_category.tscn
const _SECONDARY_CATEGORY_SCENE = preload("uid://y7ksk521w5au")  # secondary_category.tscn
const _C = preload("uid://c3vvdktou45u")  # scene_manager_constants.gd
const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd
const DFileWatcher := preload("uid://2u0usajy085y")  # DFileWatch
const _CHK = preload("uid://bfsxxd1vc4jm7")  # check_ids.gd


@export var _ebus_editor: SMgrEbusEditor
@export var _ebus_ins: SMgrEbusInspector
var _ps := preload("uid://dn6eh4s0h8jhi")  # project_settings.tres
var _manager_data: SMgrDataEditor
var _log: DLoggerClass
var _search_debouncer: Debouncer
## For file monitoring
var _scene_file_watcher: FEWFileWatcher
var _connect_ebus: bool = false

@onready var _save_delay_timer: Timer = %SaveDelayTimer

@onready var _category_tab_cont: TabContainer = %CategoryTabContainer

# --- add category ---
@onready var _add_category_button: Button = %AddCategoryButton
@onready var _category_name_edit: LineEdit = %CategoryNameToAdd

# --- include list ---
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _file_dialog: FileDialog = %FileDialog

@onready var _add_include_button: Button = %AddIncludeButton

@onready var _include_path_list: Control = %IncludeList
@onready var _misc_tab: TabContainer = %MiscTab

@onready var _garbage_bin: Control = %GarbageBin

# --- Preview ---
@onready var _preview_image: TextureRect = %PreviewImage
@onready var _sub_viewport: SubViewport = %SubViewport
@onready var _play_transition_button: Button = %PlayTransitionButton
@onready var _search_bar: LineEdit = %search_bar
@onready var _notification_dialog: AcceptDialog = %NotificationDialog

# --- Drop Data ---
@onready var _drop_confirm_dialog: ConfirmationDialog = %DropConfirmDialog
var _pending_drop_files: Array[String] = []

var _selected_scene_id: int = ResourceUID.INVALID_ID


func _ebus_get_scene_enums_as_string(recv: Array[String]) -> void:
	var scene_all := _manager_data.get_data().get_scenes_all()
	for scene in scene_all:
		recv.append(SMgrUtil.sanitize_as_enum_string(scene.name))


func prepare(conn_ebus: bool) -> void:
	_connect_ebus = conn_ebus


func _ready() -> void:
	if _connect_ebus:
		_do_connect_ebus()

	_reload_data()
	_refresh_ui()

	# Setup drop confirmation dialog
	var add_include_btn := _drop_confirm_dialog.add_button(
		"Add Directory", false, "add_include"
	)
	add_include_btn.button_up.connect(_on_drop_confirm_add_include)
	_drop_confirm_dialog.confirmed.connect(_on_drop_confirm_register_only)
	_drop_confirm_dialog.canceled.connect(_on_drop_confirm_canceled)

	# subscribe to editor file system changes
	if Engine.is_editor_hint():
		_scene_file_watcher = DFileWatcher.new(
			get_tree(),
			func() -> PackedStringArray:
				return PackedStringArray([_ps.scene_path])
		)
		_scene_file_watcher.files_changed.connect(_on_scene_file_changed)

	_search_bar.text_changed.connect(_on_search_text_changed)

	_search_debouncer = Debouncer.new(0.15)
	_search_debouncer.timeout.connect(_do_search)
	add_child(_search_debouncer)


func _remove_node_safely(node: Node) -> void:
	node.reparent(_garbage_bin)
	node.queue_free()


func _exit_tree() -> void:
	_disconnect_ebus()
	_cleanup_manager_data()
	if _scene_file_watcher:
		_scene_file_watcher.destroy()
		_scene_file_watcher = null


func _on_scene_file_changed(_files: PackedStringArray) -> void:
	_reload_data()
	_refresh_ui()


func _on_dirty_flag_changed(dirty: bool) -> void:
	if dirty:
		_trigger_save()

	_ebus_editor.on_dirty_flag_changed.emit(dirty)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if (
		typeof(data) == TYPE_DICTIONARY
		and data.has("type")
		and data["type"] == "files"
	):
		var files: Array = data["files"]
		for file in files:
			if file.ends_with(".tscn"):
				return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_pending_drop_files.clear()
	var files: Array = data["files"]
	for file in files:
		if file.ends_with(".tscn"):
			_pending_drop_files.append(file)

	if not _pending_drop_files.is_empty():
		_drop_confirm_dialog.dialog_text = (
			"How would you like to register {0} dropped scenes?"
			. format([_pending_drop_files.size()])
		)
		_drop_confirm_dialog.popup_centered()


func _on_drop_confirm_register_only() -> void:
	var added_count := 0
	for file in _pending_drop_files:
		if _manager_data.add_include_path(file):
			added_count += 1

	if added_count > 0:
		_log.info(
			"Registered {0} scenes as individual include paths.".format(
				[added_count]
			)
		)
		_refresh_ui()
	_pending_drop_files.clear()


func _on_drop_confirm_add_include() -> void:
	# Extract unique directories from pending files
	var dirs: Dictionary[String, bool] = {}
	for file in _pending_drop_files:
		dirs[file.get_base_dir()] = true

	var added_dirs := 0
	for dir in dirs.keys():
		if _manager_data.add_include_path(dir):
			added_dirs += 1

	if added_dirs > 0:
		_log.info(
			"Added {0} directories to include paths.".format([added_dirs])
		)
		_refresh_ui()

	_drop_confirm_dialog.hide()
	_pending_drop_files.clear()


func _on_drop_confirm_canceled() -> void:
	_pending_drop_files.clear()


func _on_save_button_button_up() -> void:
	_do_save()


func _trigger_save() -> void:
	if is_inside_tree():
		_save_delay_timer.start()


func _do_save_when_auto() -> void:
	if _ps.auto_save:
		_do_save()


func _do_save() -> void:
	if _scene_file_watcher:
		_scene_file_watcher.set_syncing(true)
	_manager_data.save_data(_ps.scene_path, _ps.scene_data_path)
	if _scene_file_watcher:
		_scene_file_watcher.update_watched_state()
		_scene_file_watcher.set_syncing(false)


func _on_category_tab_container_tab_changed(tab: int) -> void:
	var cat_tab: SMgrCategoryGUIBase = _category_tab_cont.get_child(tab)
	_ebus_editor.on_category_selected.emit(cat_tab.get_category_id())


func _do_connect_ebus() -> void:
	_AF.connect_if_not_connected(
		_ebus_ins.get_scene_enums_as_string, _ebus_get_scene_enums_as_string
	)
	_AF.connect_if_not_connected(
		_ebus_editor.on_scene_selected, _on_scene_selected
	)
	_AF.connect_if_not_connected(
		_play_transition_button.button_up, _on_play_transition_button_up
	)


func _disconnect_ebus() -> void:
	if not _connect_ebus:
		return
	_AF.disconnect_if_connected(
		_ebus_ins.get_scene_enums_as_string, _ebus_get_scene_enums_as_string
	)
	_AF.disconnect_if_connected(
		_ebus_editor.on_scene_selected, _on_scene_selected
	)
	_AF.disconnect_if_connected(
		_play_transition_button.button_up, _on_play_transition_button_up
	)
	_connect_ebus = false


func _on_scene_selected(scene_id: int) -> void:
	_selected_scene_id = scene_id
	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scene_info.emit(recv, scene_id)
	if recv.is_empty():
		return
	var info := recv[0]

	# Request large preview for the Preview tab
	var previewer := EditorInterface.get_resource_previewer()
	previewer.queue_resource_preview(info.path, self, "_on_preview_ready", null)

	# Check if it might be a transitioner
	var scene := load(info.path) as PackedScene
	if scene:
		var state := scene.get_state()
		var node_type := state.get_node_type(0)
		var is_transitioner := ClassDB.is_parent_class(
			node_type, &"ScreenTransitioner"
		)

		# If node type is a generic engine type (e.g. "Node"), check script inheritance
		if not is_transitioner:
			is_transitioner = _root_extends_screen_transitioner(state)

		_play_transition_button.disabled = not is_transitioner


## Check if the root node's script (or any base script) has class_name ScreenTransitioner.
## This catches scenes where the root node uses a generic engine type but has
## a ScreenTransitioner subclass script attached (e.g. FadeTransitioner on type="Node").
func _root_extends_screen_transitioner(state: SceneState) -> bool:
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"script":
			var script_val := state.get_node_property_value(0, i)
			var scr := script_val as Script
			if not scr and typeof(script_val) == TYPE_STRING:
				scr = load(script_val)
			if not scr:
				return false

			var current: Script = scr
			while current:
				if current.get_global_name() == &"ScreenTransitioner":
					return true
				current = current.get_base_script()
			return false

	return false


func _on_preview_ready(
	path: String,
	preview: Texture2D,
	_thumbnail_preview: Texture2D,
	_userdata: Variant
) -> void:
	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scene_info.emit(recv, _selected_scene_id)
	if not recv.is_empty() and recv[0].path == path:
		_preview_image.texture = preview


func _on_play_transition_button_up() -> void:
	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scene_info.emit(recv, _selected_scene_id)
	if recv.is_empty():
		return
	var info := recv[0]

	var scene_res := load(info.path) as PackedScene
	if not scene_res:
		return

	# Cleanup previous preview
	for child in _sub_viewport.get_children():
		if child != _preview_image:
			child.queue_free()

	var instance := scene_res.instantiate()
	if instance is ScreenTransitioner:
		_sub_viewport.add_child(instance)
		_preview_image.visible = false
		await instance.play_out(1.0)
		await instance.play_in(1.0)
		_preview_image.visible = true
		instance.queue_free()
	else:
		_log.warn("Scene is not a ScreenTransitioner.")
		_notification_dialog.dialog_text = (
			"The selected scene does not inherit from ScreenTransitioner.\n"
			+ "Inheriting from the ScreenTransitioner class is required for preview playback."
		)
		_notification_dialog.popup_centered()
		instance.free()


func _remove_include_path(item: SMgrRemovableItem) -> void:
	var item_ent := item.get_item_string()
	_remove_node_safely(item)

	_manager_data.remove_include_path(item_ent)


func _add_include_item(path: String, count: int) -> void:
	var item: SMgrRemovableItem = _INCLUDE_ITEM_SCENE.instantiate()
	item.prepare(path, item)
	item.set_count(count)
	_AF.connect_if_not_connected(item.on_remove, _remove_include_path)

	# Setup category dropdown
	var data := _manager_data.get_data()
	var categories := data.get_categories_list()
	var current_category_id := data.get_include_path_category(path)
	item.setup_category_dropdown(categories, current_category_id)
	_AF.connect_if_not_connected(
		item.on_category_changed, _on_include_category_changed
	)

	_include_path_list.add_child(item)


func _on_include_category_changed(path: String, category_id: int) -> void:
	# Get the old category ID to remove from scenes
	var data := _manager_data.get_data()
	var old_category_id := data.get_include_path_category(path)

	# Update the mapping
	_manager_data.set_include_path_category(path, category_id)

	# Remove old category from scenes under this path
	if old_category_id != ResourceUID.INVALID_ID:
		_manager_data.remove_category_from_include_scenes(path, old_category_id)

	# Assign new category to scenes under this path
	# Use _is_valid_category_id to guard against invalid IDs (0 or INVALID_ID)
	if _is_valid_category_id(category_id):
		_manager_data.assign_category_to_include_scenes(path, category_id)


## Returns true if category_id is a valid, existing category ID.
## Guards against ResourceUID.INVALID_ID (none) and 0 (which can occur
## when OptionButton metadata truncates large negative values).
func _is_valid_category_id(category_id: int) -> bool:
	if category_id == ResourceUID.INVALID_ID:
		return false
	if category_id == 0:
		return false
	return _manager_data.get_data().get_category_from_id(category_id) != null


func _reload_ui_includes() -> void:
	for child in _include_path_list.get_children():
		_remove_node_safely(child)

	var data := _manager_data.get_data()
	var all_scenes := data.get_scenes_all()

	for path in data.get_include_list():
		var count := 0
		for sc in all_scenes:
			if sc.path.begins_with(path):
				count += 1
		_add_include_item(path, count)


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
			cat_gui.set_search_filter(_search_bar.text)
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
		_AF.disconnect_if_connected(
			_manager_data.data_changed_debounced, _refresh_ui
		)
		_AF.disconnect_if_connected(
			_manager_data.on_dirty_flag_changed, _on_dirty_flag_changed
		)
		_AF.disconnect_if_connected(
			_manager_data.data_changed_debounced, _on_data_changed
		)
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
	if _scene_file_watcher:
		_scene_file_watcher.update_watched_state()
	_AF.connect_if_not_connected(
		_manager_data.data_changed_debounced, _refresh_ui
	)
	_AF.connect_if_not_connected(
		_manager_data.on_dirty_flag_changed, _on_dirty_flag_changed
	)
	_AF.connect_if_not_connected(
		_manager_data.data_changed_debounced, _on_data_changed
	)
	_ebus_editor.on_dirty_flag_changed.emit(false)


func _init_logger(enable: bool) -> void:
	# Re-create the logger instance
	_log = DLoggerClass.new(
		"Scene Manager",
		(
			DLoggerConstants.LogLevel.DEBUG
			if enable
			else DLoggerConstants.LogLevel.ERROR
		),
		enable
	)
	_log.debug("Logger updated. Enable: {0}", [enable])
	if _manager_data:
		_manager_data.set_logger(_log)


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
		if _AF.is_valid_resource_path(new_text):
			_add_include_button.disabled = false
			_address_edit.remove_theme_color_override("font_color")
		else:
			_add_include_button.disabled = true
			_address_edit.add_theme_color_override("font_color", Color.RED)
	else:
		_add_include_button.disabled = true
		_address_edit.remove_theme_color_override("font_color")


func _on_add_category_button_up() -> void:
	if not _category_name_edit.text.is_empty():
		_manager_data.add_category(_category_name_edit.text)
		_category_name_edit.text = ""
		_validate_category_input()


func _on_category_name_text_changed(_new_text: String) -> void:
	_validate_category_input()


func _validate_category_input() -> void:
	_add_category_button.disabled = _category_name_edit.text.is_empty()





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


func _on_search_text_changed(_new_text: String) -> void:
	_search_debouncer.call_debounced()


func _do_search() -> void:
	var filter := _search_bar.text
	for child in _category_tab_cont.get_children():
		var cat_gui := child as SMgrCategoryGUIBase
		if cat_gui:
			cat_gui.set_search_filter(filter)
