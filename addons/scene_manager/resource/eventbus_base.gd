@tool
class_name SMgrEventBusBase
extends SMgrResource

# ------------- [Constants] -------------
const _AF = preload("uid://dlgh4u64a7qxk")

# ------------- [Private Variable] -------------
## Cache to hold signal argument names { signal_name: Array[String] }
var _sig_arg_cache: Dictionary = {}


# ------------- [Public Method] -------------
## Connects all signals to the logging callback
func connect_all_signals_to_logger() -> void:
	var script := get_script() as Script
	if not script:
		return

	for sig in script.get_script_signal_list():
		var sig_name: String = sig["name"]

		# Build cache (save list of argument names)
		var args_meta: Array = sig.get("args", [])
		_sig_arg_cache[sig_name] = args_meta.map(func(arg): return arg.get("name", "Arg"))

		# Connect
		var callable := _on_signal_emitted.bind(sig_name)
		_AF.connect_if_not_connected(Signal(self, sig_name), callable)


## Disconnects the logging connection for all signals
func disconnect_all_signals_from_logger() -> void:
	var script := get_script() as Script
	if not script:
		return

	for sig in script.get_script_signal_list():
		var sig_name: String = sig["name"]
		var target_callable := _on_signal_emitted.bind(sig_name)

		_AF.disconnect_if_connected(Signal(self, sig_name), target_callable)

	_sig_arg_cache.clear()


## Returns the total number of signals defined in this script
func get_signal_count() -> int:
	var script := get_script() as Script
	if not script:
		return 0
	return script.get_script_signal_list().size()


# ------------- [Private Method] -------------
## Generic callback executed when a signal is emitted
func _on_signal_emitted(...args: Array) -> void:
	var num_args := args.size()
	if num_args == 0:
		return

	# The last argument passed via bind() is the signal name
	var sig_name: String = args[num_args - 1]
	# Everything else is the original signal arguments
	var signal_values := args.slice(0, num_args - 1)

	var log_msg := "[EventBus Log] Signal ({0})".format([sig_name])

	if not signal_values.is_empty():
		var arg_names: Array = _sig_arg_cache.get(sig_name, [])
		var formatted_args: PackedStringArray = []

		for i in range(signal_values.size()):
			# Explicitly specify String type to avoid type inference errors
			var label: String = arg_names[i] if i < arg_names.size() else "Arg%d" % i
			formatted_args.append("{0}: {1}".format([label, str(signal_values[i])]))

		log_msg += ": <{0}>".format([", ".join(formatted_args)])

	print(log_msg)
