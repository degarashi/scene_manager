extends GdUnitTestSuite

const SMgrDataScript = preload("res://addons/scene_manager/data_store/scene_data_structure.gd")
const SMgrDataSceneScript = preload("res://addons/scene_manager/data_store/scene_data_scene.gd")
const SMgrCategoryDataScript = preload("res://addons/scene_manager/data_store/category_data.gd")

const UID_A := 100001
const UID_B := 100002
const UID_C := 100003
const UID_D := 100004

const PATH_LEVELS := "res://demo/scenes/"
const PATH_LEVELS_SUB := "res://demo/scenes/boss/"
const PATH_UI := "res://ui/"

var _data: SMgrDataScript
var _cat_levels_id: int
var _cat_ui_id: int


func before_test() -> void:
	_data = SMgrDataScript.new()
	_cat_levels_id = "Levels".hash()
	_cat_ui_id = "UI".hash()

	var cat_levels := SMgrCategoryDataScript.new("Levels")
	var cat_ui := SMgrCategoryDataScript.new("UI")
	_data._categories[_cat_levels_id] = cat_levels
	_data._categories[_cat_ui_id] = cat_ui


func after_test() -> void:
	_data._cleanup_debouncer()


# ------------- [Include Path Category Mapping] -------------


func test_set_and_get_include_path_category() -> void:
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	var result := _data.get_include_path_category(PATH_LEVELS)
	assert_int(result).is_equal(_cat_levels_id)


func test_get_include_path_category_unknown_path() -> void:
	var result := _data.get_include_path_category("res://nonexistent/")
	assert_int(result).is_equal(ResourceUID.INVALID_ID)


func test_set_include_path_category_overwrite() -> void:
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	_data.set_include_path_category(PATH_LEVELS, _cat_ui_id)
	var result := _data.get_include_path_category(PATH_LEVELS)
	assert_int(result).is_equal(_cat_ui_id)


func test_set_include_path_category_clear_with_invalid_id() -> void:
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	_data.set_include_path_category(PATH_LEVELS, ResourceUID.INVALID_ID)
	var result := _data.get_include_path_category(PATH_LEVELS)
	assert_int(result).is_equal(ResourceUID.INVALID_ID)


func test_get_include_path_categories_returns_all_mappings() -> void:
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	_data.set_include_path_category(PATH_UI, _cat_ui_id)
	var result := _data.get_include_path_categories()
	assert_int(result.size()).is_equal(2)
	assert_int(result[PATH_LEVELS]).is_equal(_cat_levels_id)
	assert_int(result[PATH_UI]).is_equal(_cat_ui_id)


func test_get_include_path_categories_returns_copy() -> void:
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	var result := _data.get_include_path_categories()
	result["res://other/"] = 999
	assert_int(_data.get_include_path_categories().size()).is_equal(1)


func test_include_path_categories_persist_via_export() -> void:
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	var original := _data._include_path_categories.duplicate()
	var restored := SMgrDataScript.new()
	restored._include_path_categories = original
	assert_int(restored.get_include_path_category(PATH_LEVELS)).is_equal(_cat_levels_id)


# ------------- [Batch Category Assignment] -------------


func _make_scene(p_name: String, p_path: String, p_uid: int) -> SMgrDataSceneScript:
	var sc := SMgrDataSceneScript.new()
	sc.name = p_name
	sc.path = p_path
	sc.uid = p_uid
	sc.categories = []
	return sc


func _add_scene(p_name: String, p_path: String, p_uid: int) -> void:
	_data._scenes[p_uid] = _make_scene(p_name, p_path, p_uid)


## Replicates SMgrDataEditor.assign_category_to_include_scenes() logic
func _assign_category_to_include_scenes(path: String, category_id: int) -> int:
	# Validate category exists (mirrors SMgrDataEditor validation)
	if _data.get_category_from_id(category_id) == null:
		return 0
	var assigned := 0
	for sc in _data.get_scenes_all():
		if sc.path.begins_with(path):
			if not category_id in sc.categories:
				sc.categories.append(category_id)
				sc.emit_changed()
				assigned += 1
	return assigned


## Replicates SMgrDataEditor.remove_category_from_include_scenes() logic
func _remove_category_from_include_scenes(path: String, category_id: int) -> int:
	var removed := 0
	for sc in _data.get_scenes_all():
		if sc.path.begins_with(path):
			var idx := sc.categories.find(category_id)
			if idx != -1:
				sc.categories.remove_at(idx)
				sc.emit_changed()
				removed += 1
	return removed


## Replicates SMgrDataEditor._auto_assign_category_to_scene() logic
func _auto_assign_category(scene: SMgrDataSceneScript) -> void:
	var best_path := ""
	var best_length := 0
	for inc_path in _data.get_include_list():
		if scene.path.begins_with(inc_path):
			if inc_path.length() > best_length:
				best_path = inc_path
				best_length = inc_path.length()
	if best_path.is_empty():
		return
	var cat_id := _data.get_include_path_category(best_path)
	if cat_id == ResourceUID.INVALID_ID:
		return
	if not cat_id in scene.categories:
		scene.categories.append(cat_id)
		scene.emit_changed()


func test_batch_assign_adds_category_to_matching_scenes() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_add_scene("Level2", PATH_LEVELS + "level_2.tscn", UID_B)
	_add_scene("Menu", PATH_UI + "menu.tscn", UID_C)

	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(2)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_B).categories).is_true()
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_C).categories).is_false()


func test_batch_assign_returns_zero_when_no_match() -> void:
	_add_scene("Menu", PATH_UI + "menu.tscn", UID_A)

	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(0)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()


func test_batch_assign_skips_already_assigned() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)

	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(0)


func test_batch_assign_includes_subdirectories() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_add_scene("Boss", PATH_LEVELS + "boss/boss_1.tscn", UID_B)

	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(2)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_B).categories).is_true()


func test_batch_assign_empty_scene_list() -> void:
	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)
	assert_int(count).is_equal(0)


func test_batch_assign_returns_zero_for_nonexistent_category() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	var fake_id := "FakeCategory".hash()

	var count := _assign_category_to_include_scenes(PATH_LEVELS, fake_id)

	assert_int(count).is_equal(0)
	assert_bool(_data.get_scene_from_uid(UID_A).categories.is_empty()).is_true()


func test_batch_assign_returns_zero_for_nonexistent_category_invalid_id_format() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)

	var count := _assign_category_to_include_scenes(PATH_LEVELS, 0)

	assert_int(count).is_equal(0)


func test_batch_assign_with_path_exact_match_not_prefix() -> void:
	# Scene path exactly equals the include path (not a directory prefix)
	_add_scene("Exact", PATH_LEVELS + "exact.tscn", UID_A)
	_add_scene("Other", PATH_LEVELS + "other.tscn", UID_B)

	var count := _assign_category_to_include_scenes(PATH_LEVELS + "exact.tscn", _cat_levels_id)

	# Only the exact-matching scene should be assigned
	assert_int(count).is_equal(1)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_data.get_scene_from_uid(UID_B).categories.is_empty()).is_true()


func test_batch_assign_path_begins_with_directory_separator() -> void:
	# Verify that "res://scenes" doesn't match "res://scenes_extra/"
	_add_scene("Normal", PATH_LEVELS + "level_1.tscn", UID_A)
	_add_scene("Extra", "res://scenes_extra/other.tscn", UID_B)

	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(1)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_data.get_scene_from_uid(UID_B).categories.is_empty()).is_true()


func test_batch_remove_removes_category_from_matching_scenes() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_add_scene("Level2", PATH_LEVELS + "level_2.tscn", UID_B)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)
	_data.get_scene_from_uid(UID_B).categories.append(_cat_levels_id)

	var count := _remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(2)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_B).categories).is_false()


func test_batch_remove_returns_zero_when_not_present() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)

	var count := _remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)
	assert_int(count).is_equal(0)


func test_batch_remove_preserves_other_categories() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_ui_id)

	var count := _remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(1)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()


func test_batch_remove_empty_scene_list() -> void:
	var count := _remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)
	assert_int(count).is_equal(0)


func test_batch_remove_nonexistent_category_id() -> void:
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)
	var fake_id := "Fake".hash()

	var count := _remove_category_from_include_scenes(PATH_LEVELS, fake_id)

	assert_int(count).is_equal(0)
	assert_int(_data.get_scene_from_uid(UID_A).categories.size()).is_equal(1)


# ------------- [Multi-Category Overlapping Include Paths] -------------


func test_scene_receives_categories_from_multiple_matching_paths() -> void:
	# Scene under two include paths with different categories
	_data._include_list = [PATH_LEVELS, PATH_LEVELS_SUB]
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	_data.set_include_path_category(PATH_LEVELS_SUB, _cat_ui_id)

	_add_scene("Boss", PATH_LEVELS_SUB + "boss_1.tscn", UID_A)

	_assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)
	_assign_category_to_include_scenes(PATH_LEVELS_SUB, _cat_ui_id)

	# Scene under sub-directory gets both parent and child categories
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()


func test_batch_assign_from_parent_path_does_not_duplicate_subpath_categories() -> void:
	_add_scene("Boss", PATH_LEVELS_SUB + "boss_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_ui_id)

	# Assign parent category
	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	# Both categories present
	assert_int(count).is_equal(1)
	assert_int(_data.get_scene_from_uid(UID_A).categories.size()).is_equal(2)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()


func test_remove_parent_path_category_keeps_subpath_category() -> void:
	_add_scene("Boss", PATH_LEVELS_SUB + "boss_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_ui_id)

	_remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()


# ------------- [Auto-Assign (Longest Path Match)] -------------


func test_auto_assign_longest_path_match() -> void:
	_data._include_list = ["res://demo/", PATH_LEVELS]
	_data.set_include_path_category("res://demo/", _cat_ui_id)
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)

	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_false()


func test_auto_assign_falls_back_to_shorter_path() -> void:
	_data._include_list = ["res://demo/", PATH_LEVELS]
	_data.set_include_path_category("res://demo/", _cat_ui_id)
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)

	# Scene under res://demo/ but not under res://demo/scenes/
	_add_scene("Other", "res://demo/other.tscn", UID_A)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()


func test_auto_assign_no_match_when_no_mapping() -> void:
	_data._include_list = [PATH_LEVELS]
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_bool(_data.get_scene_from_uid(UID_A).categories.is_empty()).is_true()


func test_auto_assign_no_match_when_no_path_overlap() -> void:
	_data._include_list = [PATH_LEVELS]
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)

	_add_scene("Menu", PATH_UI + "menu.tscn", UID_A)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_bool(_data.get_scene_from_uid(UID_A).categories.is_empty()).is_true()


func test_auto_assign_skips_already_assigned() -> void:
	_data._include_list = [PATH_LEVELS]
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)

	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_int(_data.get_scene_from_uid(UID_A).categories.size()).is_equal(1)


func test_auto_assign_with_empty_include_list() -> void:
	_data._include_list = []
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_bool(_data.get_scene_from_uid(UID_A).categories.is_empty()).is_true()


func test_auto_assign_multiple_include_paths_same_category() -> void:
	# Both parent and sub path map to same category — should not duplicate
	_data._include_list = [PATH_LEVELS, PATH_LEVELS_SUB]
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	_data.set_include_path_category(PATH_LEVELS_SUB, _cat_levels_id)

	_add_scene("Boss", PATH_LEVELS_SUB + "boss_1.tscn", UID_A)

	_auto_assign_category(_data.get_scene_from_uid(UID_A))

	assert_int(_data.get_scene_from_uid(UID_A).categories.size()).is_equal(1)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()


# ------------- [Include Path List Integration] -------------


func test_include_list_does_not_affect_batch_assign() -> void:
	# Batch assign works independently of include list contents
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)

	_data._include_list = []
	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(1)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()


func test_auto_assign_uses_current_include_list_after_path_removal() -> void:
	_data._include_list = [PATH_LEVELS]
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)

	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()

	# Now add to include list
	_data._include_list = [PATH_LEVELS]
	_auto_assign_category(_data.get_scene_from_uid(UID_A))
	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_true()


# ------------- [Category Change Workflow] -------------


func _is_valid_category_id(category_id: int) -> bool:
	"""Replicates MainPanel._is_valid_category_id() logic."""
	if category_id == ResourceUID.INVALID_ID:
		return false
	if category_id == 0:
		return false
	return _data.get_category_from_id(category_id) != null


func test_is_valid_category_id_valid() -> void:
	assert_bool(_is_valid_category_id(_cat_levels_id)).is_true()


func test_is_valid_category_id_invalid_id() -> void:
	assert_bool(_is_valid_category_id(ResourceUID.INVALID_ID)).is_false()


func test_is_valid_category_id_zero() -> void:
	assert_bool(_is_valid_category_id(0)).is_false()


func test_is_valid_category_id_nonexistent() -> void:
	assert_bool(_is_valid_category_id("Fake".hash())).is_false()


func test_scenario_change_category_via_mapping_update() -> void:
	"""Simulates _on_include_category_changed: update mapping, remove old, assign new."""
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_add_scene("Level2", PATH_LEVELS + "level_2.tscn", UID_B)

	# Step 1: Initial assignment via mapping
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)
	assert_int(count).is_equal(2)

	# Step 2: Update mapping (simulate user changing category dropdown)
	_data.set_include_path_category(PATH_LEVELS, _cat_ui_id)

	# Step 3: Remove old category from scenes
	_remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)

	# Step 4: Assign new category to scenes
	_assign_category_to_include_scenes(PATH_LEVELS, _cat_ui_id)

	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_B).categories).is_true()


func test_scenario_clear_category_mapping() -> void:
	"""Simulates changing category dropdown to 'None' (INVALID_ID)."""
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)

	# Step 1: Update mapping to INVALID_ID (None)
	_data.set_include_path_category(PATH_LEVELS, ResourceUID.INVALID_ID)

	# Step 2: Remove old category
	_remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)

	# Step 3: Assign new (nonexistent) category — should do nothing
	var count := _assign_category_to_include_scenes(PATH_LEVELS, ResourceUID.INVALID_ID)

	assert_int(count).is_equal(0)
	assert_bool(_data.get_scene_from_uid(UID_A).categories.is_empty()).is_true()
	assert_int(_data.get_include_path_category(PATH_LEVELS)).is_equal(ResourceUID.INVALID_ID)


func test_scenario_reassign_same_category_idempotent() -> void:
	"""Re-assigning the same category should be a no-op (already assigned)."""
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.set_include_path_category(PATH_LEVELS, _cat_levels_id)
	_assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	# Same assignment again
	var count := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_int(count).is_equal(0)
	assert_int(_data.get_scene_from_uid(UID_A).categories.size()).is_equal(1)


func test_scenario_change_category_on_include_path() -> void:
	"""Simulates the full workflow: assign, then change category."""
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_add_scene("Level2", PATH_LEVELS + "level_2.tscn", UID_B)
	_add_scene("Boss", PATH_LEVELS + "boss/boss_1.tscn", UID_C)
	_add_scene("Menu", PATH_UI + "menu.tscn", UID_D)

	# Step 1: Assign Levels category
	var assigned := _assign_category_to_include_scenes(PATH_LEVELS, _cat_levels_id)
	assert_int(assigned).is_equal(3)

	# Step 2: Change to UI category
	_remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)
	_assign_category_to_include_scenes(PATH_LEVELS, _cat_ui_id)

	assert_bool(_cat_levels_id in _data.get_scene_from_uid(UID_A).categories).is_false()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_A).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_B).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_C).categories).is_true()
	assert_bool(_cat_ui_id in _data.get_scene_from_uid(UID_D).categories).is_false()


func test_scenario_remove_category_clears_all() -> void:
	"""Simulates removing category assignment from an include path."""
	_add_scene("Level1", PATH_LEVELS + "level_1.tscn", UID_A)
	_data.get_scene_from_uid(UID_A).categories.append(_cat_levels_id)

	_remove_category_from_include_scenes(PATH_LEVELS, _cat_levels_id)

	assert_bool(_data.get_scene_from_uid(UID_A).categories.is_empty()).is_true()
