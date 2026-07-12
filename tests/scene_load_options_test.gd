extends GdUnitTestSuite

const SceneLoadOptions = preload(
	"res://addons/scene_manager/data_store/scene_load_options.gd"
)


# ------------- [Tests] -------------


func test_default_constructor_values() -> void:
	var opts := SceneLoadOptions.new()

	assert_str(opts.node_name).is_equal("World")
	# play_out_time and play_in_time fall back to project settings (DEFAULT = 1.0)
	assert_float(opts.play_out_time).is_equal(1.0)
	assert_float(opts.play_in_time).is_equal(1.0)
	assert_bool(opts.clickable).is_false()
	# transition_layer falls back to project settings (DEFAULT = 100)
	assert_int(opts.transition_layer).is_equal(100)
	assert_object(opts.params).is_null()


func test_constructor_with_explicit_params() -> void:
	var opts := SceneLoadOptions.new(
		"HUD",
		true,
		1.2,
		0.8,
	)

	assert_str(opts.node_name).is_equal("HUD")
	assert_float(opts.play_out_time).is_equal(1.2)
	assert_float(opts.play_in_time).is_equal(0.8)
	assert_bool(opts.clickable).is_true()


func test_constructor_fallback_to_project_settings() -> void:
	# Passing -1.0 should fall back to project settings defaults
	var opts := SceneLoadOptions.new("", false, -1.0, -1.0)

	# Verify the values are not -1.0 (they come from project settings)
	assert_float(opts.play_out_time).is_not_equal(-1.0)
	assert_float(opts.play_in_time).is_not_equal(-1.0)
	# Project settings defaults are 1.0
	assert_float(opts.play_out_time).is_equal(1.0)
	assert_float(opts.play_in_time).is_equal(1.0)


func test_copy_produces_independent_deep_copy() -> void:
	var called_pre_wrap := false
	var called_pre_node := false
	var wrap_fn := func(_n: Node) -> void:
		called_pre_wrap = true
	var node_fn := func(_n: Node) -> void:
		called_pre_node = true

	var opts := SceneLoadOptions.new(
		"Custom", true, 0.3, 0.7, wrap_fn, node_fn
	)
	opts.params = {"key": "value"}

	var copied := opts.copy()

	# Callbacks are preserved
	assert_object(copied.pre_wrap_cb).is_not_null()
	assert_object(copied.pre_node_cb).is_not_null()

	# Params are deep-copied (independent)
	assert_str(copied.params["key"]).is_equal("value")
	copied.params["key"] = "changed"
	assert_str(opts.params["key"]).is_equal("value")

	# Scalar fields match
	assert_str(copied.node_name).is_equal("Custom")
	assert_bool(copied.clickable).is_true()
	assert_float(copied.play_out_time).is_equal(0.3)
	assert_float(copied.play_in_time).is_equal(0.7)


func test_deep_copy_variant_dictionary() -> void:
	var original := {"a": 1, "b": {"c": 2}}
	var copied: Dictionary = SceneLoadOptions._deep_copy_variant(original)

	# Deep: modifying nested dict doesn't affect original
	copied["b"]["c"] = 99
	assert_int(original["b"]["c"]).is_equal(2)

	# Shallow key also independent
	copied["a"] = 100
	assert_int(original["a"]).is_equal(1)


func test_deep_copy_variant_array() -> void:
	var original := [1, [2, 3], {"x": 10}]
	var copied: Array = SceneLoadOptions._deep_copy_variant(original)

	# Deep: nested array modification independent
	copied[1][0] = 99
	assert_int(original[1][0]).is_equal(2)

	# Deep: nested dict modification independent
	copied[2]["x"] = 50
	assert_int(original[2]["x"]).is_equal(10)


func test_call_pre_cb_invokes_callbacks() -> void:
	var wrap_called := [false]
	var node_called := [false]
	var opts := SceneLoadOptions.new(
		"", false, -1.0, -1.0,
		func(_n: Node) -> void:
			wrap_called[0] = true,
		func(_n: Node) -> void:
			node_called[0] = true,
	)

	var dummy_wrap := Node.new()
	add_child(dummy_wrap)
	var dummy_scene := Node.new()
	add_child(dummy_scene)

	opts.call_pre_cb(dummy_wrap, dummy_scene)

	assert_bool(wrap_called[0]).is_true()
	assert_bool(node_called[0]).is_true()

	dummy_wrap.queue_free()
	dummy_scene.queue_free()


func test_call_pre_cb_with_empty_callables() -> void:
	# Default callables are empty no-ops — should not crash
	var opts := SceneLoadOptions.new()
	var dummy_wrap := Node.new()
	add_child(dummy_wrap)
	var dummy_scene := Node.new()
	add_child(dummy_scene)

	opts.call_pre_cb(dummy_wrap, dummy_scene)

	dummy_wrap.queue_free()
	dummy_scene.queue_free()


func test_copy_deep_copies_nested_params() -> void:
	# Verify nested Dictionary and Array inside params are deep-copied
	var opts := SceneLoadOptions.new()
	opts.params = {
		"nested_dict": {"inner": 1},
		"nested_array": [1, [2, 3]],
		"plain": "value"
	}

	var copied := opts.copy()

	# Modify nested structures in copy
	copied.params["nested_dict"]["inner"] = 99
	copied.params["nested_array"][1][0] = 99
	copied.params["plain"] = "changed"

	# Original should be unaffected
	assert_int(opts.params["nested_dict"]["inner"]).is_equal(1)
	assert_int(opts.params["nested_array"][1][0]).is_equal(2)
	assert_str(opts.params["plain"]).is_equal("value")


func test_to_string_format() -> void:
	var opts := SceneLoadOptions.new(
		"TestScene", false, 0.5, 0.5
	)

	var result := opts._to_string()

	# Verify key fields appear in the string
	assert_str(result).contains("SceneLoadOptions(")
	assert_str(result).contains("node_name='TestScene'")
	assert_str(result).contains("play_out_time=0.50")
	assert_str(result).contains("play_in_time=0.50")
	assert_str(result).contains("clickable=false")
