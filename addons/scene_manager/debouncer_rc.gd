@tool
## A lightweight debouncer that does not inherit from Node.
## Can be held as a member variable in any script without needing to be added to the SceneTree.
class_name DebouncerRC
extends RefCounted

const _C = preload("uid://c3vvdktou45u")  # scene_manager_constants.gd

# ------------- [Signal] -------------
## Emitted when the debounce _delay has successfully completed.
signal timeout

# ------------- [Private Variable] -------------
## The _delay time in seconds.
var _delay: float = _C.DEFAULT_DEBOUNCE_DELAY

## If true, the signal only fires once per call.
## If false, it repeats every _delay seconds until cancelled or restarted.
var _one_shot: bool = true

# The currently active execution ID. Incremented every time call_debounced is called.
# The timeout signal is only emitted if the ID remains the same after the async wait.
var _active_id: int = 0

## Safety limit: prevents infinite loop if _one_shot is false and cancel() is never called.
const _MAX_ITERATIONS := 10000


# ------------- [Callbacks] -------------
func _init(p_delay: float = _C.DEFAULT_DEBOUNCE_DELAY, p_one_shot: bool = true) -> void:
	_delay = p_delay
	_one_shot = p_one_shot


# ------------- [Public Method] -------------
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
	var iteration_count := 0
	while _active_id == current_id and iteration_count < _MAX_ITERATIONS:
		await tree.create_timer(_delay).timeout
		iteration_count += 1

		# Only proceed if no new calls (ID updates) occurred during the wait
		if _active_id == current_id:
			timeout.emit()
			if _one_shot:
				break
		else:
			break

	if iteration_count >= _MAX_ITERATIONS:
		SMgrUtil.get_log().error(
			"DebouncerRC: Reached max iterations. Possible runaway debouncer detected."
		)


## Cancels the currently pending debounce process.
func cancel() -> void:
	_active_id += 1


## Dynamically updates the _delay time.
func set_delay(new_delay: float) -> void:
	_delay = new_delay


## Dynamically updates the one_shot behavior.
func set_one_shot(new_one_shot: bool) -> void:
	_one_shot = new_one_shot
