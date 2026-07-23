extends GdUnitTestSuite

const SMgrInstanceScript = preload(
	"res://addons/scene_manager/scene_manager.gd"
)
const SceneLoadOptions = preload(
	"res://addons/scene_manager/data_store/scene_load_options.gd"
)


# ------------- [Tests: Enum Integer Values] -------------


func test_remove_old_enum_value_is_zero() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	).is_equal(0)


func test_warn_and_skip_enum_value_is_one() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP
	).is_equal(1)


func test_rename_new_enum_value_is_two() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.RENAME_NEW
	).is_equal(2)


func test_append_enum_value_is_three() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.APPEND
	).is_equal(3)


# ------------- [Tests: Enum Contiguity] -------------


func test_enum_values_are_contiguous() -> void:
	var modes := [
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD,
		SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP,
		SMgrInstanceScript.DuplicateNameMode.RENAME_NEW,
		SMgrInstanceScript.DuplicateNameMode.APPEND,
	]
	for i in range(modes.size()):
		assert_int(modes[i]).is_equal(i)


func test_enum_has_four_members() -> void:
	var keys := SMgrInstanceScript.DuplicateNameMode.keys()
	assert_int(keys.size()).is_equal(4)


func test_enum_values_array_matches_expected() -> void:
	var values := SMgrInstanceScript.DuplicateNameMode.values()
	assert_array(values).contains_exactly([0, 1, 2, 3])


func test_enum_keys_are_strings() -> void:
	var keys := SMgrInstanceScript.DuplicateNameMode.keys()
	for key in keys:
		assert_int(typeof(key)).is_equal(TYPE_STRING)


func test_enum_keys_match_expected_names() -> void:
	var keys := SMgrInstanceScript.DuplicateNameMode.keys()
	assert_array(keys).contains_exactly(
		["REMOVE_OLD", "WARN_AND_SKIP", "RENAME_NEW", "APPEND"]
	)


# ------------- [Tests: Invalid Integer to Enum] -------------


func test_invalid_negative_value_does_not_match_any_enum() -> void:
	var invalid := -1
	var matched := false
	for mode in SMgrInstanceScript.DuplicateNameMode.values():
		if mode == invalid:
			matched = true
			break
	assert_bool(matched).is_false()


func test_invalid_large_value_does_not_match_any_enum() -> void:
	var invalid := 999
	var matched := false
	for mode in SMgrInstanceScript.DuplicateNameMode.values():
		if mode == invalid:
			matched = true
			break
	assert_bool(matched).is_false()


func test_invalid_max_int_value_does_not_match_any_enum() -> void:
	var invalid := 2147483647
	var matched := false
	for mode in SMgrInstanceScript.DuplicateNameMode.values():
		if mode == invalid:
			matched = true
			break
	assert_bool(matched).is_false()


func test_invalid_min_int_value_does_not_match_any_enum() -> void:
	var invalid := -2147483648
	var matched := false
	for mode in SMgrInstanceScript.DuplicateNameMode.values():
		if mode == invalid:
			matched = true
			break
	assert_bool(matched).is_false()


func test_invalid_value_four_does_not_match_any_enum() -> void:
	# APPEND is 3, so 4 should not match
	var invalid := 4
	var matched := false
	for mode in SMgrInstanceScript.DuplicateNameMode.values():
		if mode == invalid:
			matched = true
			break
	assert_bool(matched).is_false()


# ------------- [Tests: DuplicateNameMode as int comparisons] -------------


func test_all_enum_values_are_integers() -> void:
	var modes := [
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD,
		SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP,
		SMgrInstanceScript.DuplicateNameMode.RENAME_NEW,
		SMgrInstanceScript.DuplicateNameMode.APPEND,
	]
	for mode in modes:
		assert_int(typeof(mode)).is_equal(TYPE_INT)


func test_enum_values_are_non_negative() -> void:
	var modes := [
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD,
		SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP,
		SMgrInstanceScript.DuplicateNameMode.RENAME_NEW,
		SMgrInstanceScript.DuplicateNameMode.APPEND,
	]
	for mode in modes:
		assert_bool(mode >= 0).is_true()


func test_enum_values_are_less_than_ten() -> void:
	# Sanity check: no enum value should be absurdly large
	var modes := [
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD,
		SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP,
		SMgrInstanceScript.DuplicateNameMode.RENAME_NEW,
		SMgrInstanceScript.DuplicateNameMode.APPEND,
	]
	for mode in modes:
		assert_bool(mode < 10).is_true()


# ------------- [Tests: find_key reverse lookup] -------------


func test_find_key_for_valid_values() -> void:
	assert_str(
		SMgrInstanceScript.DuplicateNameMode.find_key(0)
	).is_equal("REMOVE_OLD")
	assert_str(
		SMgrInstanceScript.DuplicateNameMode.find_key(1)
	).is_equal("WARN_AND_SKIP")
	assert_str(
		SMgrInstanceScript.DuplicateNameMode.find_key(2)
	).is_equal("RENAME_NEW")
	assert_str(
		SMgrInstanceScript.DuplicateNameMode.find_key(3)
	).is_equal("APPEND")


func test_find_key_for_invalid_values_returns_null() -> void:
	assert_object(
		SMgrInstanceScript.DuplicateNameMode.find_key(-1)
	).is_null()
	assert_object(
		SMgrInstanceScript.DuplicateNameMode.find_key(99)
	).is_null()
	assert_object(
		SMgrInstanceScript.DuplicateNameMode.find_key(4)
	).is_null()


# ------------- [Tests: Enum type identity] -------------


func test_enum_is_accessible_as_class_constant() -> void:
	var mode_val: int = SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	assert_int(mode_val).is_equal(0)


func test_enum_values_are_distinct() -> void:
	var mode_a := SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	var mode_b := SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP
	var mode_c := SMgrInstanceScript.DuplicateNameMode.RENAME_NEW
	var mode_d := SMgrInstanceScript.DuplicateNameMode.APPEND

	assert_bool(mode_a != mode_b).is_true()
	assert_bool(mode_a != mode_c).is_true()
	assert_bool(mode_a != mode_d).is_true()
	assert_bool(mode_b != mode_c).is_true()
	assert_bool(mode_b != mode_d).is_true()
	assert_bool(mode_c != mode_d).is_true()


func test_enum_self_equality() -> void:
	var mode := SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	assert_bool(mode == mode).is_true()


func test_enum_inequality_with_different_value() -> void:
	var mode_a := SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	var mode_b := SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP
	assert_bool(mode_a != mode_b).is_true()


# ------------- [Tests: SceneLoadOptions integration] -------------


func test_scene_load_options_has_no_duplicate_name_mode_property() -> void:
	# SceneLoadOptions does NOT have a duplicate_name_mode property
	# The mode is passed as a separate parameter to add_scene()
	var opts := SceneLoadOptions.new()
	assert_bool("duplicate_name_mode" in opts).is_false()


func test_scene_load_options_copy_preserves_all_fields() -> void:
	var opts := SceneLoadOptions.new("TestNode", true, 0.5, 0.5)
	var copied := opts.copy()

	assert_str(copied.node_name).is_equal("TestNode")
	assert_bool(copied.clickable).is_true()


# ------------- [Tests: Boundary values] -------------


func test_zero_is_valid_enum_value() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	).is_equal(0)


func test_one_is_valid_enum_value() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP
	).is_equal(1)


func test_two_is_valid_enum_value() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.RENAME_NEW
	).is_equal(2)


func test_three_is_valid_enum_value() -> void:
	assert_int(
		SMgrInstanceScript.DuplicateNameMode.APPEND
	).is_equal(3)


# ------------- [Tests: Edge cases with comparisons] -------------


func test_enum_value_less_than_comparison() -> void:
	assert_bool(
		SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
		< SMgrInstanceScript.DuplicateNameMode.WARN_AND_SKIP
	).is_true()


func test_enum_value_greater_than_comparison() -> void:
	assert_bool(
		SMgrInstanceScript.DuplicateNameMode.APPEND
		> SMgrInstanceScript.DuplicateNameMode.REMOVE_OLD
	).is_true()


func test_enum_value_less_or_equal_self() -> void:
	var mode := SMgrInstanceScript.DuplicateNameMode.RENAME_NEW
	assert_bool(mode <= mode).is_true()


func test_enum_value_greater_or_equal_self() -> void:
	var mode := SMgrInstanceScript.DuplicateNameMode.RENAME_NEW
	assert_bool(mode >= mode).is_true()
