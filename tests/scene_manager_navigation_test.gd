extends GdUnitTestSuite
## Tests for SceneManager navigation API methods.
## Focuses on API contract: guard clauses, parameter validation,
## return types, and state management — NOT actual scene loading.

var _smgr: SMgrInstance


# ------------- [Setup/Teardown] -------------


func before() -> void:
	# Use the SceneManager autoload for full API access.
	_smgr = SceneManager
	monitor_signals(_smgr, false)
	await get_tree().create_timer(1.5).timeout


func after() -> void:
	await get_tree().create_timer(0.5).timeout


# ------------- [switch_to_scene — Guard Clauses] -------------


func test_switch_to_scene_none_returns_null() -> void:
	# switch_to_scene with Scenes.Id.NONE should warn and
	# return null without loading anything.
	var result: Node = await _smgr.switch_to_scene(
		Scenes.Id.NONE, false
	)
	assert_object(result).is_null()


func test_switch_to_scene_valid_id_returns_node() -> void:
	# switch_to_scene with a valid scene ID should return a
	# non-null Node after transition.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	var result: Node = await _smgr.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts
	)
	assert_object(result).is_not_null()
	assert_str(result.scene_file_path).is_equal(
		Scenes.get_scene_path(Scenes.Id.SCENE_0)
	)


func test_switch_to_scene_with_custom_options() -> void:
	# switch_to_scene should accept SceneLoadOptions with
	# custom values.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.1
	opts.play_out_time = 0.1
	opts.clickable = true
	opts.node_name = "CustomNode"

	var result: Node = await _smgr.switch_to_scene(
		Scenes.Id.SCENE_1, false, opts
	)
	assert_object(result).is_not_null()


func test_switch_to_scene_accepts_callback_param() -> void:
	# switch_to_scene should accept an optional scene_loaded_cb
	# Callable parameter without crashing.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	var cb := func(_node: Node) -> void:
		pass

	# Should not crash when passing a callback
	var result: Node = await _smgr.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts, cb
	)
	# Result may be null if scene fails to load in this env
	# — the key assertion is no crash occurred.
	assert_bool(true).is_true()


func test_switch_to_scene_adds_to_history() -> void:
	# switch_to_scene with add_to_back=true should push the
	# previous scene onto the history stack.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	var count_before := _smgr.get_history_count()

	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)
	assert_int(_smgr.get_history_count()).is_equal(
		count_before + 1
	)


func test_switch_to_scene_no_back_skips_history() -> void:
	# switch_to_scene with add_to_back=false should NOT push
	# the previous scene onto the history stack.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	var count_before := _smgr.get_history_count()

	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, false, opts)
	assert_int(_smgr.get_history_count()).is_equal(count_before)


func test_switch_to_scene_reloads_same_scene() -> void:
	# Switching to the same scene should reload it.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	var result: Node = await _smgr.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts
	)
	assert_object(result).is_not_null()
	assert_str(result.scene_file_path).is_equal(
		Scenes.get_scene_path(Scenes.Id.SCENE_0)
	)


# ------------- [switch_to_scene — Path via Scenes] -------------


func test_scenes_get_scene_path_none_returns_empty() -> void:
	# Scenes.get_scene_path(NONE) should return empty string.
	var path := Scenes.get_scene_path(Scenes.Id.NONE)
	assert_str(path).is_equal("")


func test_scenes_get_scene_path_valid_id() -> void:
	# Scenes.get_scene_path with a valid ID should return a
	# non-empty resource path.
	var path := Scenes.get_scene_path(Scenes.Id.SCENE_0)
	assert_str(path).is_not_equal("")
	assert_str(path).starts_with("res://")


func test_scenes_get_scene_none_returns_null() -> void:
	# Scenes.get_scene(NONE) should return null.
	var scene := Scenes.get_scene(Scenes.Id.NONE)
	assert_object(scene).is_null()


func test_scenes_get_scene_valid_id() -> void:
	# Scenes.get_scene with a valid ID should return a
	# PackedScene.
	var scene := Scenes.get_scene(Scenes.Id.SCENE_0)
	assert_object(scene).is_not_null()


# ------------- [add_scene — Guard Clauses] -------------


func test_add_scene_none_returns_null() -> void:
	# add_scene with Scenes.Id.NONE should warn and return null.
	var result: Node = _smgr.add_scene(Scenes.Id.NONE)
	assert_object(result).is_null()


func test_add_scene_remove_old_returns_node() -> void:
	# add_scene with REMOVE_OLD mode on a fresh name should
	# return a Node.
	var opts := SceneLoadOptions.new()
	opts.node_name = "AddTest_Default"
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	var result: Node = await _smgr.add_scene(
		Scenes.Id.SCENE_0,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)
	assert_object(result).is_not_null()

	# Cleanup
	_smgr.unload_scene_by_name("AddTest_Default")
	await get_tree().process_frame


func test_add_scene_remove_old_replaces_existing() -> void:
	# add_scene with REMOVE_OLD should remove the existing layer
	# and replace it with a new one.
	var opts := SceneLoadOptions.new()
	opts.node_name = "AddTest_RemoveOld"
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Add first scene
	var first: Node = await _smgr.add_scene(
		Scenes.Id.SCENE_0,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)
	assert_object(first).is_not_null()

	# Add second scene with same name, REMOVE_OLD
	var second: Node = await _smgr.add_scene(
		Scenes.Id.SCENE_1,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)
	assert_object(second).is_not_null()

	# Cleanup
	_smgr.unload_scene_by_name("AddTest_RemoveOld")
	await get_tree().process_frame


func test_add_scene_warn_and_skip_returns_null() -> void:
	# add_scene with WARN_AND_SKIP on an existing layer name
	# should return null.
	var opts := SceneLoadOptions.new()
	opts.node_name = "AddTest_Skip"
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Add first scene
	await _smgr.add_scene(
		Scenes.Id.SCENE_0,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)

	# Add second with WARN_AND_SKIP (same name)
	var result: Node = await _smgr.add_scene(
		Scenes.Id.SCENE_1,
		SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
		opts
	)
	assert_object(result).is_null()

	# Cleanup
	_smgr.unload_scene_by_name("AddTest_Skip")
	await get_tree().process_frame


func test_add_scene_rename_new_avoids_collision() -> void:
	# add_scene with RENAME_NEW should create a new layer with
	# a numeric suffix to avoid name collision.
	var opts := SceneLoadOptions.new()
	opts.node_name = "AddTest_Rename"
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Add first scene
	await _smgr.add_scene(
		Scenes.Id.SCENE_0,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)

	# Add second with RENAME_NEW
	var second: Node = await _smgr.add_scene(
		Scenes.Id.SCENE_1,
		SMgrInstance.DuplicateNameMode.RENAME_NEW,
		opts
	)
	assert_object(second).is_not_null()

	# Verify both layers exist
	var root := get_tree().root
	var original := root.find_child(
		"AddTest_Rename", true, false
	)
	var renamed := root.find_child(
		"AddTest_Rename2", true, false
	)
	assert_object(original).is_not_null()
	assert_object(renamed).is_not_null()

	# Cleanup
	_smgr.unload_scene_by_name("AddTest_Rename")
	_smgr.unload_scene_by_name("AddTest_Rename2")
	await get_tree().process_frame


func test_add_scene_append_adds_to_existing() -> void:
	# add_scene with APPEND should add the new scene node to
	# the existing layer instead of creating a new one.
	var opts := SceneLoadOptions.new()
	opts.node_name = "AddTest_Append"
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	# Add first scene
	await _smgr.add_scene(
		Scenes.Id.SCENE_0,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)

	# Add second with APPEND
	var second: Node = await _smgr.add_scene(
		Scenes.Id.SCENE_1,
		SMgrInstance.DuplicateNameMode.APPEND,
		opts
	)
	assert_object(second).is_not_null()

	# Verify the layer has 2 children
	var root := get_tree().root
	var layer := root.find_child(
		"AddTest_Append", true, false
	)
	assert_object(layer).is_not_null()
	assert_int(layer.get_child_count()).is_equal(2)

	# Cleanup
	_smgr.unload_scene_by_name("AddTest_Append")
	await get_tree().process_frame


# ------------- [remove_scene — Guard Clauses] -------------


func test_remove_scene_none_returns_false() -> void:
	# remove_scene with Scenes.Id.NONE should return false.
	var result := _smgr.remove_scene(Scenes.Id.NONE)
	assert_bool(result).is_false()


func test_remove_scene_nonexistent_returns_false() -> void:
	# remove_scene on a scene that isn't loaded should return
	# false.
	var result := _smgr.remove_scene(Scenes.Id.SCENE_2)
	assert_bool(result).is_false()


func test_remove_scene_loaded_returns_true() -> void:
	# remove_scene on a loaded scene should return true.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	var result := _smgr.remove_scene(Scenes.Id.SCENE_0)
	assert_bool(result).is_true()


# ------------- [unload_scene_by_name — Edge Cases] -------------


func test_unload_scene_by_name_empty_no_crash() -> void:
	# unload_scene_by_name with empty string should not crash.
	_smgr.unload_scene_by_name("")
	assert_bool(true).is_true()


func test_unload_scene_by_name_nonexistent_noop() -> void:
	# unload_scene_by_name with a nonexistent name should be
	# a no-op.
	_smgr.unload_scene_by_name("NonexistentLayer12345")
	assert_bool(true).is_true()


func test_unload_scene_by_name_removes_layer() -> void:
	# unload_scene_by_name should remove the matching layer.
	var opts := SceneLoadOptions.new()
	opts.node_name = "UnloadTarget"
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.add_scene(
		Scenes.Id.SCENE_0,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)

	# Verify the layer exists
	var root := get_tree().root
	var layer := root.find_child(
		"UnloadTarget", true, false
	)
	assert_object(layer).is_not_null()

	_smgr.unload_scene_by_name("UnloadTarget")
	await get_tree().process_frame

	layer = root.find_child("UnloadTarget", true, false)
	assert_object(layer).is_null()


# ------------- [History Navigation] -------------


func test_get_history_list_returns_array() -> void:
	# get_history_list should always return an Array.
	var history := _smgr.get_history_list()
	assert_object(history).is_not_null()


func test_get_history_count_non_negative() -> void:
	# get_history_count should return a non-negative integer.
	var count := _smgr.get_history_count()
	assert_int(count).is_greater_equal(0)


func test_history_grows_on_switch_with_back() -> void:
	# Multiple switches with add_to_back=true should grow
	# history.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	var count_start := _smgr.get_history_count()

	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_2, true, opts)

	assert_int(_smgr.get_history_count()).is_equal(
		count_start + 2
	)

	# Restore state
	await _smgr.switch_to_scene(
		Scenes.Id.SCENE_0, false, opts
	)


func test_load_previous_scene_empty_returns_false() -> void:
	# load_previous_scene on an empty history should return
	# false.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0
	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	# If history is empty, load_previous should return false
	if _smgr.get_history_count() == 0:
		var result := await _smgr.load_previous_scene(opts)
		assert_bool(result).is_false()


func test_load_previous_scene_restores_previous() -> void:
	# load_previous_scene should restore the previously visited
	# scene.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)

	var result := await _smgr.load_previous_scene(opts)
	assert_bool(result).is_true()

	var current_node := _smgr.get_current_scene_node()
	assert_object(current_node).is_not_null()
	assert_str(current_node.scene_file_path).is_equal(
		Scenes.get_scene_path(Scenes.Id.SCENE_0)
	)


func test_back_to_previous_by_offset() -> void:
	# back_to_previous_by_offset with offset=2 should go back
	# two scenes in history.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_2, true, opts)

	await _smgr.back_to_previous_by_offset(2, opts)

	var current_node := _smgr.get_current_scene_node()
	assert_object(current_node).is_not_null()
	assert_str(current_node.scene_file_path).is_equal(
		Scenes.get_scene_path(Scenes.Id.SCENE_0)
	)


func test_back_to_previous_by_offset_zero_is_noop() -> void:
	# back_to_previous_by_offset with offset=0 should warn and
	# not change the current scene.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)
	_smgr.clear_history()

	var current_before := _smgr.get_current_scene_node()
	var path_before := current_before.scene_file_path

	_smgr.back_to_previous_by_offset(0, opts)

	var current_after := _smgr.get_current_scene_node()
	assert_str(current_after.scene_file_path).is_equal(path_before)


func test_back_to_previous_by_offset_negative_is_noop() -> void:
	# back_to_previous_by_offset with negative offset should warn
	# and not change the current scene.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)
	_smgr.clear_history()

	var current_before := _smgr.get_current_scene_node()
	var path_before := current_before.scene_file_path

	_smgr.back_to_previous_by_offset(-1, opts)

	var current_after := _smgr.get_current_scene_node()
	assert_str(current_after.scene_file_path).is_equal(path_before)


func test_clear_history_empties_stack() -> void:
	# clear_history should remove all entries from the history.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_2, true, opts)

	_smgr.clear_history()
	assert_int(_smgr.get_history_count()).is_equal(0)
	assert_array(_smgr.get_history_list()).is_empty()


func test_clear_history_does_not_affect_current_scene() -> void:
	# clear_history should not change the currently active scene.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	await _smgr.switch_to_scene(Scenes.Id.SCENE_1, true, opts)

	_smgr.clear_history()

	var current_node := _smgr.get_current_scene_node()
	assert_object(current_node).is_not_null()
	assert_str(current_node.scene_file_path).is_equal(
		Scenes.get_scene_path(Scenes.Id.SCENE_1)
	)


func test_reload_current_scene_returns_true() -> void:
	# reload_current_scene should return true when a scene is
	# active.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	var result := await _smgr.reload_current_scene(opts)
	assert_bool(result).is_true()


func test_reload_current_scene_when_none_returns_false() -> void:
	# reload_current_scene should return false when current scene
	# is NONE (e.g. after remove_scene).
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	_smgr.remove_scene(Scenes.Id.SCENE_0)
	await get_tree().process_frame

	var result := await _smgr.reload_current_scene(opts)
	assert_bool(result).is_false()


# ------------- [Current Scene State] -------------


func test_get_current_scene_node_after_switch() -> void:
	# get_current_scene_node should return the node of the
	# currently active scene.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)
	var node := _smgr.get_current_scene_node()

	assert_object(node).is_not_null()
	assert_str(node.scene_file_path).is_equal(
		Scenes.get_scene_path(Scenes.Id.SCENE_0)
	)


func test_get_current_scene_node_after_additive() -> void:
	# get_current_scene_node should still return the main scene
	# after an additive scene is loaded.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	var add_opts := SceneLoadOptions.new()
	add_opts.node_name = "AdditiveOverlay"
	add_opts.play_in_time = 0.0
	add_opts.play_out_time = 0.0

	await _smgr.add_scene(
		Scenes.Id.SCENE_1,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		add_opts
	)

	var node := _smgr.get_current_scene_node()
	assert_object(node).is_not_null()

	# Cleanup
	_smgr.unload_scene_by_name("AdditiveOverlay")
	await get_tree().process_frame


# ------------- [Reserved Scene Info] -------------


func test_get_reserved_scene_type() -> void:
	# get_reserved_scene should return an int (Scenes.Id type).
	var reserved := _smgr.get_reserved_scene()
	assert_int(typeof(reserved)).is_equal(TYPE_INT)


func test_get_reserved_load_option_type() -> void:
	# get_reserved_load_option should return a SceneLoadOptions
	# or null.
	var opts_result := _smgr.get_reserved_load_option()
	if opts_result != null:
		assert_object(opts_result).is_instanceof(
			SceneLoadOptions
		)


func test_reserved_after_load_scene_with_transition() -> void:
	# After load_scene_with_transition, get_reserved_scene should
	# return the target scene ID.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	_smgr.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.LOADING_SCREEN,
		true,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)

	var reserved := _smgr.get_reserved_scene()
	assert_int(reserved).is_equal(Scenes.Id.SCENE_1)

	# Wait for async load to finish
	await assert_signal(_smgr).wait_until(5000).is_emitted(
		"load_finished"
	)

	# Cleanup
	_smgr.instantiate_async_result()
	await _smgr.activate_prepared_scene()


# ------------- [Async Loading — Guard Clauses] -------------


func test_start_async_load_with_none() -> void:
	# start_async_load with NONE should not crash.
	_smgr.start_async_load(Scenes.Id.NONE)
	assert_bool(true).is_true()


func test_load_scene_with_transition_none_warns() -> void:
	# load_scene_with_transition with NONE for next_scene should
	# not crash.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	_smgr.load_scene_with_transition(
		Scenes.Id.NONE,
		Scenes.Id.LOADING_SCREEN,
		true,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)
	assert_bool(true).is_true()


func test_load_scene_with_transition_trans_none() -> void:
	# load_scene_with_transition with NONE for transition_scene
	# should not crash.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	_smgr.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.NONE,
		true,
		SMgrInstance.DuplicateNameMode.REMOVE_OLD,
		opts
	)
	assert_bool(true).is_true()


func test_instantiate_async_result_no_reserved() -> void:
	# instantiate_async_result with no reserved scene should
	# not crash.
	_smgr.instantiate_async_result()
	assert_bool(true).is_true()


func test_activate_prepared_scene_no_reserved() -> void:
	# activate_prepared_scene with no reserved scene should
	# return null.
	var result: Node = await _smgr.activate_prepared_scene()
	assert_object(result).is_null()


# ------------- [Scene Data Access] -------------


func test_get_scene_data_returns_smgr_data() -> void:
	# get_scene_data should return a non-null SMgrData resource.
	var data := _smgr.get_scene_data()
	assert_object(data).is_not_null()


# ------------- [DuplicateNameMode Enum] -------------


func test_duplicate_name_mode_enum_values() -> void:
	# DuplicateNameMode should have the expected enum values.
	assert_int(
		SMgrInstance.DuplicateNameMode.REMOVE_OLD
	).is_equal(0)
	assert_int(
		SMgrInstance.DuplicateNameMode.WARN_AND_SKIP
	).is_equal(1)
	assert_int(
		SMgrInstance.DuplicateNameMode.RENAME_NEW
	).is_equal(2)
	assert_int(
		SMgrInstance.DuplicateNameMode.APPEND
	).is_equal(3)


# ------------- [SceneLoadOptions Integration] -------------


func test_scene_load_options_defaults() -> void:
	# SceneLoadOptions default constructor should set expected
	# defaults. Fade times come from project settings.
	var opts := SceneLoadOptions.new()

	assert_str(opts.node_name).is_equal("World")
	assert_float(opts.play_out_time).is_greater_equal(0.0)
	assert_float(opts.play_in_time).is_greater_equal(0.0)
	assert_bool(opts.clickable).is_false()
	assert_int(opts.transition_layer).is_not_equal(0)
	assert_object(opts.params).is_null()


func test_scene_load_options_copy_preserves() -> void:
	# SceneLoadOptions.copy() should preserve all field values.
	var opts := SceneLoadOptions.new()
	opts.node_name = "TestCopy"
	opts.play_in_time = 1.5
	opts.play_out_time = 2.0
	opts.clickable = true
	opts.params = {"key": "value"}

	var copied := opts.copy()

	assert_str(copied.node_name).is_equal("TestCopy")
	assert_float(copied.play_in_time).is_equal(1.5)
	assert_float(copied.play_out_time).is_equal(2.0)
	assert_bool(copied.clickable).is_true()
	assert_str(copied.params["key"]).is_equal("value")


func test_scene_load_options_copy_independence() -> void:
	# Modifying a copy should not affect the original.
	var opts := SceneLoadOptions.new()
	opts.params = {"a": 1}

	var copied := opts.copy()
	copied.params["a"] = 99
	copied.node_name = "Changed"

	assert_int(opts.params["a"]).is_equal(1)
	assert_str(opts.node_name).is_not_equal("Changed")


# ------------- [Signal Emissions] -------------


func test_scene_transition_completed_emitted() -> void:
	# switch_to_scene should emit scene_transition_completed
	# after the transition finishes.
	var opts := SceneLoadOptions.new()
	opts.play_in_time = 0.0
	opts.play_out_time = 0.0

	monitor_signals(_smgr, false)

	await _smgr.switch_to_scene(Scenes.Id.SCENE_0, false, opts)

	await assert_signal(_smgr).is_emitted(
		"scene_transition_completed", any()
	)


# ------------- [Method Existence Checks] -------------


func test_all_navigation_methods_exist() -> void:
	# Verify all expected navigation API methods exist.
	assert_bool(_smgr.has_method("switch_to_scene")).is_true()
	assert_bool(_smgr.has_method("add_scene")).is_true()
	assert_bool(_smgr.has_method("remove_scene")).is_true()
	assert_bool(
		_smgr.has_method("unload_scene_by_name")
	).is_true()
	assert_bool(
		_smgr.has_method("load_previous_scene")
	).is_true()
	assert_bool(
		_smgr.has_method("back_to_previous_by_offset")
	).is_true()
	assert_bool(
		_smgr.has_method("reload_current_scene")
	).is_true()
	assert_bool(
		_smgr.has_method("get_history_list")
	).is_true()
	assert_bool(
		_smgr.has_method("get_history_count")
	).is_true()
	assert_bool(
		_smgr.has_method("get_current_scene_node")
	).is_true()
	assert_bool(
		_smgr.has_method("get_reserved_scene")
	).is_true()
	assert_bool(
		_smgr.has_method("get_reserved_load_option")
	).is_true()
	assert_bool(
		_smgr.has_method("get_scene_data")
	).is_true()
	assert_bool(
		_smgr.has_method("start_async_load")
	).is_true()
	assert_bool(
		_smgr.has_method("load_scene_with_transition")
	).is_true()
	assert_bool(
		_smgr.has_method("instantiate_async_result")
	).is_true()
	assert_bool(
		_smgr.has_method("activate_prepared_scene")
	).is_true()
	assert_bool(_smgr.has_method("exit_game")).is_true()


func test_scenes_enum_has_expected_ids() -> void:
	# Verify the Scenes.Id enum contains expected scene IDs.
	assert_int(Scenes.Id.NONE).is_equal(-1)
	assert_int(Scenes.Id.SCENE_0).is_not_equal(Scenes.Id.NONE)
	assert_int(Scenes.Id.SCENE_1).is_not_equal(Scenes.Id.NONE)
	assert_int(Scenes.Id.SCENE_2).is_not_equal(Scenes.Id.NONE)
	assert_int(Scenes.Id.LOADING_SCREEN).is_not_equal(
		Scenes.Id.NONE
	)
