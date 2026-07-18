extends GdUnitTestSuite

const DebouncerScript = preload("res://addons/scene_manager/debouncer.gd")

var _debouncer: Debouncer


func before_test() -> void:
	_debouncer = DebouncerScript.new(0.1, true)
	add_child(_debouncer)
	monitor_signals(_debouncer)


func after_test() -> void:
	if is_instance_valid(_debouncer):
		_debouncer.queue_free()


# ------------- [Default Values] -------------

func test_default_values() -> void:
	var d := DebouncerScript.new()
	assert_float(d.delay).is_equal(0.5)
	assert_bool(d.one_shot).is_true()
	d.free()


func test_constructor_params() -> void:
	var d := DebouncerScript.new(0.25, false)
	assert_float(d.delay).is_equal(0.25)
	assert_bool(d.one_shot).is_false()
	d.free()


# ------------- [Debounce Behavior] -------------

func test_call_debounced_emits_signal() -> void:
	_debouncer.call_debounced()
	await assert_signal(_debouncer).is_emitted("timeout")


func test_debounce_resets_on_multiple_calls() -> void:
	_debouncer.call_debounced()
	await get_tree().create_timer(0.05).timeout
	_debouncer.call_debounced()
	await get_tree().create_timer(0.05).timeout
	_debouncer.call_debounced()

	# Only the last call should fire
	await assert_signal(_debouncer).wait_until(200).is_emitted("timeout")

	# No additional emission
	await get_tree().create_timer(0.15).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


func test_cancel_prevents_emission() -> void:
	_debouncer.call_debounced()
	_debouncer.cancel()

	await get_tree().create_timer(0.2).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


# ------------- [Dynamic Configuration] -------------

func test_set_delay_updates_timing() -> void:
	_debouncer.set_delay(0.3)
	_debouncer.call_debounced()

	# 0.2s: not yet emitted
	await assert_signal(_debouncer).wait_until(200).is_not_emitted("timeout")
	# 0.3s: should fire
	await assert_signal(_debouncer).wait_until(200).is_emitted("timeout")


func test_one_shot_false_repeats_signal() -> void:
	_debouncer.set_one_shot(false)
	_debouncer.set_delay(0.1)
	_debouncer.call_debounced()

	# First emission
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")
	# Second emission (auto-restart from one_shot=false)
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	_debouncer.cancel()
	await get_tree().create_timer(0.15).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


func test_one_shot_true_does_not_repeat() -> void:
	_debouncer.set_one_shot(true)
	_debouncer.set_delay(0.1)
	_debouncer.call_debounced()

	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")
	await get_tree().create_timer(0.2).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


# ------------- [Edge Cases] -------------

func test_call_debounced_not_in_tree() -> void:
	# Instance not added to tree — is_inside_tree() is false
	var d := DebouncerScript.new(0.1, true)
	# Should be a no-op (no crash)
	d.call_debounced()
	d.free()
