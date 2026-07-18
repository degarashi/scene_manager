extends GdUnitTestSuite

const SceneResource = preload(
	"res://addons/scene_manager/data_store/scene_resource.gd"
)

# Instance reused across tests, cleaned up in after_test.
var _resource: SceneResource = null


# ------------- [Before / After] -------------


func before_test() -> void:
	_resource = SceneResource.new()


func after_test() -> void:
	_resource = null


# ------------- [Tests] -------------


func test_default_state() -> void:
	assert_str(_resource.string_value).is_empty()
	assert_int(_resource.scene_value).is_equal(Scenes.Id.NONE)


func test_set_text_updates_string_value() -> void:
	_resource.set_text("SCENE_0")
	assert_str(_resource.string_value).is_equal("SCENE_0")


func test_set_text_emits_changed_on_new_value() -> void:
	monitor_signals(_resource)
	_resource.set_text("SCENE_0")
	await assert_signal(_resource).is_emitted("changed")


func test_set_text_no_signal_on_same_value() -> void:
	_resource.set_text("SCENE_0")
	# Re-monitor to clear the previously emitted signal.
	monitor_signals(_resource)
	_resource.set_text("SCENE_0")
	await assert_signal(_resource).is_not_emitted("changed")


func test_scene_value_returns_correct_enum() -> void:
	_resource.set_text("SCENE_0")
	assert_int(_resource.scene_value).is_equal(Scenes.Id.SCENE_0)


func test_scene_value_returns_none_for_unknown_name() -> void:
	_resource.set_text("NONEXISTENT_SCENE")
	assert_int(_resource.scene_value).is_equal(Scenes.Id.NONE)


func test_to_string_contains_expected_fields() -> void:
	_resource.set_text("SCENE_0")
	var result := _resource._to_string()
	assert_str(result).contains("String: SCENE_0")
	assert_str(result).contains("Scene: ")
