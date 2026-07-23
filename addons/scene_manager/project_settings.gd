@tool
class_name SMgrProjectSettings
extends SMgrResource

# ------------- [Signal] -------------
signal on_auto_save_changed(enable: bool)
signal on_enable_log_changed(enable: bool)

# ------------- [Constants] -------------
const DEFAULT_DATA_DIR = "res://scene_manager_data"
const DEFAULT_SCENES_FILENAME = "scenes.gd"
const DEFAULT_PATH_TO_SCENES := DEFAULT_DATA_DIR + "/" + DEFAULT_SCENES_FILENAME
const DEFAULT_SCENES_DATA_FILENAME = "scenes_data.tres"
const DEFAULT_PLAY_OUT_TIME: float = 1
const DEFAULT_PLAY_IN_TIME: float = 1
const DEFAULT_TRANSITION_LAYER: int = 100
const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd


# ------------- [Defines] -------------
# Setting Paths
class Property:
	const SCENE_PATH = "scene_manager/scenes/scenes_path"
	const PLAY_OUT_TIME = "scene_manager/scenes/default_play_out_time"
	const PLAY_IN_TIME = "scene_manager/scenes/default_play_in_time"
	const AUTO_SAVE = "scene_manager/scenes/autosave"
	const INCLUDES_VISIBLE = "scene_manager/scenes/includes_visible"
	const TRANSITION_LAYER = "scene_manager/scenes/transition_layer"
	const ENABLE_LOG = "scene_manager/general/enable_log"


# Dictionary Keys
class Key:
	const KEY = "key"
	const DEFAULT = "default"
	const TYPE = "type"
	const HINT = "hint"
	const HINT_STRING = "hint_string"
	const BASIC = "basic"
	const INTERNAL = "internal"
	const RESTART = "restart"


# ------------- [Static Variable] -------------
static var _property_definitions: Array[Dictionary] = [
	{
		Key.KEY: Property.SCENE_PATH,
		Key.DEFAULT: DEFAULT_PATH_TO_SCENES,
		Key.TYPE: TYPE_STRING,
		Key.HINT: PROPERTY_HINT_FILE,
		Key.HINT_STRING: DEFAULT_SCENES_FILENAME,
		Key.BASIC: true,
		Key.RESTART: true,
	},
	{
		Key.KEY: Property.PLAY_OUT_TIME,
		Key.DEFAULT: DEFAULT_PLAY_OUT_TIME,
		Key.TYPE: TYPE_FLOAT,
		Key.BASIC: true,
	},
	{
		Key.KEY: Property.PLAY_IN_TIME,
		Key.DEFAULT: DEFAULT_PLAY_IN_TIME,
		Key.TYPE: TYPE_FLOAT,
		Key.BASIC: true,
	},
	{
		Key.KEY: Property.AUTO_SAVE,
		Key.DEFAULT: false,
		Key.TYPE: TYPE_BOOL,
		Key.INTERNAL: true,
	},
	{
		Key.KEY: Property.INCLUDES_VISIBLE,
		Key.DEFAULT: true,
		Key.TYPE: TYPE_BOOL,
		Key.INTERNAL: true,
	},
	{
		Key.KEY: Property.TRANSITION_LAYER,
		Key.DEFAULT: DEFAULT_TRANSITION_LAYER,
		Key.TYPE: TYPE_INT,
		Key.BASIC: true,
	},
	{
		Key.KEY: Property.ENABLE_LOG,
		Key.DEFAULT: false,
		Key.TYPE: TYPE_BOOL,
		Key.BASIC: true,
	},
]


# ------------- [Public Variable] -------------
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
			_save()
			_last_auto_save = value
			on_auto_save_changed.emit.call_deferred(value)

var includes_visible: bool:
	get:
		return ProjectSettings.get_setting(Property.INCLUDES_VISIBLE, true)
	set(value):
		if includes_visible != value:
			ProjectSettings.set_setting(Property.INCLUDES_VISIBLE, value)
			_save()

var transition_layer: int:
	get:
		return ProjectSettings.get_setting(Property.TRANSITION_LAYER, DEFAULT_TRANSITION_LAYER)
	set(value):
		if transition_layer != value:
			ProjectSettings.set_setting(Property.TRANSITION_LAYER, value)
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

# ------------- [Private Variable] -------------
var _last_auto_save: bool = false
var _last_enable_log: bool = false


# ------------- [Private Method] -------------
func _ensure_data_dir_exists(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		SMgrUtil.get_log().debug("Created data directory at {0}", [dir_path])


func _save() -> void:
	var error: Error = ProjectSettings.save()
	if error != OK:
		SMgrUtil.get_log().error("SceneManager: Failed to _save ProjectSettings (Error code: {0})", [error])


## Handler to detect changes made to settings from external sources like the Project Settings window
func _on_project_settings_changed() -> void:
	# Check auto_save change
	var current_auto_save := auto_save
	if current_auto_save != _last_auto_save:
		_last_auto_save = current_auto_save
		on_auto_save_changed.emit.call_deferred(current_auto_save)

	# Check enable_log change
	var current_log := enable_log
	if current_log != _last_enable_log:
		_last_enable_log = current_log
		on_enable_log_changed.emit(current_log)


# ------------- [Private Static Method] -------------
## Registers a project setting: checks existence, sets default,
## adds property info for the editor, and sets initial value.
static func _register_setting(
	key: String, type: int, default: Variant,
	hint: int = PROPERTY_HINT_NONE, hint_string: String = ""
) -> void:
	if not ProjectSettings.has_setting(key):
		ProjectSettings.set_setting(key, default)

	var info: Dictionary[String, Variant] = {"name": key, "type": type}
	if hint != PROPERTY_HINT_NONE:
		info["hint"] = hint
	if not hint_string.is_empty():
		info["hint_string"] = hint_string

	ProjectSettings.add_property_info(info)
	ProjectSettings.set_initial_value(key, default)


# ------------- [Public Method] -------------
func setup_project_settings() -> void:
	# Connect signals (monitor direct changes from the editor)
	_AF.connect_if_not_connected(ProjectSettings.settings_changed, _on_project_settings_changed)

	_ensure_data_dir_exists(scene_path.get_base_dir())

	var needs_save: bool = false

	for def: Dictionary in _property_definitions:
		var key: String = def[Key.KEY]

		if not ProjectSettings.has_setting(key):
			needs_save = true

		_register_setting(
			key,
			def[Key.TYPE] as int,
			def[Key.DEFAULT],
			def.get(Key.HINT, PROPERTY_HINT_NONE) as int,
			def.get(Key.HINT_STRING, "") as String,
		)

		# Apply meta flags using type-safe casting
		if def.get(Key.BASIC, false) as bool:
			ProjectSettings.set_as_basic(key, true)
		if def.get(Key.INTERNAL, false) as bool:
			ProjectSettings.set_as_internal(key, true)
		if def.get(Key.RESTART, false) as bool:
			ProjectSettings.set_restart_if_changed(key, true)

	# Cache the initial state
	_last_auto_save = auto_save
	_last_enable_log = enable_log

	if needs_save:
		_save()
