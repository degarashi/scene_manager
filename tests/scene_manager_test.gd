extends GdUnitTestSuite


func before() -> void:
	monitor_signals(SceneManager, false)
	# Wait for initial setup to complete
	await get_tree().create_timer(1.5).timeout


func test_switch_to_scene() -> void:
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Use SCENE_0 as start point
	await SceneManager.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await assert_signal(SceneManager).is_emitted("scene_transition_completed", any())

	# Switch to SCENE_1
	await SceneManager.switch_to_scene(Scenes.Id.SCENE_1, false, opts)
	await assert_signal(SceneManager).is_emitted("scene_transition_completed", any())

	var current_node := SceneManager.get_current_scene_node()
	assert_object(current_node).is_not_null()
	assert_str(current_node.scene_file_path).is_equal(Scenes.get_scene_path(Scenes.Id.SCENE_1))


func test_add_scene_additive() -> void:
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Switch to SCENE_0 first
	await SceneManager.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	# Add SCENE_1 additively
	var add_opts := SceneLoadOptions.new()
	add_opts.node_name = "AdditiveScene"
	add_opts.play_in_time = 0.0
	add_opts.play_out_time = 0.0

	var result := await SceneManager.add_scene(
		Scenes.Id.SCENE_1, SMgrInstance.DuplicateNameMode.REMOVE_OLD, add_opts
	)
	assert_object(result).is_not_null()

	var root := get_tree().root
	var additive_layer := root.find_child("AdditiveScene", true, false)
	assert_object(additive_layer).is_not_null()

	var scene_1_node := additive_layer.get_child(0)
	assert_object(scene_1_node).is_not_null()


func test_history_navigation() -> void:
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await SceneManager.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	var initial_history_count := SceneManager.get_history_count()

	await SceneManager.switch_to_scene(Scenes.Id.SCENE_1, true, opts)  # add_to_back = true

	assert_int(SceneManager.get_history_count()).is_equal(initial_history_count + 1)

	await SceneManager.load_previous_scene(opts)

	assert_int(SceneManager.get_history_count()).is_equal(initial_history_count)

	var current_node := SceneManager.get_current_scene_node()
	assert_str(current_node.scene_file_path).is_equal(Scenes.get_scene_path(Scenes.Id.SCENE_0))
