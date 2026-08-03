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


func test_initialize_prefers_existing_path() -> void:
	## initialize() keeps the entry's own path when the file exists with the expected UID.
	var path := "res://demo/scenes/scene_0.tscn"
	var uid := ResourceLoader.get_resource_uid(path)
	assert_int(uid).is_not_equal(ResourceUID.INVALID_ID)

	var result := DataScene.initialize("Scene0", path, uid)
	assert_object(result).is_not_null()
	assert_str(result.path).is_equal(path)
	assert_int(result.uid).is_equal(uid)
	result._cleanup_debouncer()


func test_initialize_corrects_mismatched_uid_from_path() -> void:
	## When the given UID does not resolve, initialize() falls back to the file's real UID.
	var path := "res://demo/scenes/scene_0.tscn"
	var real_uid := ResourceLoader.get_resource_uid(path)
	assert_int(real_uid).is_not_equal(ResourceUID.INVALID_ID)

	var result := DataScene.initialize("Scene0", path, real_uid + 1)
	assert_object(result).is_not_null()
	assert_str(result.path).is_equal(path)
	assert_int(result.uid).is_equal(real_uid)
	result._cleanup_debouncer()
