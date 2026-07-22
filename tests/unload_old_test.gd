extends GdUnitTestSuite
## Tests for the `unload_old` parameter in load_scene_with_transition().
## Verifies that the old scene is freed when unload_old=true and
## retained when unload_old=false.


func before() -> void:
	monitor_signals(SceneManager, false)
	await get_tree().create_timer(1.5).timeout


func after() -> void:
	await get_tree().create_timer(0.5).timeout


# ------------- [unload_old=true] -------------


func test_unload_old_true_removes_old_scene_layer() -> void:
	# When unload_old=true, the old scene's layer should be
	# removed from the tree after load_scene_with_transition.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Establish SCENE_0 as the current scene
	await SceneManager.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts
	)

	# Record the old scene's layer (parent of current node)
	var old_node := SceneManager.get_current_scene_node()
	assert_object(old_node).is_not_null()
	var old_layer := old_node.get_parent()
	assert_object(old_layer).is_not_null()

	# Start async load with unload_old=true
	await SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.LOADING_SCREEN,
		false,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts,
		opts,
		true  # unload_old
	)

	# Old layer should have been freed by the trash can
	assert_bool(is_instance_valid(old_layer)).is_false()

	# Complete the async flow to avoid state pollution
	await assert_signal(SceneManager).wait_until(
		5000
	).is_emitted("load_finished")
	SceneManager.instantiate_async_result()
	await SceneManager.activate_prepared_scene()


# ------------- [unload_old=false] -------------


func test_unload_old_false_keeps_old_scene_layer() -> void:
	# When unload_old=false, the old scene's layer should
	# remain in the tree after load_scene_with_transition.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Establish SCENE_0 as the current scene
	await SceneManager.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts
	)

	# Record the old scene's layer (parent of current node)
	var old_node := SceneManager.get_current_scene_node()
	assert_object(old_node).is_not_null()
	var old_layer := old_node.get_parent()
	assert_object(old_layer).is_not_null()

	# Start async load with unload_old=false (default)
	await SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.LOADING_SCREEN,
		false,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts,
		opts,
		false  # unload_old
	)

	# Old layer should still be in the scene tree
	assert_object(old_layer.get_parent()).is_not_null()

	# Complete the async flow to avoid state pollution
	await assert_signal(SceneManager).wait_until(
		5000
	).is_emitted("load_finished")
	SceneManager.instantiate_async_result()
	await SceneManager.activate_prepared_scene()


func test_unload_old_default_keeps_old_scene_layer() -> void:
	# When unload_old is omitted (default false), the old
	# scene's layer should remain in the tree.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await SceneManager.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts
	)

	var old_node := SceneManager.get_current_scene_node()
	assert_object(old_node).is_not_null()
	var old_layer := old_node.get_parent()
	assert_object(old_layer).is_not_null()

	# Call without unload_old parameter (default behavior)
	await SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.LOADING_SCREEN,
		false,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts,
		opts
	)

	# Old layer should still be present
	assert_object(old_layer.get_parent()).is_not_null()

	# Cleanup
	await assert_signal(SceneManager).wait_until(
		5000
	).is_emitted("load_finished")
	SceneManager.instantiate_async_result()
	await SceneManager.activate_prepared_scene()
