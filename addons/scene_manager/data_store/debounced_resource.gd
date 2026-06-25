class_name DebouncedResource
extends Resource

# ------------- [Signal] -------------
## Signal emitted when the debounce delay has successfully completed.
signal data_changed_debounced

# ------------- [Constants] -------------
const DEFAULT_DEBOUNCE_TIME: float = 0.3
const _AF = preload("uid://dlgh4u64a7qxk")

# ------------- [Private Variable] -------------
## Internal debouncer instance
var _debouncer: DebouncerRC

## The debounce delay time in seconds
var _debounce_time: float = 0.5


# ------------- [Private Method] -------------
## Initializes the debouncer and starts monitoring change notifications.
## Expected to be called in the _init method of inherited classes.
func _init_debouncer(p_delay: float = 0.5) -> void:
	_debounce_time = p_delay

	if _debouncer == null:
		_debouncer = DebouncerRC.new(_debounce_time, true)
		_AF.connect_if_not_connected(_debouncer.timeout, _on_debounce_timeout)

	# Hook into the Resource's own change notification (emit_changed) to trigger the debouncer
	_AF.connect_if_not_connected(changed, _on_resource_changed)


## Handler for when the Resource emits a changed signal.
func _on_resource_changed() -> void:
	if _debouncer:
		_debouncer.call_debounced()


## Called when the debouncer timer finishes.
func _on_debounce_timeout() -> void:
	data_changed_debounced.emit()


# ------------- [Public Method] -------------
## Updates the debounce delay time.
## If the debouncer is already initialized, it updates its internal delay.
func set_delay(p_delay: float) -> void:
	_debounce_time = p_delay
	if _debouncer:
		_debouncer.set_delay(p_delay)


## Cleanup the debouncer instance and connections.
func _cleanup_debouncer() -> void:
	if is_instance_valid(_debouncer):
		_debouncer.cancel()
		_debouncer = null
