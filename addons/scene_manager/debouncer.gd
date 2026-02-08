## Encapsulates debouncing logic to delay execution of a callback
extends RefCounted

var _timer: SceneTreeTimer
var _callback: Callable
var _delay: float


func _init(delay: float, callback: Callable) -> void:
	_delay = delay
	_callback = callback


func call_debounced() -> void:
	var current_timer: SceneTreeTimer = Engine.get_main_loop().create_timer(_delay)
	_timer = current_timer

	await current_timer.timeout

	if _timer == current_timer:
		_callback.call()
