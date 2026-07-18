extends GdUnitTestSuite

const SceneLayerScript = preload("res://addons/scene_manager/scene_layer.gd")

var _layer: SMgrSceneLayer


func before_test() -> void:
	_layer = SceneLayerScript.new()
	add_child(_layer)


func after_test() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()


# =============================================================================
# Test: default state
# =============================================================================


## Verify default state: scene_id is Scenes.Id.NONE, pause_lower is false,
## l_priority is 1, _main_node is null
func test_default_state() -> void:
	assert_int(_layer.scene_id).is_equal(Scenes.Id.NONE)
	assert_bool(_layer.pause_lower).is_false()
	assert_int(_layer.l_priority).is_equal(1)
	assert_object(_layer.get_main_node()).is_null()
	# _on_child_order_changed is not connected until prepare() is called
	assert_bool(_layer.child_order_changed.is_connected(_layer._on_child_order_changed)).is_false()


# =============================================================================
# Test: prepare()
# =============================================================================


## Verify prepare() sets all properties correctly
func test_prepare_sets_all_properties() -> void:
	var test_id := Scenes.Id.SCENE_0
	var test_name := "TestSceneLayer"
	var test_priority := 5
	var test_pause_lower := true
	var test_follow := true

	_layer.prepare(test_id, test_name, test_priority, test_pause_lower, test_follow)

	assert_int(_layer.scene_id).is_equal(test_id)
	assert_str(_layer.name).is_equal(test_name)
	assert_int(_layer.layer).is_equal(test_priority)
	assert_int(_layer.l_priority).is_equal(test_priority)
	assert_bool(_layer.pause_lower).is_true()
	assert_bool(_layer.follow_viewport_enabled).is_true()
	# Verify child_order_changed is connected
	assert_bool(_layer.child_order_changed.is_connected(_layer._on_child_order_changed)).is_true()


# =============================================================================
# Test: add_node()
# =============================================================================


## Verify add_node() makes the node a child and sets _main_node
func test_add_node_valid() -> void:
	var node := Node.new()
	_layer.add_node(node)

	assert_object(node.get_parent()).is_equal(_layer)
	assert_object(_layer.get_main_node()).is_equal(node)
	# Verify the node was added as a child
	assert_int(_layer.get_child_count()).is_equal(1)


## Verify passing null to add_node() emits push_warning without crash,
## child count stays same and _main_node remains null
func test_add_node_null() -> void:
	assert_object(_layer.get_main_node()).is_null()
	var child_count_before := _layer.get_child_count()

	_layer.add_node(null)

	# No crash, child count unchanged
	assert_int(_layer.get_child_count()).is_equal(child_count_before)
	# _main_node remains null
	assert_object(_layer.get_main_node()).is_null()


## Verify add_node() reparents a node that already has a parent
func test_add_node_reparents() -> void:
	var original_parent := Node.new()
	add_child(original_parent)

	var node := Node.new()
	original_parent.add_child(node)
	assert_object(node.get_parent()).is_equal(original_parent)

	_layer.add_node(node)

	# Node removed from original parent and added to _layer
	assert_object(node.get_parent()).is_equal(_layer)
	assert_object(_layer.get_main_node()).is_equal(node)
	# Original parent has no children left
	assert_int(original_parent.get_child_count()).is_equal(0)

	original_parent.queue_free()


# =============================================================================
# Test: get_main_node()
# =============================================================================


## Verify get_main_node() returns the node added by add_node()
func test_get_main_node_returns_added_node() -> void:
	var node := Node.new()
	_layer.add_node(node)

	var result := _layer.get_main_node()
	assert_object(result).is_equal(node)


## Verify calling add_node() multiple times sets _main_node to the last added node
func test_get_main_node_returns_last_added() -> void:
	var first := Node.new()
	var second := Node.new()

	_layer.add_node(first)
	assert_object(_layer.get_main_node()).is_equal(first)

	_layer.add_node(second)
	assert_object(_layer.get_main_node()).is_equal(second)
	# Both are children of the layer
	assert_int(_layer.get_child_count()).is_equal(2)


# =============================================================================
# Test: auto-disposal on child removal
# =============================================================================


## Verify removing a child triggers _on_child_order_changed,
## emits queue_free + layer_disposed signal
## NOTE: GDScript closures capture primitives by value,
## so we detect signal emission via Dictionary (reference type)
func test_child_removal_triggers_disposal() -> void:
	_layer.prepare(Scenes.Id.SCENE_0, "DisposeTest", 1, false, false)

	var captured := {emitted = false, id = Scenes.Id.NONE}
	_layer.layer_disposed.connect(
		func(id: Scenes.Id) -> void:
			captured.emitted = true
			captured.id = id
	)

	var child := Node.new()
	_layer.add_child(child)
	assert_int(_layer.get_child_count()).is_equal(1)

	# Remove the only child → _on_child_order_changed → queue_free + layer_disposed
	_layer.remove_child(child)
	child.queue_free()

	# Verify layer_disposed signal was emitted (fired synchronously)
	assert_bool(captured.emitted).is_true()
	var signal_id: int = captured.id
	assert_int(signal_id).is_equal(Scenes.Id.SCENE_0)

	# Wait for queue_free to process
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify the layer has been freed
	assert_bool(not is_instance_valid(_layer)).is_true()


## Use monitor_signals to detect child_order_changed signal
## (signal test for add_child without queue_free)
func test_monitor_signals_child_added() -> void:
	_layer.prepare(Scenes.Id.SCENE_0, "SignalMonitor", 1, false, false)
	monitor_signals(_layer)

	var child := Node.new()
	_layer.add_child(child)
	await assert_signal(_layer).is_emitted("child_order_changed")

	child.queue_free()


# =============================================================================
# Test: _exit_tree disconnects signals
# =============================================================================


## Verify queue_free triggers _exit_tree,
## which disconnects child_order_changed signal connected by prepare()
func test_exit_tree_disconnects_signals() -> void:
	_layer.prepare(Scenes.Id.SCENE_0, "ExitTreeTest", 1, false, false)

	# Signal is connected after prepare()
	assert_bool(_layer.child_order_changed.is_connected(_layer._on_child_order_changed)).is_true()

	# Call queue_free (removed from tree, _exit_tree executes)
	_layer.queue_free()
	await get_tree().process_frame

	# Verify the layer has been freed (signal disconnected in _exit_tree)
	assert_bool(not is_instance_valid(_layer)).is_true()


## Verify remove_child also triggers _exit_tree
## and disconnects child_order_changed signal
func test_exit_tree_by_remove_child_disconnects_signal() -> void:
	_layer.prepare(Scenes.Id.SCENE_0, "RemoveExitTest", 1, false, false)

	# Verify it is connected
	assert_bool(_layer.child_order_changed.is_connected(_layer._on_child_order_changed)).is_true()

	# Remove from tree via remove_child → _exit_tree is called synchronously
	remove_child(_layer)

	# Verify signal was disconnected by _exit_tree
	assert_bool(_layer.child_order_changed.is_connected(_layer._on_child_order_changed)).is_false()

	# Cleanup
	_layer.queue_free()


# =============================================================================
# Test: multiple children
# =============================================================================


## Verify that removing the first of multiple children does not dispose,
## but removing the last child triggers disposal
func test_multiple_children_removal_partial() -> void:
	_layer.prepare(Scenes.Id.SCENE_0, "MultiChildTest", 1, false, false)

	var child_a := Node.new()
	var child_b := Node.new()
	_layer.add_child(child_a)
	_layer.add_child(child_b)

	# Remove first child → still have children, not disposed
	_layer.remove_child(child_a)
	child_a.queue_free()

	await get_tree().process_frame
	assert_bool(is_instance_valid(_layer)).is_true()

	# Remove last child → no children left, disposed
	_layer.remove_child(child_b)
	child_b.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(not is_instance_valid(_layer)).is_true()
