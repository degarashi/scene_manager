@tool
## A lightweight debouncer that does not inherit from Node.
## Can be held as a member variable in any script without needing to be added to the SceneTree.
class_name DebouncerRC
extends RefCounted

## Emitted when the debounce _delay has successfully completed.
signal timeout

## The _delay time in seconds.
var _delay: float = 0.5

## If true, the signal only fires once per call.
## If false, it repeats every _delay seconds until cancelled or restarted.
var _one_shot: bool = true

# The currently active execution ID. Incremented every time call_debounced is called.
# The timeout signal is only emitted if the ID remains the same after the async wait.
var _active_id: int = 0


func _init(p_delay: float = 0.5, p_one_shot: bool = true) -> void:
	_delay = p_delay
	_one_shot = p_one_shot


## Starts or restarts the debounce process.
## If called repeatedly, previous calls are ignored, and the timeout emits only
## after the specified _delay following the final call.
func call_debounced() -> void:
	_active_id += 1
	var current_id := _active_id

	# Create a timer via the SceneTree
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		return

	# If _one_shot is false, the loop will continue to emit signals until _active_id changes.
	while _active_id == current_id:
		await tree.create_timer(_delay).timeout

		# Only proceed if no new calls (ID updates) occurred during the wait
		if _active_id == current_id:
			timeout.emit()
			if _one_shot:
				break
		else:
			break


## Cancels the currently pending debounce process.
func cancel() -> void:
	_active_id += 1


## Dynamically updates the _delay time.
func set_delay(new_delay: float) -> void:
	_delay = new_delay


## Dynamically updates the one_shot behavior.
func set_one_shot(new_one_shot: bool) -> void:
	_one_shot = new_one_shot
