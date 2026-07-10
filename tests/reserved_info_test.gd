extends GdUnitTestSuite

const ReservedInfoScript = preload(
	"res://addons/scene_manager/resource/reserved_info.gd"
)

var _info: SMgrReservedInfo


func before_test() -> void:
	_info = ReservedInfoScript.new()


func test_default_values() -> void:
	assert_int(_info.scene_id).is_equal(Scenes.Id.NONE)
	assert_object(_info.options).is_null()
	assert_bool(_info.is_additive).is_false()
	assert_bool(_info.add_to_back).is_false()


func test_setting_fields() -> void:
	_info.scene_id = Scenes.Id.SCENE_0
	_info.options = SceneLoadOptions.new()
	_info.is_additive = true
	_info.add_to_back = true

	assert_int(_info.scene_id).is_equal(Scenes.Id.SCENE_0)
	assert_object(_info.options).is_not_null()
	assert_bool(_info.is_additive).is_true()
	assert_bool(_info.add_to_back).is_true()


func test_clear_resets_all_fields() -> void:
	_info.scene_id = Scenes.Id.SCENE_0
	_info.options = SceneLoadOptions.new()
	_info.is_additive = true
	_info.add_to_back = true

	_info.clear()

	assert_int(_info.scene_id).is_equal(Scenes.Id.NONE)
	assert_object(_info.options).is_null()
	assert_bool(_info.is_additive).is_false()
	assert_bool(_info.add_to_back).is_false()


func test_clear_after_null_options() -> void:
	_info.options = null

	_info.clear()

	assert_int(_info.scene_id).is_equal(Scenes.Id.NONE)
	assert_object(_info.options).is_null()
	assert_bool(_info.is_additive).is_false()
	assert_bool(_info.add_to_back).is_false()
