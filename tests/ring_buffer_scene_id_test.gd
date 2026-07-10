extends GdUnitTestSuite

const RingBufferSceneIdScript = preload("res://addons/scene_manager/data_store/ring_buffer_scene_id.gd")

var _buffer: RingBufferSceneIdScript


func before_test() -> void:
	_buffer = RingBufferSceneIdScript.new()


func test_push_pop() -> void:
	_buffer.push(Scenes.Id.SCENE_0)
	assert_int(_buffer.pop()).is_equal(Scenes.Id.SCENE_0)


func test_size_tracking() -> void:
	assert_int(_buffer.size()).is_equal(0)
	_buffer.push(Scenes.Id.SCENE_0)
	assert_int(_buffer.size()).is_equal(1)
	_buffer.push(Scenes.Id.SCENE_1)
	assert_int(_buffer.size()).is_equal(2)
	_buffer.pop()
	assert_int(_buffer.size()).is_equal(1)
	_buffer.pop()
	assert_int(_buffer.size()).is_equal(0)


func test_capacity() -> void:
	assert_int(_buffer.capacity()).is_equal(5)
	var buf := RingBufferSceneIdScript.new(10)
	assert_int(buf.capacity()).is_equal(10)


func test_clear() -> void:
	_buffer.push(Scenes.Id.SCENE_0)
	_buffer.push(Scenes.Id.SCENE_1)
	_buffer.clear()
	assert_int(_buffer.size()).is_equal(0)


func test_get_all_items() -> void:
	_buffer.push(Scenes.Id.SCENE_0)
	_buffer.push(Scenes.Id.SCENE_1)
	_buffer.push(Scenes.Id.SCENE_2)
	var items := _buffer.get_all_items()
	assert_int(items.size()).is_equal(3)
	assert_int(items[0]).is_equal(Scenes.Id.SCENE_0)
	assert_int(items[1]).is_equal(Scenes.Id.SCENE_1)
	assert_int(items[2]).is_equal(Scenes.Id.SCENE_2)


func test_pop_empty_returns_none() -> void:
	assert_int(_buffer.pop()).is_equal(Scenes.Id.NONE)
