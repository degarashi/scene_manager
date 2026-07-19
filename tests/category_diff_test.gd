extends GdUnitTestSuite

const SMgrDataScript = preload("res://addons/scene_manager/data_store/scene_data_structure.gd")


# ------------- [Tests] -------------

func test_both_empty() -> void:
	var diff := SMgrDataScript.CategoryDiff.new([], [])
	assert_array(diff.added).is_empty()
	assert_array(diff.removed).is_empty()
	assert_array(diff.unchanged).is_empty()


func test_current_empty_target_populated() -> void:
	var current: Array[int] = []
	var target: Array[int] = [100, 200]
	var diff := SMgrDataScript.CategoryDiff.new(current, target)
	assert_array(diff.added).has_size(2)
	assert_array(diff.removed).is_empty()
	assert_array(diff.unchanged).is_empty()


func test_current_populated_target_empty() -> void:
	var current: Array[int] = [100, 200]
	var target: Array[int] = []
	var diff := SMgrDataScript.CategoryDiff.new(current, target)
	assert_array(diff.added).is_empty()
	assert_array(diff.removed).has_size(2)
	assert_array(diff.unchanged).is_empty()


func test_partial_overlap() -> void:
	var current: Array[int] = [100, 200]
	var target: Array[int] = [200, 300]
	var diff := SMgrDataScript.CategoryDiff.new(current, target)
	assert_array(diff.added).has_size(1)
	assert_array(diff.removed).has_size(1)
	assert_array(diff.unchanged).has_size(1)
	assert_array(diff.unchanged).contains([200])


func test_identical() -> void:
	var cats: Array[int] = [100, 200]
	var diff := SMgrDataScript.CategoryDiff.new(cats, cats)
	assert_array(diff.added).is_empty()
	assert_array(diff.removed).is_empty()
	assert_array(diff.unchanged).has_size(2)


func test_to_string_format() -> void:
	var current: Array[int] = [100]
	var target: Array[int] = [200]
	var diff := SMgrDataScript.CategoryDiff.new(current, target)
	var result := diff._to_string()
	assert_str(result).contains("Added:")
	assert_str(result).contains("Removed:")
	assert_str(result).contains("Unchanged:")
