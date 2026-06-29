extends GdUnitTestSuite

const ScenesScript = preload("res://scene_manager_data/scenes.gd")


func test_get_scene_path() -> void:
	var path := ScenesScript.get_scene_path(Scenes.Id.SCENE_0)
	assert_str(path).is_equal("res://demo/scenes/scene_0.tscn")


func test_get_scene() -> void:
	var scene := ScenesScript.get_scene(Scenes.Id.SCENE_0)
	assert_object(scene).is_not_null()
	assert_bool(scene is PackedScene).is_true()
	assert_str(scene.resource_path).is_equal("res://demo/scenes/scene_0.tscn")


func test_get_none() -> void:
	assert_str(ScenesScript.get_scene_path(Scenes.Id.NONE)).is_empty()
	assert_object(ScenesScript.get_scene(Scenes.Id.NONE)).is_null()
