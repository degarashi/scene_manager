class_name SMgrLayerManager
extends RefCounted
## Helper class to manage SceneLayers, their priorities, and naming.

const _C := preload("uid://c3vvdktou45u")  # scene_manager_constants.gd
const _SCENE_LAYER := preload("uid://do8sylacoy3u4")  # scene_layer.tscn

var _scene_db: SMgrData
var _ebus: SMgrEbusRuntime
var _log: DLoggerClass


func _init(p_scene_db: SMgrData, p_ebus: SMgrEbusRuntime, p_log: DLoggerClass) -> void:
	_scene_db = p_scene_db
	_ebus = p_ebus
	_log = p_log


## Returns an object containing the aggregated category info for a specified Scene ID.
func get_category_summary(scene_id: Scenes.Id) -> SMgrSceneCategorySummary:
	var category_ids := _scene_db.get_category_ids_by_scene(scene_id)
	var category_data_list: Array[SMgrCategoryData] = []

	for c_id in category_ids:
		var data := _scene_db.get_category_from_id(c_id)
		if data:
			category_data_list.append(data)

	return SMgrSceneCategorySummary.new(category_data_list)


## Creates a SceneLayer and registers cleanup processing for self-destruction.
##
## The final node name is determined by the following priority:
## > override_name (if provided and not empty)
## > category.layer_name (if defined in the scene database)
## > node_name (the fallback name passed as an argument)
func create_scene_layer(
	scene_id: Scenes.Id, node_name: String, override_name: String = ""
) -> SMgrSceneLayer:
	var summary := get_category_summary(scene_id)

	# Determine final name based on the priority described above
	var final_name := override_name
	if final_name.is_empty():
		final_name = summary.layer_name if not summary.layer_name.is_empty() else node_name
	assert(not final_name.is_empty(), "Scene Manager: wrapper node name cannot be empty.")

	var layer: SMgrSceneLayer = _SCENE_LAYER.instantiate()
	layer.prepare(
		scene_id, final_name, summary.max_priority, summary.pauses_lower, summary.follow_viewport
	)
	layer.layer_disposed.connect(on_layer_disposed)

	# Update process mode of all layers (including the new one)
	recalculate_pause_threshold()

	if summary.always_process:
		layer.process_mode = Node.PROCESS_MODE_ALWAYS

	return layer


func on_layer_disposed(_scene_id: Scenes.Id) -> void:
	recalculate_pause_threshold()


func recalculate_pause_threshold() -> void:
	var max_p_wrap := [_C.MIN_LAYER_PRIORITY]
	_ebus.process_scene_layer.emit(
		func(sc: SMgrSceneLayer) -> void:
			if is_instance_valid(sc) and sc.pause_lower:
				max_p_wrap[0] = max(max_p_wrap[0], sc.l_priority)
	)

	var max_p: int = max_p_wrap[0]
	if max_p != _C.MIN_LAYER_PRIORITY:
		_ebus.pause_threshold_changed.emit(max_p)
	else:
		# If no such scene exists, send a default value (or invalid value) to unpause all
		_ebus.pause_threshold_changed.emit(_C.DEFAULT_LAYER_PRIORITY - 1)


func get_unique_layer_name(base_name: String) -> String:
	# Collect all existing layer names in one pass for O(1) lookups
	var existing_names: Dictionary[String, bool] = {}
	_ebus.process_scene_layer.emit(
		func(sc: SMgrSceneLayer) -> void:
			if is_instance_valid(sc):
				existing_names[sc.name] = true
	)

	# Find a unique name by incrementing suffix
	var suffix := 2
	var new_name := base_name + str(suffix)
	while existing_names.has(new_name):
		suffix += 1
		new_name = base_name + str(suffix)
	return new_name
