extends GdUnitTestSuite

var _debouncer: DebouncerRC


func before_test() -> void:
	# デフォルトで 0.1秒、one_shot = true
	_debouncer = DebouncerRC.new(0.1, true)
	monitor_signals(_debouncer)


func test_call_debounced_emits_signal() -> void:
	_debouncer.call_debounced()
	# シグナルが発行されるまで待機
	await assert_signal(_debouncer).is_emitted("timeout")


func test_debounce_resets_on_multiple_calls() -> void:
	_debouncer.call_debounced()
	await get_tree().create_timer(0.05).timeout
	_debouncer.call_debounced()
	await get_tree().create_timer(0.05).timeout
	_debouncer.call_debounced()

	# 最後の呼び出しから0.1秒待機して発行を確認
	await assert_signal(_debouncer).wait_until(200).is_emitted("timeout")

	# 追加の発行がないことを確認
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

	# 0.2秒時点ではまだ発行されていないはず
	await assert_signal(_debouncer).wait_until(200).is_not_emitted("timeout")

	# 0.3秒のディレイ後に発行を確認
	await assert_signal(_debouncer).wait_until(200).is_emitted("timeout")


func test_one_shot_false_repeats_signal() -> void:
	# one_shot を無効化
	_debouncer.set_one_shot(false)
	_debouncer.set_delay(0.1)
	_debouncer.call_debounced()

	# 1回目の発行を確認
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	# 2回目の自動発行を確認 (whileループによる継続)
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	# キャンセルして止まることを確認
	_debouncer.cancel()
	await get_tree().create_timer(0.15).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")


func test_one_shot_true_does_not_repeat() -> void:
	# 明示的に one_shot = true に設定
	_debouncer.set_one_shot(true)
	_debouncer.set_delay(0.1)
	_debouncer.call_debounced()

	# 1回目は発行される
	await assert_signal(_debouncer).wait_until(150).is_emitted("timeout")

	# その後、待機しても2回目は発行されない
	await get_tree().create_timer(0.2).timeout
	assert_signal(_debouncer).is_not_emitted("timeout")
