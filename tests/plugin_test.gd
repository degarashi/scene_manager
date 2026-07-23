extends GdUnitTestSuite

## Tests for addons/scene_manager/plugin.gd — the EditorPlugin class.
## Tests constants, inner classes, and instance methods in isolation
## without requiring the actual Godot editor to be available.

const PluginScript = preload("res://addons/scene_manager/plugin.gd")

# Instance used for testing instance methods (typed loosely to allow
# calling custom plugin methods without EditorPlugin type restrictions).
var _plugin


func before_test() -> void:
	_plugin = PluginScript.new()


func after_test() -> void:
	if is_instance_valid(_plugin):
		@warning_ignore("unsafe_method_access")
		_plugin.queue_free()
		_plugin = null


# ------------- [Constants Tests] -------------


func test_constants_main_panel_name() -> void:
	assert_str(PluginScript.MAIN_PANEL_NAME).is_equal("Scene Manager")


func test_constants_autoload_prefix() -> void:
	assert_str(PluginScript.AUTOLOAD_PREFIX).is_equal("autoload/")


# ------------- [Inner Class: AutoloadInfo] -------------


func test_autoload_info_init_stores_name_and_path() -> void:
	var scenes_path := "res://scene_manager_data/scenes.gd"
	@warning_ignore("unsafe_method_access")
	var info := PluginScript.AutoloadInfo.new("Scenes", scenes_path)
	assert_str(info.name).is_equal("Scenes")
	assert_str(info.path).is_equal(scenes_path)


func test_autoload_info_init_with_empty_strings() -> void:
	@warning_ignore("unsafe_method_access")
	var info := PluginScript.AutoloadInfo.new("", "")
	assert_str(info.name).is_empty()
	assert_str(info.path).is_empty()


# ------------- [Instance Methods: Simple Queries] -------------


func test_get_plugin_name() -> void:
	if _plugin == null:
		return
	@warning_ignore("unsafe_method_access")
	var name: String = _plugin._get_plugin_name()
	assert_str(name).is_equal("Scene Manager")


func test_has_main_screen() -> void:
	if _plugin == null:
		return
	@warning_ignore("unsafe_method_access")
	var has: bool = _plugin._has_main_screen()
	assert_bool(has).is_true()


# ------------- [_get_autoload_list] -------------


func test_get_autoload_list_returns_array() -> void:
	if _plugin == null:
		return
	@warning_ignore("unsafe_method_access")
	var list: Array = _plugin._get_autoload_list()
	assert_array(list).is_not_null()
	assert_int(list.size()).is_equal(2)


func test_get_autoload_list_first_entry_scenes() -> void:
	if _plugin == null:
		return
	@warning_ignore("unsafe_method_access")
	var list: Array = _plugin._get_autoload_list()
	assert_str(list[0].name).is_equal("Scenes")
	@warning_ignore("unsafe_property_access", "unsafe_method_access")
	assert_bool(list[0].path.ends_with(".gd")).is_true()


func test_get_autoload_list_second_entry_scene_manager() -> void:
	if _plugin == null:
		return
	var expected_path := "res://addons/scene_manager/scene_manager.tscn"
	@warning_ignore("unsafe_method_access")
	var list: Array = _plugin._get_autoload_list()
	assert_str(list[1].name).is_equal("SceneManager")
	assert_str(list[1].path).is_equal(expected_path)


func test_get_autoload_list_entries_have_valid_paths() -> void:
	if _plugin == null:
		return
	@warning_ignore("unsafe_method_access")
	var list: Array = _plugin._get_autoload_list()
	for entry: PluginScript.AutoloadInfo in list:
		assert_bool(not entry.path.is_empty()).is_true()
		# Path must start with res:// to be a valid Godot resource path
		assert_str(entry.path).starts_with("res://")


# ------------- [_register_autoloads] -------------


func test_register_autoloads_adds_both_to_settings() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_true()
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_true()


func test_register_autoloads_stores_correct_paths() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	@warning_ignore("unsafe_method_access")
	var list: Array = _plugin._get_autoload_list()
	for entry: PluginScript.AutoloadInfo in list:
		var key: String = "autoload/" + entry.name
		assert_bool(ProjectSettings.has_setting(key)).is_true()
		var stored: Variant = ProjectSettings.get_setting(key)
		assert_str(stored).is_equal(entry.path)


func test_register_autoloads_is_idempotent() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	# Second registration must not throw or duplicate
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_true()
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_true()


func test_register_autoloads_skips_if_already_exists() -> void:
	if _plugin == null:
		return
	# Pre-set one autoload to verify skipping
	_clean_autoloads()
	ProjectSettings.set_setting("autoload/Scenes", "res://pre_existing.gd")
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	# Scenes was already set, should keep pre-existing value
	var stored: Variant = ProjectSettings.get_setting("autoload/Scenes")
	assert_str(stored).is_equal("res://pre_existing.gd")
	# SceneManager should still be registered
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_true()


# ------------- [_unregister_autoloads] -------------


func test_unregister_autoloads_removes_both() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._unregister_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_false()
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_false()


func test_unregister_autoloads_is_idempotent() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	# First call on clean state
	@warning_ignore("unsafe_method_access")
	_plugin._unregister_autoloads()
	# Second call must not throw
	@warning_ignore("unsafe_method_access")
	_plugin._unregister_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_false()


# ------------- [_enable_plugin] -------------


func test_enable_plugin_registers_autoloads() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._enable_plugin()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_true()
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_true()


func test_enable_plugin_is_idempotent() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._enable_plugin()
	@warning_ignore("unsafe_method_access")
	_plugin._enable_plugin()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_true()


# ------------- [_disable_plugin] -------------


func test_disable_plugin_unregisters_autoloads() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	# Register first so there's something to unregister
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._disable_plugin()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_false()
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_false()


func test_disable_plugin_on_clean_state_is_safe() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	# Calling _disable_plugin when nothing was registered must not error
	@warning_ignore("unsafe_method_access")
	_plugin._disable_plugin()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_false()


# ------------- [Round-trip: register → unregister] -------------


func test_register_unregister_round_trip() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_true()
	@warning_ignore("unsafe_method_access")
	_plugin._unregister_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_false()
	assert_bool(ProjectSettings.has_setting("autoload/SceneManager")).is_false()


func test_register_disable_round_trip() -> void:
	if _plugin == null:
		return
	_clean_autoloads()
	@warning_ignore("unsafe_method_access")
	_plugin._register_autoloads()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_true()
	@warning_ignore("unsafe_method_access")
	_plugin._disable_plugin()
	assert_bool(ProjectSettings.has_setting("autoload/Scenes")).is_false()


# ------------- [Private Helper] -------------


## Removes both autoload settings to ensure a clean test state.
func _clean_autoloads() -> void:
	var keys := ["autoload/Scenes", "autoload/SceneManager"]
	for key: String in keys:
		if ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, null)
