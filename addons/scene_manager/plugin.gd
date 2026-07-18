@tool
extends EditorPlugin

# ------------- [Constants] -------------
const MAIN_PANEL_SCENE = preload("uid://crnf0w0s44hxx")  # main_panel.tscn
const MAIN_PANEL_NAME = "Scene Manager"
const AUTOLOAD_PREFIX = "autoload/"
const AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd
const _EBUS_EDITOR = preload(
	"res://addons/scene_manager/editor/event_bus/ebus_editor.tres"
)

# ------------- [Private Variable] -------------
var _ps := preload("uid://dn6eh4s0h8jhi")  # project_settings.tres
var _dock: EditorDock
var _main_panel: SMgrMainPanel
var _inspector: EditorInspectorPlugin
var _dirty_tab_icon: Texture2D


# ------------- [Inner Class] -------------
class AutoloadInfo:
	var name: String
	var path: String

	func _init(p_name: String, p_path: String) -> void:
		name = p_name
		path = p_path


# ------------- [Godot-Callback] -------------
# Plugin installation
func _enter_tree() -> void:
	_ps.setup_project_settings()

	add_custom_type(
		"Auto Complete Assistant",
		"Node",
		# [auto_complete_assistant.gd]
		preload("uid://btabfwj4vodlm"),
		# [line-edit-complete-icon.svg]
		preload("uid://cpepbcd57iype")
	)

	_setup_editor_panels.call_deferred()


# Plugin uninstallation
func _exit_tree() -> void:
	# We intentionally do not clear SCENE_SETTINGS_PROPERTY_NAME from ProjectSettings
	# to preserve the user's configuration when the plugin is merely toggled or restarted.
	AF.disconnect_if_connected(
		_EBUS_EDITOR.on_dirty_flag_changed, _on_tab_dirty_changed
	)
	remove_custom_type("Auto Complete Assistant")
	if _dock:
		remove_dock(_dock)
		_dock.queue_free()
		_dock = null

	if _inspector:
		remove_inspector_plugin(_inspector)


func _enable_plugin() -> void:
	# Attempt setup first
	var needs_scan := _setup_default_data()

	if needs_scan:
		# If scan is required, wait for completion (filesystem_changed) before registering autoloads
		var fs := EditorInterface.get_resource_filesystem()
		fs.filesystem_changed.connect(_register_autoloads, CONNECT_ONE_SHOT)
	else:
		# If files already exist, register immediately
		_register_autoloads()


func _disable_plugin() -> void:
	_unregister_autoloads()


# ------------- [Private Method] -------------
func _setup_editor_panels() -> void:
	_main_panel = MAIN_PANEL_SCENE.instantiate()
	_main_panel.name = MAIN_PANEL_NAME
	_main_panel.prepare(true)

	# Wrap the main panel in an EditorDock (Godot 4.7+ API).
	# EditorDock.title is dynamically updated, unlike the deprecated
	# add_control_to_dock approach which derived the tab title from the
	# control's name and was not reliably refreshed at runtime.
	_dock = EditorDock.new()
	_dock.title = MAIN_PANEL_NAME
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_dock.add_child(_main_panel)
	add_dock(_dock)

	# Connect to the dirty flag to show unsaved indicator on the dock tab.
	# The data layer suppresses dirty=true during its initial watcher scan,
	# so we don't need to defer the connection here.
	AF.connect_if_not_connected(
		_EBUS_EDITOR.on_dirty_flag_changed, _on_tab_dirty_changed
	)

	_inspector = preload("uid://duwd2dwcofsrt").new()  # scene_inspector_plugin.gd
	add_inspector_plugin(_inspector)


func _setup_default_data() -> bool:
	if (
		not FileAccess.file_exists(_ps.scene_data_path)
		or not FileAccess.file_exists(_ps.scene_path)
	):
		var source_dir := "res://addons/scene_manager/default_data/"
		var dir := DirAccess.open(source_dir)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var source_path := source_dir.path_join(file_name)
					var target_path := "res://scene_manager_data".path_join(
						file_name
					)

					# Copy file
					dir.copy(source_path, target_path)

					# Reset UID for resource files to avoid conflicts
					if (
						target_path.ends_with(".gd")
						or target_path.ends_with(".tres")
						or target_path.ends_with(".tscn")
					):
						AF.change_resource_uid(target_path)

				file_name = dir.get_next()

			# Start filesystem scan and notify that a scan is required
			var fs := EditorInterface.get_resource_filesystem()
			fs.scan()
			return true
	return false


func _get_autoload_list() -> Array[AutoloadInfo]:
	return [
		AutoloadInfo.new("Scenes", _ps.scene_path),
		AutoloadInfo.new(
			"SceneManager", "res://addons/scene_manager/scene_manager.tscn"
		),
	]


func _register_autoloads() -> void:
	for al in _get_autoload_list():
		if not ProjectSettings.has_setting(AUTOLOAD_PREFIX + al.name):
			add_autoload_singleton(al.name, al.path)


func _unregister_autoloads() -> void:
	for al in _get_autoload_list():
		if ProjectSettings.has_setting(AUTOLOAD_PREFIX + al.name):
			remove_autoload_singleton(al.name)


## Creates a small orange indicator icon for the dirty tab marker.
## Returns a cached 8x16 ImageTexture with a 3px-wide orange bar on the left.
func _get_dirty_tab_icon() -> Texture2D:
	if _dirty_tab_icon:
		return _dirty_tab_icon
	var img := Image.create(8, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var orange := Color(1.0, 0.6, 0.0, 1.0)
	for y in range(16):
		for x in range(3):
			img.set_pixel(x, y, orange)
	_dirty_tab_icon = ImageTexture.create_from_image(img)
	return _dirty_tab_icon


## Called when the unsaved-changes flag changes.
## Updates the EditorDock title with "(*)" suffix and the dock icon when dirty,
## so the user can see at a glance whether there are unsaved edits.
func _on_tab_dirty_changed(dirty: bool) -> void:
	if not _dock:
		return
	_dock.title = MAIN_PANEL_NAME + " (*)" if dirty else MAIN_PANEL_NAME
	_dock.dock_icon = _get_dirty_tab_icon() if dirty else null
