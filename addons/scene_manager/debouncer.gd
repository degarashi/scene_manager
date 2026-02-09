## Encapsulates debouncing logic to delay the execution of a callback.
extends RefCounted

var _timer: SceneTreeTimer
var _callback: Callable
var _delay: float


func _init(delay: float, callback: Callable) -> void:
	_delay = delay
	_callback = callback


## Executes the debounced call. If called repeatedly, previous timer waits are ignored.
func call_debounced() -> void:
	var scene_tree := Engine.get_main_loop() as SceneTree
	if not scene_tree:
		return

	# Overwrite the existing timer reference to invalidate any ongoing 'await'
	var current_timer := scene_tree.create_timer(_delay)
	_timer = current_timer

	await current_timer.timeout

	# Check if this specific timer is still the active one and the instance is alive
	if not is_instance_valid(self) or _timer != current_timer:
		return

	# Final check on the callback validity before execution
	if _callback.is_valid():
		_callback.call()

	# Cleanup reference
	_timer = null


## Explicitly stops the current debounce and prevents the pending callback.
func cancel() -> void:
	_timer = null
