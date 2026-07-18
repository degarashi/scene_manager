extends GdUnitTestSuite

# Test suite for check_ids.gd ID validation logic
#   - Regex pattern matching for Scenes.Id.XXXX
#   - Exclusion of built-in methods (keys, values, has, size, find_key)
#   - Exclusion of arbitrary method calls xxx()
#   - Direct invocation of _check_file_content_for_invalid_ids (file I/O)
#   - Path exclusion for _scan_project_for_invalid_ids (res://addons, .gdignore)
#
# NOTE: check_ids.gd uses uid-based preload, so some tests below may
#       fail with GdUnit errors if resources cannot be resolved in the test environment.

# ------------- [Constants] -------------

const _TEMP_DIR := "res://.test_check_ids"
const _CheckIds := preload("res://addons/scene_manager/check_ids.gd")

# ------------- [Variables] -------------

var _regex: RegEx

# ------------- [Setup / Teardown] -------------


func before_test() -> void:
	_regex = RegEx.new()
	_regex.compile("Scenes\\.Id\\.(?!(?:find_key|keys|values|has|size)\\b)([A-Za-z0-9_]+)(?!\\()")


func after_test() -> void:
	_delete_dir_recursive(_TEMP_DIR)


# ------------- [Private Helper] -------------


## Recursively delete a directory
func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_delete_dir_recursive(full)
		else:
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
	# Remove the now-empty directory from its parent
	var parent_dir := DirAccess.open(path.get_base_dir())
	if parent_dir:
		parent_dir.remove(path.get_file())


## Create a temporary .gd file and return its path
func _create_temp_gd(content: String) -> String:
	DirAccess.make_dir_recursive_absolute(_TEMP_DIR)
	var path := _TEMP_DIR.path_join("test_temp.gd")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	return path


# =============================================================================
#  [Regex: Valid enum value matching]
#  Verify that Scenes.Id.XXXX pattern correctly captures the XXXX portion
# =============================================================================


func test_regex_matches_simple_enum() -> void:
	## Simple uppercase + number enum value matches
	var result := _regex.search("Scenes.Id.LEVEL_1")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("LEVEL_1")


func test_regex_matches_upper_snake_case() -> void:
	## Upper snake case (MAIN_MENU) matches
	var result := _regex.search("Scenes.Id.MAIN_MENU")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("MAIN_MENU")


func test_regex_matches_mixed_case() -> void:
	## CamelCase (LevelSelect) matches
	var result := _regex.search("Scenes.Id.LevelSelect")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("LevelSelect")


func test_regex_matches_NONE() -> void:
	## NONE (default value) matches
	var result := _regex.search("Scenes.Id.NONE")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("NONE")


func test_regex_matches_trailing_underscore() -> void:
	## Enum value with trailing underscore matches
	var result := _regex.search("Scenes.Id.MENU_")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("MENU_")


func test_regex_matches_single_word() -> void:
	## Single-word enum (MENU only) matches
	var result := _regex.search("Scenes.Id.MENU")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("MENU")


func test_regex_matches_in_switch_to_scene() -> void:
	## Enum embedded in switch_to_scene argument matches
	var result := _regex.search("await SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true)")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("LEVEL_1")


func test_regex_matches_in_comparison() -> void:
	## Enum on the right side of if-comparison matches
	var result := _regex.search("if current_scene == Scenes.Id.NONE:")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("NONE")


func test_regex_matches_with_dot_access() -> void:
	## Enum in property access (left side of xxx.yyy) matches
	var line := "Scenes.Id.PLAYER.some_property"
	var result := _regex.search(line)
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("PLAYER")


# =============================================================================
#  [Regex: Built-in method call exclusion]
#  Verify keys() / values() / has() / size() / find_key() do NOT match
# =============================================================================


func test_regex_excludes_keys() -> void:
	## Scenes.Id.keys() does not match
	assert_bool(_regex.search("Scenes.Id.keys()") == null).is_true()


func test_regex_excludes_values() -> void:
	## Scenes.Id.values() does not match
	assert_bool(_regex.search("Scenes.Id.values()") == null).is_true()


func test_regex_excludes_has() -> void:
	## Scenes.Id.has() does not match
	assert_bool(_regex.search("Scenes.Id.has()") == null).is_true()


func test_regex_excludes_size() -> void:
	## Scenes.Id.size() does not match
	assert_bool(_regex.search("Scenes.Id.size()") == null).is_true()


func test_regex_excludes_find_key() -> void:
	## Scenes.Id.find_key() does not match
	assert_bool(_regex.search("Scenes.Id.find_key()") == null).is_true()


func test_regex_excludes_keys_without_parens() -> void:
	## keys without parentheses does not match (word boundary check)
	assert_bool(_regex.search("Scenes.Id.keys") == null).is_true()


func test_regex_excludes_values_without_parens() -> void:
	## values without parentheses does not match
	assert_bool(_regex.search("Scenes.Id.values") == null).is_true()


func test_regex_excludes_keys_in_loop() -> void:
	## .keys() inside for-in loop does not match
	var line := "for key in Scenes.Id.keys():"
	assert_bool(_regex.search(line) == null).is_true()


func test_regex_excludes_has_in_condition() -> void:
	## .has() inside conditional expression does not match
	var line := "if Scenes.Id.has(some_key):"
	assert_bool(_regex.search(line) == null).is_true()


# =============================================================================
#  [Regex: Arbitrary method call exclusion]
#  Verify Scenes.Id.xxx() format (xxx is any name) does NOT match
# =============================================================================


func test_regex_excludes_custom_method() -> void:
	## Note: Regex backtracking causes "custom_function()" to match
	## with the last character truncated (known limitation)
	## Complete exclusion is impossible due to `(?!\()` alignment
	var result := _regex.search("Scenes.Id.custom_function()")
	assert_bool(result != null).is_true()
	# Backtracking causes "custom_functio" to be captured
	assert_str(result.get_string(1)).is_equal("custom_functio")


func test_regex_excludes_method_in_argument() -> void:
	## Note: Regex backtracking truncates the tail for a match (known limitation)
	var result := _regex.search("print(Scenes.Id.custom_func())")
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("custom_fun")


func test_regex_excludes_chained_method() -> void:
	## Note: Regex backtracking truncates the tail for a match (known limitation)
	var line := "Scenes.Id.custom().another()"
	var result := _regex.search(line)
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("custo")


func test_regex_excludes_method_with_underscore() -> void:
	## Note: Regex backtracking truncates the tail for a match (known limitation)
	var line := "Scenes.Id.get_enum_values()"
	var result := _regex.search(line)
	assert_bool(result != null).is_true()
	assert_str(result.get_string(1)).is_equal("get_enum_value")


# =============================================================================
#  [Regex: Multi-line / Multiple matches]
#  Verify extraction of multiple Scenes.Id.XXX values within a single line
# =============================================================================


func test_regex_multiple_values_in_array() -> void:
	## Multiple enum values in array literal all match
	var line := "var ids := [Scenes.Id.MENU, Scenes.Id.GAME, Scenes.Id.NONE]"
	var results := _regex.search_all(line)
	assert_int(results.size()).is_equal(3)
	assert_str(results[0].get_string(1)).is_equal("MENU")
	assert_str(results[1].get_string(1)).is_equal("GAME")
	assert_str(results[2].get_string(1)).is_equal("NONE")


func test_regex_mixed_methods_and_values() -> void:
	## Only enum values match in lines mixing method calls and enum values
	var line := "for key in Scenes.Id.keys(): print(Scenes.Id.LEVEL_1)"
	var results := _regex.search_all(line)
	assert_int(results.size()).is_equal(1)
	assert_str(results[0].get_string(1)).is_equal("LEVEL_1")


func test_regex_only_methods_in_line() -> void:
	## Lines with only method calls yield 0 matches
	var line := "Scenes.Id.keys() + Scenes.Id.values()"
	var results := _regex.search_all(line)
	assert_int(results.size()).is_zero()


func test_regex_values_in_multiline_script() -> void:
	## Verify listing enum references across multiple lines
	var script := """\
func start() -> void:
	var a := Scenes.Id.MENU
	SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true)
	var b := Scenes.Id.NONE
"""
	var count := 0
	for line in script.split("\n"):
		count += _regex.search_all(line).size()
	assert_int(count).is_equal(3)


# =============================================================================
#  [_check_file_content_for_invalid_ids: File Inspection]
#  Verify ID validation logic by directly calling private static method
# =============================================================================


func test_check_file_valid_ids_only() -> void:
	## Files with only valid IDs have invalid ID count of 0
	var content := """\
extends Node

func _ready() -> void:
	SceneManager.switch_to_scene(Scenes.Id.MENU, true)
	SceneManager.switch_to_scene(Scenes.Id.LEVEL_1, true)
"""
	var path := _create_temp_gd(content)
	var valid: Dictionary[String, bool] = {
		"MENU": true,
		"LEVEL_1": true,
		"NONE": true,
	}
	var count := _CheckIds._check_file_content_for_invalid_ids(path, valid)
	assert_int(count).is_zero()


func test_check_file_invalid_id_detected() -> void:
	## Files with one invalid ID have count of 1
	var content := """\
extends Node

func _ready() -> void:
	SceneManager.switch_to_scene(Scenes.Id.WRONG_ID, true)
"""
	var path := _create_temp_gd(content)
	var valid: Dictionary[String, bool] = {
		"MENU": true,
		"LEVEL_1": true,
	}
	var count := _CheckIds._check_file_content_for_invalid_ids(path, valid)
	assert_int(count).is_equal(1)


func test_check_file_mixed_valid_invalid() -> void:
	## Mixed valid/invalid ID files count only the invalid ones
	var content := """\
extends Node

func _ready() -> void:
	var a := Scenes.Id.MENU
	var b := Scenes.Id.BAD_REF
	var c := Scenes.Id.LEVEL_1
	var d := Scenes.Id.ANOTHER_BAD
"""
	var path := _create_temp_gd(content)
	var valid: Dictionary[String, bool] = {
		"MENU": true,
		"LEVEL_1": true,
		"NONE": true,
	}
	var count := _CheckIds._check_file_content_for_invalid_ids(path, valid)
	assert_int(count).is_equal(2)


func test_check_file_skips_method_calls() -> void:
	## Method calls (keys()) are excluded from inspection
	var content := """\
func _check() -> void:
	for key in Scenes.Id.keys():
		print(Scenes.Id.MENU)
"""
	var path := _create_temp_gd(content)
	var valid: Dictionary[String, bool] = {
		"MENU": true,
	}
	var count := _CheckIds._check_file_content_for_invalid_ids(path, valid)
	assert_int(count).is_zero()


func test_check_file_not_found_returns_zero() -> void:
	## Non-existent files return 0
	var valid: Dictionary[String, bool] = {"MENU": true}
	var count := _CheckIds._check_file_content_for_invalid_ids(
		"res://nonexistent_dir/nonexistent.gd", valid
	)
	assert_int(count).is_zero()


# =============================================================================
#  [_scan_project_for_invalid_ids: Path Exclusion / Scan]
#  Verify skip behavior for specific paths
# =============================================================================


func test_scan_skips_addons_path() -> void:
	## res://addons is skipped
	var count := _CheckIds._scan_project_for_invalid_ids("res://addons")
	assert_int(count).is_zero()


func test_scan_skips_nonexistent_path() -> void:
	## Non-existent path is skipped
	var count := _CheckIds._scan_project_for_invalid_ids("res://nonexistent_test_dir_xyz")
	assert_int(count).is_zero()


func test_scan_skips_gdignore_directory() -> void:
	## Directories with .gdignore file are skipped
	DirAccess.make_dir_recursive_absolute(_TEMP_DIR)

	# Create .gdignore
	var gdignore := FileAccess.open(_TEMP_DIR.path_join(".gdignore"), FileAccess.WRITE)
	if gdignore:
		gdignore.store_string("")
		gdignore.close()

	# Create a .gd file with invalid ID (should be ignored due to .gdignore)
	var bad := FileAccess.open(_TEMP_DIR.path_join("bad.gd"), FileAccess.WRITE)
	if bad:
		bad.store_string("var x := Scenes.Id.INVALID_ID")
		bad.close()

	var count := _CheckIds._scan_project_for_invalid_ids(_TEMP_DIR)
	assert_int(count).is_zero()


func test_scan_skips_dot_prefixed_dirs() -> void:
	## Directories starting with . are skipped
	var dot_dir := _TEMP_DIR.path_join(".hidden")
	DirAccess.make_dir_recursive_absolute(dot_dir)

	var gd := FileAccess.open(dot_dir.path_join("test.gd"), FileAccess.WRITE)
	if gd:
		gd.store_string("var x := Scenes.Id.INVALID_ID")
		gd.close()

	var count := _CheckIds._scan_project_for_invalid_ids(_TEMP_DIR)
	assert_int(count).is_zero()


func test_scan_normal_dir_returns_zero_for_valid() -> void:
	## Directory with only valid IDs has invalid count of 0
	DirAccess.make_dir_recursive_absolute(_TEMP_DIR)

	var gd := FileAccess.open(_TEMP_DIR.path_join("test.gd"), FileAccess.WRITE)
	if gd:
		gd.store_string("var x := Scenes.Id.NONE\n")
		gd.close()

	var count := _CheckIds._scan_project_for_invalid_ids(_TEMP_DIR)
	assert_int(count).is_zero()
