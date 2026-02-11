extends RefCounted

const _RING_BUFFER = preload("./ring_buffer.gd")
var _buffer := _RING_BUFFER.new()


func _init(capacity: Scenes.Id = _RING_BUFFER.DEFAULT_RING_SIZE) -> void:
	_buffer.set_capacity(capacity)


func push(value: Scenes.Id) -> void:
	_buffer.push(value)


func pop() -> Scenes.Id:
	var v = _buffer.pop()
	return v if v != null else Scenes.Id.NONE


func size() -> Scenes.Id:
	return _buffer.size()


func capacity() -> Scenes.Id:
	return _buffer.capacity()


func clear() -> void:
	_buffer.clear()


func get_all_items() -> Array[Scenes.Id]:
	var arr: Array[Scenes.Id] = []
	for v in _buffer.get_all_items():
		arr.append(v)
	return arr
