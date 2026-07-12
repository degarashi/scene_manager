extends GdUnitTestSuite

var sm: SMgrInstance


func before() -> void:
	sm = get_node("/root/SceneManager") as SMgrInstance
	# Wait for initial setup
	await get_tree().create_timer(1.5).timeout


func test_concurrent_switch_to_scene_is_locked() -> void:
	var opts1 := SceneLoadOptions.new()
	opts1.play_out_time = 0.5
	opts1.play_in_time = 0.5

	var opts2 := SceneLoadOptions.new()
	opts2.play_out_time = 0.2
	opts2.play_in_time = 0.2

	# Start first transition (to SCENE_0)
	sm.call_deferred("switch_to_scene", Scenes.Id.SCENE_0, false, opts1)

	# Small delay to ensure the deferred call starts
	await get_tree().process_frame

	# Start second transition immediately (to SCENE_1)
	# This should be ignored because the first one is in progress.
	var node2 = await sm.switch_to_scene(Scenes.Id.SCENE_1, false, opts2)

	assert_object(node2).is_null()  # Second call should return null

	# Wait enough time for the first one to finish
	await get_tree().create_timer(1.5).timeout

	# Validate state
	# We expect SCENE_0 to be the current one because SCENE_1 was ignored.
	assert_int(sm._current_scene_enum).is_equal(Scenes.Id.SCENE_0)

	var root := get_tree().root
	var layers = []
	for child in root.get_children():
		if child is SMgrSceneLayer:
			layers.append(child)

	assert_int(layers.size()).is_equal(1)
	assert_int(layers[0].scene_id).is_equal(Scenes.Id.SCENE_0)
