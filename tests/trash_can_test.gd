extends GdUnitTestSuite

const TrashCanScript = preload("res://addons/scene_manager/trash_can.gd")

var _trash_can: SMgrTrashCan


func before_test() -> void:
	_trash_can = TrashCanScript.new()
	add_child(_trash_can)


func after_test() -> void:
	_trash_can.flush()
	if is_instance_valid(_trash_can):
		_trash_can.queue_free()


func test_collect_valid_node() -> void:
	var node := Node.new()
	_trash_can.collect(node)

	assert_int(_trash_can.get_child_count()).is_equal(1)
	assert_str(_trash_can.get_child(0).name).starts_with("dying_")
	assert_bool(_trash_can.get_child(0).is_queued_for_deletion()).is_true()


func test_collect_null() -> void:
	_trash_can.collect(null)
	assert_int(_trash_can.get_child_count()).is_equal(0)


func test_flush_removes_all() -> void:
	_trash_can.collect(Node.new())
	_trash_can.collect(Node.new())
	assert_int(_trash_can.get_child_count()).is_equal(2)

	_trash_can.flush()
	assert_int(_trash_can.get_child_count()).is_equal(0)


func test_flush_empty_does_nothing() -> void:
	_trash_can.flush()
	assert_int(_trash_can.get_child_count()).is_equal(0)


func test_collect_multiple_nodes() -> void:
	_trash_can.collect(Node.new())
	_trash_can.collect(Node.new())
	_trash_can.collect(Node.new())
	assert_int(_trash_can.get_child_count()).is_equal(3)


func test_flush_with_valid_and_invalid_nodes() -> void:
	var valid := Node.new()
	_trash_can.collect(valid)
	_trash_can.flush()
	assert_int(_trash_can.get_child_count()).is_equal(0)
