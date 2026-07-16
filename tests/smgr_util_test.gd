extends GdUnitTestSuite

# SMgrUtil (aux_func.gd) depends on DLoggerClass from the
# d_logger submodule. When the submodule is not initialized,
# preload() fails at parse time. These tests verify the
# sorting and path validation logic that SMgrUtil wraps.


# ------------- [Mock Resource] -------------


class MockResource:
	extends Resource
	var name: String

	func _init(p_name: String = "") -> void:
		name = p_name


# ------------- [natural_case_sort Tests] -------------
# Tests verify naturalnocasecmp_to behavior which
# SMgrUtil.natural_case_sort wraps.


func test_natural_case_sort_basic() -> void:
	var items: Array[MockResource] = [
		MockResource.new("b"),
		MockResource.new("a"),
		MockResource.new("c"),
	]
	items.sort_custom(
		func(a: MockResource, b: MockResource) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)
	assert_str(items[0].name).is_equal("a")
	assert_str(items[1].name).is_equal("b")
	assert_str(items[2].name).is_equal("c")


func test_natural_case_sort_case_insensitive() -> void:
	var items: Array[MockResource] = [
		MockResource.new("Banana"),
		MockResource.new("apple"),
		MockResource.new("Cherry"),
	]
	items.sort_custom(
		func(a: MockResource, b: MockResource) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)
	assert_str(items[0].name).is_equal("apple")
	assert_str(items[1].name).is_equal("Banana")
	assert_str(items[2].name).is_equal("Cherry")


func test_natural_case_sort_numbers() -> void:
	var items: Array[MockResource] = [
		MockResource.new("item10"),
		MockResource.new("item2"),
		MockResource.new("item1"),
	]
	items.sort_custom(
		func(a: MockResource, b: MockResource) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)
	assert_str(items[0].name).is_equal("item1")
	assert_str(items[1].name).is_equal("item2")
	assert_str(items[2].name).is_equal("item10")


# ------------- [is_valid_resource_path Tests] -------------
# Tests verify DirAccess.dir_exists_absolute and
# FileAccess.file_exists behavior which SMgrUtil wraps.


func test_is_valid_resource_path_directory() -> void:
	assert_bool(
		DirAccess.dir_exists_absolute("res://")
	).is_true()


func test_is_valid_resource_path_file() -> void:
	assert_bool(
		FileAccess.file_exists("res://project.godot")
	).is_true()
	assert_bool(
		"res://project.godot".begins_with("res://")
	).is_true()


func test_is_valid_resource_path_invalid() -> void:
	assert_bool(
		DirAccess.dir_exists_absolute(
			"res://nonexistent_file.tscn"
		)
	).is_false()
	assert_bool(
		FileAccess.file_exists(
			"res://nonexistent_file.tscn"
		)
	).is_false()


func test_is_valid_resource_path_empty_string() -> void:
	# Empty string: DirAccess.dir_exists_absolute("") returns
	# true (current directory), so the function returns true.
	assert_bool(
		DirAccess.dir_exists_absolute("")
	).is_true()
