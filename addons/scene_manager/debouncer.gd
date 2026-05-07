@tool
## Encapsulates debouncing logic to delay execution until a specified delay has passed.
## Only the last call within the delay period will trigger the timeout signal.
class_name Debouncer
extends Node

# ------------- [Signal] -------------
## Emitted when the debounce delay has successfully completed.
signal timeout

# ------------- [Exports] -------------
## The delay time in seconds.
@export var delay: float = 0.5
## If true, the timer only fires once (standard debounce behavior).
@export var one_shot: bool = true

# ------------- [Private Variable] -------------
var _timer: Timer


# ------------- [Callbacks] -------------
func _init(p_delay: float = 0.5, p_one_shot: bool = true) -> void:
	delay = p_delay
	one_shot = p_one_shot


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = one_shot
	_timer.wait_time = delay
	_timer.autostart = false

	# Relay the internal Timer's timeout to the Debouncer's timeout signal
	_timer.timeout.connect(func() -> void: timeout.emit())
	add_child(_timer)


# ------------- [Public Method] -------------
## Starts or restarts the debounce process.
## Calling this repeatedly resets the timer, ignoring previous calls.
func call_debounced() -> void:
	if not is_inside_tree():
		return
	_timer.start(delay)


## Explicitly stops the current debounce process and prevents the timeout signal from emitting.
func cancel() -> void:
	_timer.stop()


## Updates the delay time dynamically.
func set_delay(new_delay: float) -> void:
	delay = new_delay
	_timer.wait_time = delay
