extends GdUnitTestSuite

const DataScene = preload("res://addons/scene_manager/data_store/scene_data_scene.gd")


func test_property_setters_trigger_emit_changed() -> void:
	var scene := DataScene.new()

	monitor_signals(scene)
	scene.name = "Level1"
	await assert_signal(scene).is_emitted("changed")

	monitor_signals(scene)
	scene.categories = [0, 1]
	await assert_signal(scene).is_emitted("changed")

	monitor_signals(scene)
	scene.path = "res://scenes/level1.tscn"
	await assert_signal(scene).is_emitted("changed")

	monitor_signals(scene)
	scene.uid = 12345
	await assert_signal(scene).is_emitted("changed")

	scene._cleanup_debouncer()


func test_same_value_no_reemit() -> void:
	var scene := DataScene.new()

	scene.name = "Test"
	monitor_signals(scene)
	scene.name = "Test"
	await assert_signal(scene).is_not_emitted("changed")

	scene._cleanup_debouncer()


func test_get_path_from_uid_invalid() -> void:
	var result := DataScene.get_path_from_uid(ResourceUID.INVALID_ID)
	assert_str(result).is_equal("")


func test_get_uid_from_path_empty() -> void:
	var result := DataScene.get_uid_from_path("")
	assert_int(result).is_equal(ResourceUID.INVALID_ID)
