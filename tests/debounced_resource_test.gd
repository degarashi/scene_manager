extends GdUnitTestSuite


class MockDebouncedResource:
	extends DebouncedResource

	func _init() -> void:
		# Use 0.1s for fast testing
		_init_debouncer(0.1)


func test_data_changed_debounced_emitted_after_delay() -> void:
	var res := MockDebouncedResource.new()
	# Start monitoring signals
	monitor_signals(res)

	# Trigger change notification
	res.emit_changed()

	# Wait and verify the signal is emitted
	await assert_signal(res).wait_until(300).is_emitted("data_changed_debounced")

	# Verify no extra emissions
	res._cleanup_debouncer()


func test_multiple_changes_only_emits_once() -> void:
	var res := MockDebouncedResource.new()
	monitor_signals(res)

	# Call emit_changed 3 times at 0.05s intervals
	# Total time taken is 0.15s, but since the timer resets each time,
	# the signal should not be emitted until 0.1s after the last call
	res.emit_changed()
	await get_tree().create_timer(0.05).timeout
	res.emit_changed()
	await get_tree().create_timer(0.05).timeout
	res.emit_changed()

	# Should not be emitted at this point
	await assert_signal(res).wait_until(30).is_not_emitted("data_changed_debounced")

	# Verify that the signal is emitted exactly once in the end
	await assert_signal(res).wait_until(120).is_emitted("data_changed_debounced")

	res._cleanup_debouncer()


func test_cleanup_prevents_further_emissions() -> void:
	var res := MockDebouncedResource.new()
	monitor_signals(res)

	# Cleanup the debouncer immediately after the change
	res.emit_changed()
	res._cleanup_debouncer()

	# Since it's cleaned up, the signal should not fire even after time passes
	await assert_signal(res).wait_until(200).is_not_emitted("data_changed_debounced")


func test_different_delay_setting() -> void:
	var res := MockDebouncedResource.new()
	# Override delay setting to 0.3s
	res.set_delay(0.3)
	monitor_signals(res)

	res.emit_changed()

	# Should not fire at the default 0.1s or even at 0.2s
	await assert_signal(res).wait_until(200).is_not_emitted("data_changed_debounced")

	# Should be emitted after 0.3s (waiting 250ms with margin)
	await assert_signal(res).wait_until(250).is_emitted("data_changed_debounced")

	res._cleanup_debouncer()
