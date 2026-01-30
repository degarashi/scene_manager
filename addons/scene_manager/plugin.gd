@tool
extends EditorPlugin

const MAIN_PANEL_SCENE = preload("uid://crnf0w0s44hxx")
const MAIN_PANEL_NAME = "Scene Manager"
var _main_panel: SMgrMainPanel
var _inspector: EditorInspectorPlugin


# Plugin installation
func _enter_tree():
	SMgrProjectSettings.setup_project_settings()

	add_custom_type(
		"Auto Complete Assistant",
		"Node",
		preload(
			"res://addons/scene_manager/auto_complete_menu_node/scripts/auto_complete_assistant.gd"
		),
		preload("res://addons/scene_manager/icons/line-edit-complete-icon.svg")
	)

	# --- main panel ---
	_main_panel = MAIN_PANEL_SCENE.instantiate()
	_main_panel.name = MAIN_PANEL_NAME
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
	var path_to_scenes := SMgrConstants.DEFAULT_PATH_TO_SCENES
	assert(not path_to_scenes.is_empty())

	add_autoload_singleton("SceneManager", "res://addons/scene_manager/scene_manager.tscn")
	add_autoload_singleton("Scenes", path_to_scenes)


func _disable_plugin() -> void:
	remove_autoload_singleton("SceneManager")
	remove_autoload_singleton("Scenes")
