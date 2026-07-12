extends GdUnitTestSuite

const RingBufferScript = preload("res://addons/scene_manager/data_store/ring_buffer.gd")

var _buffer: RingBufferScript


func before_test() -> void:
	_buffer = RingBufferScript.new()


func test_default_capacity() -> void:
	assert_int(_buffer.capacity()).is_equal(5)
	assert_int(_buffer.size()).is_equal(0)


func test_push_and_pop_single() -> void:
	_buffer.push("a")
	assert_int(_buffer.size()).is_equal(1)
	assert_str(_buffer.pop()).is_equal("a")
	assert_int(_buffer.size()).is_equal(0)


func test_push_and_pop_lifo_order() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")

	assert_str(_buffer.pop()).is_equal("c")
	assert_str(_buffer.pop()).is_equal("b")
	assert_str(_buffer.pop()).is_equal("a")


func test_pop_empty_returns_null() -> void:
	assert_object(_buffer.pop()).is_null()


func test_get_all_items_order() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")

	var items = _buffer.get_all_items()
	assert_int(items.size()).is_equal(3)
	assert_str(items[0]).is_equal("a")
	assert_str(items[1]).is_equal("b")
	assert_str(items[2]).is_equal("c")


func test_wrap_around() -> void:
	# capacity=5, push 7 items → oldest 2 are dropped, newest on top (LIFO)
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")
	_buffer.push("d")
	_buffer.push("e")
	_buffer.push("f")
	_buffer.push("g")

	assert_int(_buffer.size()).is_equal(5)
	assert_str(_buffer.pop()).is_equal("g")
	assert_str(_buffer.pop()).is_equal("f")
	assert_str(_buffer.pop()).is_equal("e")
	assert_str(_buffer.pop()).is_equal("d")
	assert_str(_buffer.pop()).is_equal("c")
	assert_object(_buffer.pop()).is_null()


func test_get_all_items_after_wrap() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")
	_buffer.push("d")
	_buffer.push("e")
	_buffer.push("f")
	_buffer.push("g")

	var items = _buffer.get_all_items()
	assert_int(items.size()).is_equal(5)
	assert_str(items[0]).is_equal("c")
	assert_str(items[1]).is_equal("d")
	assert_str(items[2]).is_equal("e")
	assert_str(items[3]).is_equal("f")
	assert_str(items[4]).is_equal("g")


func test_clear() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.clear()

	assert_int(_buffer.size()).is_equal(0)
	assert_object(_buffer.pop()).is_null()


func test_set_capacity_larger() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")

	_buffer.set_capacity(10)

	assert_int(_buffer.capacity()).is_equal(10)
	assert_int(_buffer.size()).is_equal(3)
	var items = _buffer.get_all_items()
	assert_str(items[0]).is_equal("a")
	assert_str(items[1]).is_equal("b")
	assert_str(items[2]).is_equal("c")


func test_set_capacity_smaller_drops_oldest() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")
	_buffer.push("d")
	_buffer.push("e")

	_buffer.set_capacity(3)

	assert_int(_buffer.capacity()).is_equal(3)
	assert_int(_buffer.size()).is_equal(3)
	var items = _buffer.get_all_items()
	assert_str(items[0]).is_equal("c")
	assert_str(items[1]).is_equal("d")
	assert_str(items[2]).is_equal("e")


func test_set_capacity_smaller_with_wrap() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")
	_buffer.push("d")
	_buffer.push("e")
	_buffer.push("f")
	_buffer.push("g")

	_buffer.set_capacity(2)

	assert_int(_buffer.capacity()).is_equal(2)
	assert_int(_buffer.size()).is_equal(2)
	var items = _buffer.get_all_items()
	assert_str(items[0]).is_equal("f")
	assert_str(items[1]).is_equal("g")


func test_set_capacity_zero() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.set_capacity(0)

	assert_int(_buffer.capacity()).is_equal(0)
	assert_int(_buffer.size()).is_equal(0)
	assert_object(_buffer.pop()).is_null()


func test_set_capacity_preserves_order_when_not_full() -> void:
	_buffer.push("x")
	_buffer.push("y")

	_buffer.set_capacity(4)

	var items = _buffer.get_all_items()
	assert_int(items.size()).is_equal(2)
	assert_str(items[0]).is_equal("x")
	assert_str(items[1]).is_equal("y")
	# Verify push still works after resize (LIFO: most recent popped first)
	_buffer.push("z")
	assert_str(_buffer.pop()).is_equal("z")


func test_push_after_set_capacity() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.set_capacity(3)
	_buffer.push("c")
	_buffer.push("d")

	assert_int(_buffer.size()).is_equal(3)
	var items = _buffer.get_all_items()
	assert_str(items[0]).is_equal("b")
	assert_str(items[1]).is_equal("c")
	assert_str(items[2]).is_equal("d")


func test_multiple_resizes() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")

	_buffer.set_capacity(2)
	_buffer.set_capacity(4)
	_buffer.set_capacity(1)

	assert_int(_buffer.size()).is_equal(1)
	assert_str(_buffer.pop()).is_equal("c")


# ------------- [peek] -------------


func test_peek_empty_returns_null() -> void:
	assert_object(_buffer.peek()).is_null()


func test_peek_single_item() -> void:
	_buffer.push("a")
	assert_str(_buffer.peek()).is_equal("a")
	# peek should not remove the item
	assert_int(_buffer.size()).is_equal(1)


func test_peek_returns_most_recent() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.push("c")
	assert_str(_buffer.peek()).is_equal("c")


func test_peek_after_pop() -> void:
	_buffer.push("a")
	_buffer.push("b")
	_buffer.pop()  # remove "b"
	assert_str(_buffer.peek()).is_equal("a")


func test_peek_does_not_modify_state() -> void:
	_buffer.push("x")
	_buffer.push("y")
	var before_size := _buffer.size()
	_buffer.peek()
	_buffer.peek()
	assert_int(_buffer.size()).is_equal(before_size)
	assert_str(_buffer.peek()).is_equal("y")
