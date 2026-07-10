extends GdUnitTestSuite

const CategoryData = preload("res://addons/scene_manager/data_store/category_data.gd")


func test_default_init() -> void:
	var cat := CategoryData.new()
	assert_str(cat.name).is_equal("")
	cat._cleanup_debouncer()


func test_init_with_name() -> void:
	var cat := CategoryData.new("HUD")
	assert_str(cat.name).is_equal("HUD")
	cat._cleanup_debouncer()


func test_property_setters_trigger_emit_changed() -> void:
	var cat := CategoryData.new("UI")

	monitor_signals(cat)

	cat.name = "PauseMenu"
	await assert_signal(cat).is_emitted("changed")

	monitor_signals(cat)
	cat.layer_name = "overlay"
	await assert_signal(cat).is_emitted("changed")

	monitor_signals(cat)
	cat.layer_priority = 5
	await assert_signal(cat).is_emitted("changed")

	monitor_signals(cat)
	cat.pauses_lower_priority_layers = true
	await assert_signal(cat).is_emitted("changed")

	monitor_signals(cat)
	cat.always_process = true
	await assert_signal(cat).is_emitted("changed")

	monitor_signals(cat)
	cat.follow_viewport = true
	await assert_signal(cat).is_emitted("changed")

	cat._cleanup_debouncer()


func test_same_value_no_reemit() -> void:
	var cat := CategoryData.new("Test")

	cat.name = "Test"
	monitor_signals(cat)
	cat.name = "Test"
	await assert_signal(cat).is_not_emitted("changed")

	cat._cleanup_debouncer()
