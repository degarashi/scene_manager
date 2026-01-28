@tool
extends EditorPlugin

const MAIN_PANEL_SCENE = preload("uid://crnf0w0s44hxx")
const MAIN_PANEL_NAME = "Scene Manager"
var _main_panel: SMgrMainPanel
var _plugin: Object


func set_properties_for_setting() -> void:
	ProjectSettings.add_property_info(
		{
			"name": SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME,
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "scenes.gd"
		}
	)

	(
		ProjectSettings
		. add_property_info(
			{
				"name": SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME,
				"type": TYPE_FLOAT,
			}
		)
	)

	(
		ProjectSettings
		. add_property_info(
			{
				"name": SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME,
				"type": TYPE_FLOAT,
			}
		)
	)

	(
		ProjectSettings
		. add_property_info(
			{
				"name": SceneManagerConstants.SETTINGS_AUTO_SAVE_PROPERTY_NAME,
				"type": TYPE_BOOL,
			}
		)
	)

	ProjectSettings.set_initial_value(
		SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME,
		SceneManagerConstants.DEFAULT_PATH_TO_SCENES
	)
	ProjectSettings.set_as_basic(SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME, true)

	ProjectSettings.set_initial_value(
		SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME,
		SceneManagerConstants.DEFAULT_FADE_OUT_TIME
	)
	ProjectSettings.set_as_basic(SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME, true)

	ProjectSettings.set_initial_value(
		SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME,
		SceneManagerConstants.DEFAULT_FADE_IN_TIME
	)
	ProjectSettings.set_as_basic(SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME, true)

	ProjectSettings.set_initial_value(SceneManagerConstants.SETTINGS_AUTO_SAVE_PROPERTY_NAME, false)
	ProjectSettings.set_as_internal(SceneManagerConstants.SETTINGS_AUTO_SAVE_PROPERTY_NAME, true)

	ProjectSettings.set_initial_value(
		SceneManagerConstants.SETTINGS_INCLUDES_VISIBLE_PROPERTY_NAME, true
	)
	ProjectSettings.set_as_internal(
		SceneManagerConstants.SETTINGS_INCLUDES_VISIBLE_PROPERTY_NAME, true
	)

	# Restart is required as path to Scenes singleton has changed
	ProjectSettings.set_restart_if_changed(SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME, true)

	ProjectSettings.save()


# Plugin installation
func _enter_tree():
	# Adding settings property to Project/Settings & loading
	if not ProjectSettings.has_setting(SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME):
		ProjectSettings.set_setting(
			SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME,
			SceneManagerConstants.DEFAULT_PATH_TO_SCENES
		)

	if not ProjectSettings.has_setting(SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME):
		ProjectSettings.set_setting(
			SceneManagerConstants.SETTINGS_FADE_OUT_PROPERTY_NAME,
			SceneManagerConstants.DEFAULT_FADE_OUT_TIME
		)

	if not ProjectSettings.has_setting(SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME):
		ProjectSettings.set_setting(
			SceneManagerConstants.SETTINGS_FADE_IN_PROPERTY_NAME,
			SceneManagerConstants.DEFAULT_FADE_IN_TIME
		)

	if not ProjectSettings.has_setting(SceneManagerConstants.SETTINGS_AUTO_SAVE_PROPERTY_NAME):
		ProjectSettings.set_setting(SceneManagerConstants.SETTINGS_AUTO_SAVE_PROPERTY_NAME, false)

	if not ProjectSettings.has_setting(
		SceneManagerConstants.SETTINGS_INCLUDES_VISIBLE_PROPERTY_NAME
	):
		ProjectSettings.set_setting(
			SceneManagerConstants.SETTINGS_INCLUDES_VISIBLE_PROPERTY_NAME, true
		)

	set_properties_for_setting()

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

	_plugin = preload("res://addons/scene_manager/property_editor/scene_inspector_plugin.gd").new()
	add_inspector_plugin(_plugin)


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

	remove_inspector_plugin(_plugin)


func _enable_plugin() -> void:
	var path_to_scenes := SceneManagerConstants.DEFAULT_PATH_TO_SCENES
	if ProjectSettings.has_setting(SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME):
		path_to_scenes = ProjectSettings.get_setting(
			SceneManagerConstants.SETTINGS_SCENE_PROPERTY_NAME
		)

	add_autoload_singleton("SceneManager", "res://addons/scene_manager/scene_manager.tscn")
	add_autoload_singleton("Scenes", path_to_scenes)


func _disable_plugin() -> void:
	remove_autoload_singleton("SceneManager")
	remove_autoload_singleton("Scenes")
