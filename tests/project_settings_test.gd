extends GdUnitTestSuite

const SettingsScript = preload("res://addons/scene_manager/project_settings.gd")

const _ALL_SETTING_PATHS: Array[String] = [
	SettingsScript.Property.SCENE_PATH,
	SettingsScript.Property.PLAY_OUT_TIME,
	SettingsScript.Property.PLAY_IN_TIME,
	SettingsScript.Property.AUTO_SAVE,
	SettingsScript.Property.INCLUDES_VISIBLE,
	SettingsScript.Property.TRANSITION_LAYER,
	SettingsScript.Property.ENABLE_LOG,
]


var _settings: SMgrProjectSettings
var _original_values: Dictionary = {}


# ------------- [Setup/Teardown] -------------


func before_test() -> void:
	_settings = SettingsScript.new()
	# Save original state of all settings
	_original_values = {}
	for p: String in _ALL_SETTING_PATHS:
		if ProjectSettings.has_setting(p):
			_original_values[p] = ProjectSettings.get_setting(p)
		else:
			_original_values[p] = null  # mark as absent
	# Reset all settings to their code defaults so each test starts clean
	ProjectSettings.set_setting(SettingsScript.Property.SCENE_PATH, SettingsScript.DEFAULT_PATH_TO_SCENES)
	ProjectSettings.set_setting(SettingsScript.Property.PLAY_OUT_TIME, SettingsScript.DEFAULT_PLAY_OUT_TIME)
	ProjectSettings.set_setting(SettingsScript.Property.PLAY_IN_TIME, SettingsScript.DEFAULT_PLAY_IN_TIME)
	ProjectSettings.set_setting(SettingsScript.Property.AUTO_SAVE, false)
	ProjectSettings.set_setting(SettingsScript.Property.INCLUDES_VISIBLE, true)
	ProjectSettings.set_setting(SettingsScript.Property.TRANSITION_LAYER, SettingsScript.DEFAULT_TRANSITION_LAYER)
	ProjectSettings.set_setting(SettingsScript.Property.ENABLE_LOG, false)


func after_test() -> void:
	# Restore original state of all settings
	for setting_path: String in _ALL_SETTING_PATHS:
		var original_val = _original_values.get(setting_path)
		if original_val != null:
			ProjectSettings.set_setting(setting_path, original_val)
	_settings = null


# ------------- [Default Value Tests] -------------
# These verify that SMgrProjectSettings returns the correct defaults
# when ProjectSettings has been reset to baseline values.


func test_default_scene_path() -> void:
	assert_str(_settings.scene_path).is_equal(SettingsScript.DEFAULT_PATH_TO_SCENES)


func test_default_play_out_time() -> void:
	assert_float(_settings.play_out_time).is_equal(SettingsScript.DEFAULT_PLAY_OUT_TIME)


func test_default_play_in_time() -> void:
	assert_float(_settings.play_in_time).is_equal(SettingsScript.DEFAULT_PLAY_IN_TIME)


func test_default_auto_save() -> void:
	assert_bool(_settings.auto_save).is_false()


func test_default_transition_layer() -> void:
	assert_int(_settings.transition_layer).is_equal(SettingsScript.DEFAULT_TRANSITION_LAYER)


func test_default_enable_log() -> void:
	assert_bool(_settings.enable_log).is_false()


# ------------- [Setter Tests] -------------


func test_set_scene_path() -> void:
	var temp_path := "res://test_data/custom_scenes.gd"
	_settings.scene_path = temp_path
	assert_str(_settings.scene_path).is_equal(temp_path)
	# Ensure the data directory was created
	var data_dir := temp_path.get_base_dir()
	assert_bool(DirAccess.dir_exists_absolute(data_dir)).is_true()


func test_scene_data_path_derived() -> void:
	var temp_path := "res://test_data/custom_scenes.gd"
	_settings.scene_path = temp_path
	var expected := temp_path.get_base_dir().path_join(SettingsScript.DEFAULT_SCENES_DATA_FILENAME)
	assert_str(_settings.scene_data_path).is_equal(expected)


func test_set_play_out_time() -> void:
	var value := 2.5
	_settings.play_out_time = value
	assert_float(_settings.play_out_time).is_equal(value)


func test_set_play_in_time() -> void:
	var value := 0.5
	_settings.play_in_time = value
	assert_float(_settings.play_in_time).is_equal(value)


func test_set_auto_save_emits_signal() -> void:
	_settings.auto_save = true
	# on_auto_save_changed is emitted via call_deferred; await_signal_on waits up to 2s
	await await_signal_on(_settings, "on_auto_save_changed")


func test_set_transition_layer() -> void:
	var value := 200
	_settings.transition_layer = value
	assert_int(_settings.transition_layer).is_equal(value)


func test_set_enable_log_emits_signal() -> void:
	var count := [0]
	_settings.on_enable_log_changed.connect(func(_v: bool) -> void:
		count[0] += 1
	)
	_settings.enable_log = true
	# on_enable_log_changed is emitted immediately (no call_deferred)
	assert_int(count[0]).is_equal(1)


# ------------- [Round-trip Tests] -------------


func test_includes_visible_round_trip() -> void:
	# Default is true
	assert_bool(_settings.includes_visible).is_true()
	# Set false → verify
	_settings.includes_visible = false
	assert_bool(_settings.includes_visible).is_false()
	# Set true → verify
	_settings.includes_visible = true
	assert_bool(_settings.includes_visible).is_true()


# ------------- [Integration Tests] -------------


func test_setup_project_settings() -> void:
	_settings.setup_project_settings()

	for p: String in _ALL_SETTING_PATHS:
		assert_bool(ProjectSettings.has_setting(p)).is_true()
