## A simple ring buffer implementation

const DEFAULT_RING_SIZE: int = 5

var _ring_buffer: Array = Array()
var _head_index: int = 0 # Keeps track of the head of the buffer ahead of the most recent item
var _tail_index: int = 0 # Keeps track of the tail with the oldest item
var _size: int = 0 # Amount of items in the ring buffer
var _capacity: int


## Class constructor
func _init() -> void:
	set_capacity(DEFAULT_RING_SIZE)


## Sets how much the ring buffer can hold.
func set_capacity(size: int) -> void:
	# Copy the items from the head to the tail for the new size.
	# If the size is smaller, this will remove the oldest items from the array.
	var temp = Array()
	_capacity = size
	_size = 0
	_head_index = 0

	# If there's no capacity, don't loop through the items as the buffer will have nothing
	if size > 0:
		temp.resize(size)
		for i in range(mini(size, _ring_buffer.size())):
			temp[i] = _ring_buffer[(_tail_index + 1) % _capacity]
			if temp[i] == null:
				break
			
			_head_index = i
			_size += 1
	
	_ring_buffer = temp
	_tail_index = 0 


## Returns how much the ring buffer can hold.
func capacity() -> int:
	return _capacity


## Returns the number of items in the ring buffer.
func size() -> int:
	return _size


## Removes all the items from the ring buffer.
func clear() -> void:
	for i in range(_ring_buffer.size()):
		_ring_buffer[i] = null
	_head_index = 0
	_tail_index = 0
	_size = 0


## Adds an item to the ring buffer.
func push(item) -> void:
	# If the buffer is full, the head index will hit the tail, so keep the tail with the head
	if _size == _capacity:
		_tail_index = (_tail_index + 1) % _capacity

	_ring_buffer[_head_index] = item
	_head_index = (_head_index + 1) % _capacity
	_size = mini(_size + 1, _capacity)


## Removes the most recent item from the ring buffer.
func pop() -> Variant:
	if _size == 0:
		return null
	
	# Move the head back, wrapping it around to the top if it went past the beginning
	_head_index = _head_index - 1
	if _head_index < 0:
		_head_index += _capacity
	
	var item = _ring_buffer[_head_index]
	_ring_buffer[_head_index] = null
	_size -= 1

	return item