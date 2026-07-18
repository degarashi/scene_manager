extends GdUnitTestSuite

var _debouncer: DebouncerRC


func before_test() -> void:
	# Default: 0.1s delay, one_shot = true
	_debouncer = DebouncerRC.new(0.1, true)
	monitor_signals(_debouncer)


func test_call_debounced_emits_signal() -> void:
	_debouncer.call_debounced()
	# Wait for signal to be emitted
	await assert_signal(_debouncer).is_emitted("timeout")


func test_debounce_resets_on_multiple_calls() -> void:
	_debouncer.call_debounced()
	await get_tree().create_timer(0.05).timeout
	_debouncer.call_debounced()
	await get_tree().create_timer(0.05).timeout
	_debouncer.call_debounced()

	# Wait 0.1s after last call, verify emission
	await assert_signal(_debouncer).wait_until(200).is_emitted("timeout")

	# Verify no additional emission
	await get_tree().create_timer(0.15).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


func test_cancel_prevents_emission() -> void:
	_debouncer.call_debounced()
	_debouncer.cancel()

	await get_tree().create_timer(0.2).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


func test_set_delay_updates_timing() -> void:
	_debouncer.set_delay(0.3)
	_debouncer.call_debounced()

	# At 0.2s, signal should not have been emitted yet
	await assert_signal(_debouncer).wait_until(200).is_not_emitted("timeout")

	# Verify emission after 0.3s delay
	await assert_signal(_debouncer).wait_until(200).is_emitted("timeout")


func test_one_shot_false_repeats_signal() -> void:
	# Disable one_shot
	_debouncer.set_one_shot(false)
	_debouncer.set_delay(0.1)
	_debouncer.call_debounced()

	# Verify first emission
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	# Verify second auto-emission (continuous via while loop)
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	# Verify cancel stops it
	_debouncer.cancel()
	await get_tree().create_timer(0.15).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


func test_one_shot_true_does_not_repeat() -> void:
	# Explicitly set one_shot = true
	_debouncer.set_one_shot(true)
	_debouncer.set_delay(0.1)
	_debouncer.call_debounced()

	# First emission occurs
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	# After waiting, second emission does not occur
	await get_tree().create_timer(0.2).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")
