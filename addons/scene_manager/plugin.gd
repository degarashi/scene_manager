@tool
extends EditorPlugin

const MAIN_PANEL_SCENE = preload("uid://crnf0w0s44hxx")
const MAIN_PANEL_NAME = "Scene Manager"
var _ps := preload("uid://dn6eh4s0h8jhi")
var _main_panel: SMgrMainPanel
var _inspector: EditorInspectorPlugin


# Plugin installation
func _enter_tree():
	_ps.setup_project_settings()

	add_custom_type(
		"Auto Complete Assistant",
		"Node",
		preload(
			"res://addons/scene_manager/auto_complete_menu_node/scripts/auto_complete_assistant.gd"
		),
		preload("res://addons/scene_manager/icons/line-edit-complete-icon.svg")
	)

	get_tree().create_timer(1.0).timeout.connect(_delay)


func _delay() -> void:
	# --- main panel ---
	_main_panel = MAIN_PANEL_SCENE.instantiate()
	_main_panel.name = MAIN_PANEL_NAME
	_main_panel.connect_ebus()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _main_panel)

	_inspector = (
		preload("res://addons/scene_manager/property_editor/scene_inspector_plugin.gd").new()
	)
	add_inspector_plugin(_inspector)


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
	remove_control_from_docks(_main_panel)
	_main_panel.free()

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


func _setup_default_data() -> bool:
	if not FileAccess.file_exists(_ps.scene_data_path):
		var source_dir: String = "res://addons/scene_manager/default_data/"
		var dir: DirAccess = DirAccess.open(source_dir)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var source_path: String = source_dir.path_join(file_name)
					var target_path: String = "res://".path_join(file_name)

					# Copy file
					dir.copy(source_path, target_path)

					# Reset UID for resource files to avoid conflicts
					if (
						file_name.ends_with(".gd")
						or file_name.ends_with(".tres")
						or file_name.ends_with(".tscn")
					):
						var res: Resource = load(target_path)
						if res:
							# Recognize the resource as a new path and maintain UID consistency
							res.take_over_path(target_path)
							ResourceSaver.save(res, target_path)

				file_name = dir.get_next()

			# Start filesystem scan and notify that a scan is required
			var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
			fs.scan()
			return true
	return false


func _register_autoloads() -> void:
	if not ProjectSettings.has_setting("autoload/SceneManager"):
		add_autoload_singleton("SceneManager", "res://addons/scene_manager/scene_manager.tscn")
	if not ProjectSettings.has_setting("autoload/Scenes"):
		add_autoload_singleton("Scenes", _ps.scene_path)
