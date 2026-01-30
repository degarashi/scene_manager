class_name SMgrProjectSettings
extends RefCounted

const DEFAULT_SCENES_FILENAME = "scenes.gd"


# Setting Paths
class Property:
	const SCENE_PATH = "scene_manager/scenes/scenes_path"
	const FADE_OUT_TIME = "scene_manager/scenes/default_fade_out_time"
	const FADE_IN_TIME = "scene_manager/scenes/default_fade_in_time"
	const AUTO_SAVE = "scene_manager/scenes/autosave"
	const INCLUDES_VISIBLE = "scene_manager/scenes/includes_visible"


# Dictionary Keys
class Key:
	const DEFAULT = "default"
	const TYPE = "type"
	const HINT = "hint"
	const HINT_STRING = "hint_string"
	const BASIC = "basic"
	const INTERNAL = "internal"
	const RESTART = "restart"


# Runtime Properties linked to ProjectSettings
static var scene_path: String:
	get:
		return ProjectSettings.get_setting(
			Property.SCENE_PATH, SMgrConstants.DEFAULT_PATH_TO_SCENES
		)
	set(value):
		ProjectSettings.set_setting(Property.SCENE_PATH, value)
		ProjectSettings.save()

static var fade_out_time: float:
	get:
		return ProjectSettings.get_setting(
			Property.FADE_OUT_TIME, SMgrConstants.DEFAULT_FADE_OUT_TIME
		)
	set(value):
		ProjectSettings.set_setting(Property.FADE_OUT_TIME, value)
		ProjectSettings.save()

static var fade_in_time: float:
	get:
		return ProjectSettings.get_setting(
			Property.FADE_IN_TIME, SMgrConstants.DEFAULT_FADE_IN_TIME
		)
	set(value):
		ProjectSettings.set_setting(Property.FADE_IN_TIME, value)
		ProjectSettings.save()

static var auto_save: bool:
	get:
		return ProjectSettings.get_setting(Property.AUTO_SAVE, false)
	set(value):
		ProjectSettings.set_setting(Property.AUTO_SAVE, value)
		ProjectSettings.save()

static var includes_visible: bool:
	get:
		return ProjectSettings.get_setting(Property.INCLUDES_VISIBLE, true)
	set(value):
		ProjectSettings.set_setting(Property.INCLUDES_VISIBLE, value)
		ProjectSettings.save()


static func setup_project_settings() -> void:
	# Structured configuration using constant keys
	var settings: Dictionary[String, Dictionary] = {
		Property.SCENE_PATH:
		{
			Key.DEFAULT: SMgrConstants.DEFAULT_PATH_TO_SCENES,
			Key.TYPE: TYPE_STRING,
			Key.HINT: PROPERTY_HINT_FILE,
			Key.HINT_STRING: DEFAULT_SCENES_FILENAME,
			Key.BASIC: true,
			Key.RESTART: true
		},
		Property.FADE_OUT_TIME:
		{
			Key.DEFAULT: SMgrConstants.DEFAULT_FADE_OUT_TIME,
			Key.TYPE: TYPE_FLOAT,
			Key.BASIC: true,
		},
		Property.FADE_IN_TIME:
		{
			Key.DEFAULT: SMgrConstants.DEFAULT_FADE_IN_TIME,
			Key.TYPE: TYPE_FLOAT,
			Key.BASIC: true,
		},
		Property.AUTO_SAVE:
		{
			Key.DEFAULT: false,
			Key.TYPE: TYPE_BOOL,
			Key.INTERNAL: true,
		},
		Property.INCLUDES_VISIBLE:
		{
			Key.DEFAULT: true,
			Key.TYPE: TYPE_BOOL,
			Key.INTERNAL: true,
		}
	}

	for path: String in settings:
		var s: Dictionary = settings[path]
		var default_val: Variant = s[Key.DEFAULT]
		var type: int = s[Key.TYPE] as int

		# Initialize setting if missing
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, default_val)

		# Prepare property info for editor display (Explicit Dictionary typing)
		var info: Dictionary[String, Variant] = {"name": path, "type": type}

		if s.has(Key.HINT):
			info["hint"] = s[Key.HINT]
		if s.has(Key.HINT_STRING):
			info["hint_string"] = s[Key.HINT_STRING]

		ProjectSettings.add_property_info(info)
		ProjectSettings.set_initial_value(path, default_val)

		# Apply meta flags using type-safe casting
		if s.get(Key.BASIC, false) as bool:
			ProjectSettings.set_as_basic(path, true)
		if s.get(Key.INTERNAL, false) as bool:
			ProjectSettings.set_as_internal(path, true)
		if s.get(Key.RESTART, false) as bool:
			ProjectSettings.set_restart_if_changed(path, true)

	# Persist changes to project.godot
	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("SceneManager: Failed to save ProjectSettings (Error code: %d)" % error)
