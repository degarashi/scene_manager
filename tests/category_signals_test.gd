extends GdUnitTestSuite

const CategoryDataScript = preload("res://addons/scene_manager/data_store/category_data.gd")
const SMgrDataScript = preload("res://addons/scene_manager/data_store/scene_data_structure.gd")

var _scenes_cls: Node


func before() -> void:
	_scenes_cls = preload("res://scene_manager_data/scenes.gd").new()
	add_child(_scenes_cls)
	# monitor_signals(SceneManager, false)
	await get_tree().create_timer(1.5).timeout


func after() -> void:
	await get_tree().create_timer(0.5).timeout


func test_category_changed_signal_declaration() -> void:
	var signal_names: Array[StringName] = []
	for sig in SceneManager.get_signal_list():
		signal_names.append(sig["name"])
	assert_bool(signal_names.has(&"category_changed")).is_true()


func test_category_reapplied_signal_declaration() -> void:
	var signal_names: Array[StringName] = []
	for sig in SceneManager.get_signal_list():
		signal_names.append(sig["name"])
	assert_bool(signal_names.has(&"category_reapplied")).is_true()


func test_category_tags_notified_signal_declaration() -> void:
	var signal_names: Array[StringName] = []
	for sig in SceneManager.get_signal_list():
		signal_names.append(sig["name"])
	assert_bool(signal_names.has(&"category_tags_notified")).is_true()


func test_category_changed_signal_connection() -> void:
	var callback_called := false
	var callback := func(_diff: Variant) -> void:
		callback_called = true

	SceneManager.category_changed.connect(callback)
	assert_bool(SceneManager.category_changed.is_connected(callback)).is_true()

	SceneManager.category_changed.disconnect(callback)
	assert_bool(SceneManager.category_changed.is_connected(callback)).is_false()
	await get_tree().create_timer(0.5).timeout


func test_category_reapplied_signal_connection() -> void:
	var callback := func(_tags: Variant) -> void:
		pass

	SceneManager.category_reapplied.connect(callback)
	assert_bool(SceneManager.category_reapplied.is_connected(callback)).is_true()

	SceneManager.category_reapplied.disconnect(callback)
	assert_bool(SceneManager.category_reapplied.is_connected(callback)).is_false()
	await get_tree().create_timer(0.5).timeout


func test_category_tags_notified_signal_connection() -> void:
	var callback := func(_tags: Variant) -> void:
		pass

	SceneManager.category_tags_notified.connect(callback)
	assert_bool(SceneManager.category_tags_notified.is_connected(callback)).is_true()

	SceneManager.category_tags_notified.disconnect(callback)
	assert_bool(SceneManager.category_tags_notified.is_connected(callback)).is_false()
	await get_tree().create_timer(0.5).timeout


func test_category_changed_signal_argument_type() -> void:
	# GDScript lambdas capture by value; use an Array to share state
	var received := [null]
	var callback := func(diff: Variant) -> void:
		received[0] = diff

	SceneManager.category_changed.connect(callback)

	var diff := SMgrData.CategoryDiff.new([], [])
	SceneManager.category_changed.emit(diff)

	assert_object(received[0]).is_not_null()
	assert_bool(received[0] is Object).is_true()

	SceneManager.category_changed.disconnect(callback)
	await get_tree().create_timer(0.5).timeout


func test_category_reapplied_signal_argument_type() -> void:
	var received := [null]
	var callback := func(tags: Variant) -> void:
		received[0] = tags

	SceneManager.category_reapplied.connect(callback)

	var tags: Array[ScenesClass.CategoryId] = []
	SceneManager.category_reapplied.emit(tags)

	assert_object(received[0]).is_not_null()
	assert_bool(received[0] is Array).is_true()

	SceneManager.category_reapplied.disconnect(callback)
	await get_tree().create_timer(0.5).timeout


func test_category_tags_notified_signal_argument_type() -> void:
	var received := [null]
	var callback := func(tags: Variant) -> void:
		received[0] = tags

	SceneManager.category_tags_notified.connect(callback)

	var tags: Array[ScenesClass.CategoryId] = []
	SceneManager.category_tags_notified.emit(tags)

	assert_object(received[0]).is_not_null()
	assert_bool(received[0] is Array).is_true()

	SceneManager.category_tags_notified.disconnect(callback)
	await get_tree().create_timer(0.5).timeout


func test_category_diff_object_structure() -> void:
	var diff := SMgrDataScript.CategoryDiff.new([], [])

	assert_bool("added" in diff).is_true()
	assert_bool("removed" in diff).is_true()
	assert_bool("unchanged" in diff).is_true()
	await get_tree().create_timer(0.5).timeout


func test_category_diff_added_categories() -> void:
	var current_cats: Array[ScenesClass.CategoryId] = []
	var target_cats: Array[ScenesClass.CategoryId] = [100, 200]
	var diff := SMgrDataScript.CategoryDiff.new(current_cats, target_cats)

	assert_int(diff.added.size()).is_equal(2)
	assert_bool(100 in diff.added).is_true()
	assert_bool(200 in diff.added).is_true()
	await get_tree().create_timer(0.5).timeout


func test_category_diff_removed_categories() -> void:
	var current_cats: Array[ScenesClass.CategoryId] = [100, 200]
	var target_cats: Array[ScenesClass.CategoryId] = []
	var diff := SMgrDataScript.CategoryDiff.new(current_cats, target_cats)

	assert_int(diff.removed.size()).is_equal(2)
	assert_bool(100 in diff.removed).is_true()
	assert_bool(200 in diff.removed).is_true()
	await get_tree().create_timer(0.5).timeout


func test_category_diff_unchanged_categories() -> void:
	var current_cats: Array[ScenesClass.CategoryId] = [100, 200]
	var target_cats: Array[ScenesClass.CategoryId] = [100, 200]
	var diff := SMgrDataScript.CategoryDiff.new(current_cats, target_cats)

	assert_int(diff.unchanged.size()).is_equal(2)
	assert_bool(100 in diff.unchanged).is_true()
	assert_bool(200 in diff.unchanged).is_true()
	await get_tree().create_timer(0.5).timeout


func test_category_diff_mixed_changes() -> void:
	var current_cats: Array[ScenesClass.CategoryId] = [100, 200]
	var target_cats: Array[ScenesClass.CategoryId] = [200, 300]
	var diff := SMgrDataScript.CategoryDiff.new(current_cats, target_cats)

	assert_int(diff.added.size()).is_equal(1)
	assert_int(diff.removed.size()).is_equal(1)
	assert_int(diff.unchanged.size()).is_equal(1)
	assert_bool(300 in diff.added).is_true()
	assert_bool(100 in diff.removed).is_true()
	assert_bool(200 in diff.unchanged).is_true()
	await get_tree().create_timer(0.5).timeout


func test_category_diff_to_string() -> void:
	var current_cats: Array[ScenesClass.CategoryId] = [100]
	var target_cats: Array[ScenesClass.CategoryId] = [200]
	var diff := SMgrDataScript.CategoryDiff.new(current_cats, target_cats)

	var result := diff._to_string()
	assert_str(result).contains("Added")
	assert_str(result).contains("Removed")
	assert_str(result).contains("Unchanged")
	await get_tree().create_timer(0.5).timeout


func test_category_data_changed_signal_emission() -> void:
	var cat := CategoryDataScript.new("TestCategory")
	monitor_signals(cat)

	cat.name = "UpdatedCategory"
	await assert_signal(cat).is_emitted("changed")

	cat._cleanup_debouncer()


func test_category_data_no_reemit_on_same_value() -> void:
	var cat := CategoryDataScript.new("SameValue")

	cat.name = "SameValue"
	monitor_signals(cat)
	cat.name = "SameValue"
	await assert_signal(cat).is_not_emitted("changed")

	cat._cleanup_debouncer()


func test_multiple_signal_connections() -> void:
	var callback1_called := [false]
	var callback2_called := [false]

	var callback1 := func(_diff: Variant) -> void:
		callback1_called[0] = true
	var callback2 := func(_diff: Variant) -> void:
		callback2_called[0] = true

	SceneManager.category_changed.connect(callback1)
	SceneManager.category_changed.connect(callback2)

	var diff := SMgrDataScript.CategoryDiff.new([], [])
	SceneManager.category_changed.emit(diff)

	assert_bool(callback1_called[0]).is_true()
	assert_bool(callback2_called[0]).is_true()

	SceneManager.category_changed.disconnect(callback1)
	SceneManager.category_changed.disconnect(callback2)
	await get_tree().create_timer(0.5).timeout


func test_signal_emission_timing_category_changed() -> void:
	var emission_order: Array[String] = []
	var callback := func(_diff: Variant) -> void:
		emission_order.append("category_changed")

	SceneManager.category_changed.connect(callback)

	var diff := SMgrDataScript.CategoryDiff.new([], [])
	SceneManager.category_changed.emit(diff)

	assert_int(emission_order.size()).is_equal(1)
	assert_str(emission_order[0]).is_equal("category_changed")

	SceneManager.category_changed.disconnect(callback)
	await get_tree().create_timer(0.5).timeout


func test_signal_emission_category_reapplied() -> void:
	var emission_order: Array[String] = []
	var callback := func(_tags: Variant) -> void:
		emission_order.append("category_reapplied")

	SceneManager.category_reapplied.connect(callback)

	var tags: Array[ScenesClass.CategoryId] = []
	SceneManager.category_reapplied.emit(tags)

	assert_int(emission_order.size()).is_equal(1)
	assert_str(emission_order[0]).is_equal("category_reapplied")

	SceneManager.category_reapplied.disconnect(callback)
	await get_tree().create_timer(0.5).timeout


func test_signal_emission_category_tags_notified() -> void:
	var emission_order: Array[String] = []
	var callback := func(_tags: Variant) -> void:
		emission_order.append("category_tags_notified")

	SceneManager.category_tags_notified.connect(callback)

	var tags: Array[ScenesClass.CategoryId] = []
	SceneManager.category_tags_notified.emit(tags)

	assert_int(emission_order.size()).is_equal(1)
	assert_str(emission_order[0]).is_equal("category_tags_notified")

	SceneManager.category_tags_notified.disconnect(callback)
	await get_tree().create_timer(0.5).timeout


func test_category_diff_empty_arrays() -> void:
	var current_cats: Array[ScenesClass.CategoryId] = []
	var target_cats: Array[ScenesClass.CategoryId] = []
	var diff := SMgrDataScript.CategoryDiff.new(current_cats, target_cats)

	assert_int(diff.added.size()).is_equal(0)
	assert_int(diff.removed.size()).is_equal(0)
	assert_int(diff.unchanged.size()).is_equal(0)
	await get_tree().create_timer(0.5).timeout


func test_category_data_all_property_changes_emit_changed() -> void:
	var cat := CategoryDataScript.new("FullTest")

	monitor_signals(cat)
	cat.layer_name = "test_layer"
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
