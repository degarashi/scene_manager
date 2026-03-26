@tool
extends EditorPlugin

# ------------- [Constants] -------------
const MAIN_PANEL_SCENE = preload("uid://crnf0w0s44hxx")
const MAIN_PANEL_NAME = "Scene Manager"
const AUTOLOAD_PREFIX = "autoload/"
const AF = preload("uid://dlgh4u64a7qxk")

# ------------- [Private Variable] -------------
var _ps := preload("uid://dn6eh4s0h8jhi")
var _main_panel: SMgrMainPanel
var _inspector: EditorInspectorPlugin


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

	get_tree().create_timer(1.0).timeout.connect(_delay)


# Plugin uninstallation
func _exit_tree() -> void:
	# TODO: We can use this function but it removes the saved value of it
	# along side with the gui setting, if you want to actually just
	# restart the plugin, you have to set the value for scenes path again
	#
	# So... not a good idea to use this:
	#
	# ProjectSettings.clear(SCENE_SETTINGS_PROPERTY_NAME)
	#
	# We just don't remove the settings for now
	remove_custom_type("Auto Complete Assistant")
	if _main_panel:
		remove_control_from_docks(_main_panel)
		_main_panel.free()

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
func _delay() -> void:
	# --- main panel ---
	_main_panel = MAIN_PANEL_SCENE.instantiate()
	_main_panel.name = MAIN_PANEL_NAME
	_main_panel.prepare(true)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _main_panel)

	# [scene_inspector_plugin.gd]
	_inspector = preload("uid://duwd2dwcofsrt").new()
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
					var target_path := "res://scene_manager_data".path_join(file_name)

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
		AutoloadInfo.new("SceneManager", "res://addons/scene_manager/scene_manager.tscn"),
	]


func _register_autoloads() -> void:
	for al in _get_autoload_list():
		if not ProjectSettings.has_setting(AUTOLOAD_PREFIX + al.name):
			add_autoload_singleton(al.name, al.path)


func _unregister_autoloads() -> void:
	for al in _get_autoload_list():
		if ProjectSettings.has_setting(AUTOLOAD_PREFIX + al.name):
			remove_autoload_singleton(al.name)
