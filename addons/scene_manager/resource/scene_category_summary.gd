class_name SMgrSceneCategorySummary
extends RefCounted
## Class to aggregate and hold category information associated with a scene.

const _C := preload("uid://c3vvdktou45u")

var categories: Array[SMgrCategoryData] = []
var max_priority: int = _C.DEFAULT_LAYER_PRIORITY
var pauses_lower: bool = false
var always_process: bool = false
var follow_viewport: bool = false
var layer_name: String = ""


func _init(p_categories: Array[SMgrCategoryData]) -> void:
	categories = p_categories
	if categories.is_empty():
		return

	# Set initial value to a very low number
	max_priority = _C.MIN_LAYER_PRIORITY
	for category in categories:
		# Calculate maximum priority
		if category.layer_priority > max_priority:
			max_priority = category.layer_priority

		# Determine whether to pause lower priority layers
		if category.pauses_lower_priority_layers:
			pauses_lower = true

		if category.always_process:
			always_process = true

		if category.follow_viewport:
			follow_viewport = true

		# Pick the first non-empty layer name found in categories
		if layer_name.is_empty() and not category.layer_name.is_empty():
			layer_name = category.layer_name

	# Fallback if no categories were found (safety measure)
	if max_priority == _C.MIN_LAYER_PRIORITY:
		max_priority = 1
