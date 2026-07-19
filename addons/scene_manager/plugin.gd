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
var _main_panel: SMgrMainPanel
var _inspector: EditorInspectorPlugin


# ------------- [Inner Class] -------------
class AutoloadInfo:
	var name: String
	var path: String

	func _init(p_name: String, p_path: String) -> void:
		name = p_name
		path = p_path


# ------------- [Callbacks] -------------
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

	_setup_data_and_autoloads.call_deferred()
	# _setup_editor_panels is called from _finish_setup
	# Autoload registration is done only in _enable_plugin (not on every editor startup)


# Plugin uninstallation
func _exit_tree() -> void:
	remove_custom_type("Auto Complete Assistant")
	if _main_panel:
		EditorInterface.get_editor_main_screen().remove_child(_main_panel)
		_main_panel.queue_free()
		_main_panel = null

	if _inspector:
		remove_inspector_plugin(_inspector)


func _enable_plugin() -> void:
	# Data setup is already scheduled by _enter_tree() via call_deferred.
	# _enable_plugin() is responsible only for registering autoloads.
	_register_autoloads()


func _disable_plugin() -> void:
	_unregister_autoloads()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _main_panel:
		_main_panel.visible = visible


func _get_plugin_name() -> String:
	return MAIN_PANEL_NAME


func _get_plugin_icon() -> Texture2D:
	# Use a standard small editor icon for the toolbar tab button.
	# "Node" is guaranteed to exist in all Godot 4.x EditorIcons themes.
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")


# ------------- [Private Method] -------------
func _setup_editor_panels() -> void:
	if _main_panel:
		return  # Already set up
	_main_panel = MAIN_PANEL_SCENE.instantiate()
	_main_panel.name = MAIN_PANEL_NAME
	_main_panel.prepare(true)

	EditorInterface.get_editor_main_screen().add_child(_main_panel)
	_make_visible(false)

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
			# Ensure target directory exists before copying
			var target_dir := "res://scene_manager_data"
			if not DirAccess.dir_exists_absolute(target_dir):
				DirAccess.make_dir_recursive_absolute(target_dir)

			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var source_path := source_dir.path_join(file_name)
					var target_path := target_dir.path_join(file_name)

					# Copy file using absolute-path-safe static method
					var result := DirAccess.copy_absolute(
						source_path, target_path
					)
					if result != OK:
						push_error(
							(
								"Scene Manager: Failed to copy %s to %s (error: %d)"
								% [source_path, target_path, result]
							)
						)
						return false

					# Reset UID for resource files to avoid conflicts
					if (
						target_path.ends_with(".gd")
						or target_path.ends_with(".tres")
						or target_path.ends_with(".tscn")
					):
						AF.change_resource_uid(target_path)

				file_name = dir.get_next()

			# Start filesystem scan and notify that a scan is required.
			# Guard against double scan (e.g. when called from both
			# _enter_tree deferred and _enable_plugin on first activation).
			var fs := EditorInterface.get_resource_filesystem()
			if not fs.is_scanning():
				fs.scan()
			return true
	return false


func _setup_data_and_autoloads() -> void:
	var needs_scan := _setup_default_data()

	if needs_scan:
		# If scan is required, wait for completion (filesystem_changed) before finishing setup
		var fs := EditorInterface.get_resource_filesystem()
		fs.filesystem_changed.connect(_finish_setup, CONNECT_ONE_SHOT)
	else:
		# If files already exist, finish setup immediately
		_finish_setup()


func _finish_setup() -> void:
	_setup_editor_panels.call_deferred()


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



