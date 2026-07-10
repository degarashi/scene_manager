extends GdUnitTestSuite

const CategoryDataScript = preload("res://addons/scene_manager/data_store/category_data.gd")
const SummaryScript = preload("res://addons/scene_manager/resource/scene_category_summary.gd")


# ------------- [Tests] -------------

func test_empty_categories_defaults() -> void:
	var summary: SMgrSceneCategorySummary = SummaryScript.new([])
	assert_int(summary.max_priority).is_equal(SMgrConstants.DEFAULT_LAYER_PRIORITY)
	assert_bool(summary.pauses_lower).is_false()
	assert_bool(summary.always_process).is_false()
	assert_bool(summary.follow_viewport).is_false()
	assert_str(summary.layer_name).is_equal("")


func test_single_category_priority() -> void:
	var cat: SMgrCategoryData = _make_category()
	cat.layer_priority = 5
	var summary: SMgrSceneCategorySummary = SummaryScript.new([cat])
	assert_int(summary.max_priority).is_equal(5)


func test_multiple_categories_max_priority() -> void:
	var cat_low: SMgrCategoryData = _make_category()
	cat_low.layer_priority = 2
	var cat_high: SMgrCategoryData = _make_category()
	cat_high.layer_priority = 10
	var cat_mid: SMgrCategoryData = _make_category()
	cat_mid.layer_priority = 7
	var summary: SMgrSceneCategorySummary = SummaryScript.new([
		cat_low, cat_high, cat_mid,
	])
	assert_int(summary.max_priority).is_equal(10)


func test_pauses_lower_true() -> void:
	var cat_off: SMgrCategoryData = _make_category()
	var cat_on: SMgrCategoryData = _make_category()
	cat_on.pauses_lower_priority_layers = true
	var summary: SMgrSceneCategorySummary = SummaryScript.new([cat_off, cat_on])
	assert_bool(summary.pauses_lower).is_true()


func test_always_process_true() -> void:
	var cat_off: SMgrCategoryData = _make_category()
	var cat_on: SMgrCategoryData = _make_category()
	cat_on.always_process = true
	var summary: SMgrSceneCategorySummary = SummaryScript.new([cat_off, cat_on])
	assert_bool(summary.always_process).is_true()


func test_follow_viewport_true() -> void:
	var cat_off: SMgrCategoryData = _make_category()
	var cat_on: SMgrCategoryData = _make_category()
	cat_on.follow_viewport = true
	var summary: SMgrSceneCategorySummary = SummaryScript.new([cat_off, cat_on])
	assert_bool(summary.follow_viewport).is_true()


func test_layer_name_selection() -> void:
	var cat_empty: SMgrCategoryData = _make_category()
	cat_empty.layer_name = ""
	var cat_named: SMgrCategoryData = _make_category()
	cat_named.layer_name = "HUD"
	var cat_later: SMgrCategoryData = _make_category()
	cat_later.layer_name = "Menu"
	var summary: SMgrSceneCategorySummary = SummaryScript.new([
		cat_empty, cat_named, cat_later,
	])
	assert_str(summary.layer_name).is_equal("HUD")


func test_layer_name_empty_when_all_empty() -> void:
	var cat1: SMgrCategoryData = _make_category()
	cat1.layer_name = ""
	var cat2: SMgrCategoryData = _make_category()
	cat2.layer_name = ""
	var summary: SMgrSceneCategorySummary = SummaryScript.new([cat1, cat2])
	assert_str(summary.layer_name).is_equal("")


# ------------- [Helpers] -------------

func _make_category() -> SMgrCategoryData:
	return CategoryDataScript.new("")
