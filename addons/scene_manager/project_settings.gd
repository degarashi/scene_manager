@tool
class_name SMgrProjectSettings
extends SMgrResource

signal on_auto_save_changed(enable: bool)
signal on_enable_log_changed(enable: bool)

const DEFAULT_DATA_DIR = "res://scene_manager_data"
const DEFAULT_SCENES_FILENAME = "scenes.gd"
const DEFAULT_PATH_TO_SCENES := DEFAULT_DATA_DIR + "/" + DEFAULT_SCENES_FILENAME
const DEFAULT_SCENES_DATA_FILENAME = "scenes_data.tres"
const DEFAULT_PLAY_OUT_TIME: float = 1
const DEFAULT_PLAY_IN_TIME: float = 1
const _AF = preload("uid://dlgh4u64a7qxk")


# Setting Paths
class Property:
	const SCENE_PATH = "scene_manager/scenes/scenes_path"
	const PLAY_OUT_TIME = "scene_manager/scenes/default_play_out_time"
	const PLAY_IN_TIME = "scene_manager/scenes/default_play_in_time"
	const AUTO_SAVE = "scene_manager/scenes/autosave"
	const INCLUDES_VISIBLE = "scene_manager/scenes/includes_visible"
	const ENABLE_LOG = "scene_manager/general/enable_log"


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
var scene_path: String:
	get:
		return ProjectSettings.get_setting(Property.SCENE_PATH, DEFAULT_PATH_TO_SCENES)
	set(value):
		if scene_path != value:
			ProjectSettings.set_setting(Property.SCENE_PATH, value)
			_ensure_data_dir_exists(value.get_base_dir())
			_save()

var scene_data_path: String:
	get:
		return scene_path.get_base_dir().path_join(DEFAULT_SCENES_DATA_FILENAME)

var play_out_time: float:
	get:
		return ProjectSettings.get_setting(Property.PLAY_OUT_TIME, DEFAULT_PLAY_OUT_TIME)
	set(value):
		if play_out_time != value:
			ProjectSettings.set_setting(Property.PLAY_OUT_TIME, value)
			_save()

var play_in_time: float:
	get:
		return ProjectSettings.get_setting(Property.PLAY_IN_TIME, DEFAULT_PLAY_IN_TIME)
	set(value):
		if play_in_time != value:
			ProjectSettings.set_setting(Property.PLAY_IN_TIME, value)
			_save()

var auto_save: bool:
	get:
		return ProjectSettings.get_setting(Property.AUTO_SAVE, false)
	set(value):
		if auto_save != value:
			ProjectSettings.set_setting(Property.AUTO_SAVE, value)
			# force _save only the "auto _save" value
			_save()
			on_auto_save_changed.emit.call_deferred(value)

var includes_visible: bool:
	get:
		return ProjectSettings.get_setting(Property.INCLUDES_VISIBLE, true)
	set(value):
		if includes_visible != value:
			ProjectSettings.set_setting(Property.INCLUDES_VISIBLE, value)
			_save()

var enable_log: bool:
	get:
		return ProjectSettings.get_setting(Property.ENABLE_LOG, false)
	set(value):
		if enable_log != value:
			ProjectSettings.set_setting(Property.ENABLE_LOG, value)
			_save()
			_last_enable_log = value
			on_enable_log_changed.emit(value)

var _last_enable_log: bool = false


func _ensure_data_dir_exists(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		print("Scene Manager: Created data directory at ", dir_path)


func _save() -> void:
	var error: Error = ProjectSettings.save()
	if error != OK:
		push_error("SceneManager: Failed to _save ProjectSettings (Error code: %d)" % error)


## Handler to detect changes made to settings from external sources like the Project Settings window
func _on_project_settings_changed() -> void:
	var current_log := enable_log
	if current_log != _last_enable_log:
		_last_enable_log = current_log
		on_enable_log_changed.emit(current_log)


func setup_project_settings() -> void:
	# Connect signals (monitor direct changes from the editor)
	_AF.connect_if_not_connected(ProjectSettings.settings_changed, _on_project_settings_changed)

	_ensure_data_dir_exists(scene_path.get_base_dir())
	# Structured configuration using constant keys
	var settings: Dictionary[String, Dictionary] = {
		Property.SCENE_PATH:
		{
			Key.DEFAULT: DEFAULT_PATH_TO_SCENES,
			Key.TYPE: TYPE_STRING,
			Key.HINT: PROPERTY_HINT_FILE,
			Key.HINT_STRING: DEFAULT_SCENES_FILENAME,
			Key.BASIC: true,
			Key.RESTART: true
		},
		Property.PLAY_OUT_TIME:
		{
			Key.DEFAULT: DEFAULT_PLAY_OUT_TIME,
			Key.TYPE: TYPE_FLOAT,
			Key.BASIC: true,
		},
		Property.PLAY_IN_TIME:
		{
			Key.DEFAULT: DEFAULT_PLAY_IN_TIME,
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
		},
		Property.ENABLE_LOG:
		{
			Key.DEFAULT: false,
			Key.TYPE: TYPE_BOOL,
			Key.BASIC: true,
		}
	}

	var needs_save: bool = false

	for path: String in settings:
		var s: Dictionary = settings[path]
		var default_val: Variant = s[Key.DEFAULT]
		var type: int = s[Key.TYPE] as int

		# Initialize setting if missing
		if not ProjectSettings.has_setting(path):
			ProjectSettings.set_setting(path, default_val)
			needs_save = true

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

	# Cache the initial state
	_last_enable_log = enable_log

	if needs_save:
		_save()
