class_name SMgrInstance
extends Node
## Main SceneManager that handles adding and transitioning between scenes.

# ------------- [Signal] -------------
## Emitted when loading progress (0-100) changes.
signal load_percent_changed(value: int)
signal load_finished
signal load_failed

## Emitted when scene instantiation is completed.
signal scene_loaded(scene_id: Scenes.Id)
## Emitted when the entire transition (including visual effects) is finished.
signal scene_transition_completed(scene_id: Scenes.Id)
signal on_game_end

signal category_changed(diff: SMgrData.CategoryDiff)
## Emitted when a scene is reloaded
signal category_reapplied(tags: Array[Scenes.CategoryId])
## Emitted to notify added or current categories depending on the transition type.
signal category_tags_notified(tags: Array[Scenes.CategoryId])

## Defines how to handle cases where a SceneLayer name already exists.
enum DuplicateNameMode {
	REMOVE_OLD,  ## Remove the existing SceneLayer before adding the new one.
	WARN_AND_SKIP,  ## Print a warning and abort the addition.
	RENAME_NEW,  ## Append a numeric suffix to the new SceneLayer to avoid collision.
	APPEND,  ## Add the new scene to the existing SceneLayer.
}
# ------------- [Constants] -------------
const _C = preload("uid://c3vvdktou45u")
const _RING_BUFFER = preload("uid://b6phac21mxnxr")
const _RESOURCE_LOADER = preload("uid://dabq3s83q0iku")
const _SCENE_LAYER = preload("uid://do8sylacoy3u4")
const _AF = preload("uid://dlgh4u64a7qxk")

@export var _loading_node_name: String = "===Transition==="
@export var _initial_play_in_time = 1.0
@export var _actual_scene_container_path: NodePath = "/root"
@export var _wrap_initial_scene := true
@export var _transitioner_source: PackedScene = preload("uid://2iy8wfgenjka")
@export var _ebus: SMgrEbusRuntime


# ------------- [Defines] -------------
## Internal class to hold reservation info for asynchronous loading.
class _ReservedInfo:
	var scene_id: Scenes.Id = Scenes.Id.NONE
	var options: SceneLoadOptions
	var is_additive: bool = false
	var add_to_back: bool = false

	func clear() -> void:
		scene_id = Scenes.Id.NONE
		options = null
		is_additive = false
		add_to_back = false


## Class to aggregate and hold category information associated with a scene.
class SceneCategorySummary:
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


# ------------- [Private Variable] -------------
var _scene_db: SMgrData
## ID of the scene currently being loaded.
var _load_scene_id: Scenes.Id = Scenes.Id.NONE

## Reservation info for asynchronous loading.
var _reserved := _ReservedInfo.new()

## Scenes currently present (Key: Scene-Id, Value: SMgrSceneLayer).
var _current_scene_enum: Scenes.Id = Scenes.Id.NONE
var _trash_can: SMgrTrashCan
var _transition_player: ScreenTransitioner

@onready var _history_stack := _RING_BUFFER.new()

## ResourceLoaderMgr instance
@onready var _loader_mgr: _RESOURCE_LOADER


# ------------- [Callbacks] -------------
func _ready() -> void:
	_init_resourece_loader()
	_init_effector()
	_init_trash_node()

	var PS := preload("uid://dn6eh4s0h8jhi")
	# SMgrData is a Resource, so read it with the loader
	_scene_db = load(PS.scene_data_path)
	assert(_scene_db != null, "Scene Manager: Failed to load scene database resource.")

	_on_initial_setup.call_deferred()


# ------------- [Private Methods] -------------
## Returns an object containing the aggregated category info for a specified Scene ID.
func _get_category_summary(scene_id: Scenes.Id) -> SceneCategorySummary:
	var category_ids := _scene_db.get_category_ids_by_scene(scene_id)
	var category_data_list: Array[SMgrCategoryData] = []

	for c_id in category_ids:
		var data := _scene_db.get_category_from_id(c_id)
		if data:
			category_data_list.append(data)

	return SceneCategorySummary.new(category_data_list)


func _init_resourece_loader() -> void:
	_loader_mgr = _RESOURCE_LOADER.new()
	_loader_mgr.name = "ResourceLoader"
	_loader_mgr.progress_changed.connect(_on_loader_progress_changed)
	add_child(_loader_mgr)


func _init_effector() -> void:
	_transition_player = _transitioner_source.instantiate()
	add_child(_transition_player)


func _init_trash_node() -> void:
	_trash_can = SMgrTrashCan.new()
	add_child(_trash_can)


func _on_loader_progress_changed(_path: String, percent: int) -> void:
	# If the progress is for our currently loading scene, emit signal
	var loading_path := _scene_db.get_scene_path_from_enum(_load_scene_id)
	if _path == loading_path:
		load_percent_changed.emit(percent)


## Creates a SceneLayer and registers cleanup processing for self-destruction.
##
## The final node name is determined by the following priority:
## 1. override_name (if provided and not empty)
## 2. category.layer_name (if defined in the scene database)
## 3. node_name (the fallback name passed as an argument)
func _create_scene_layer(
	scene_id: Scenes.Id, node_name: String, override_name: String = ""
) -> SMgrSceneLayer:
	var summary := _get_category_summary(scene_id)

	# Determine final name based on the priority described above
	var final_name := override_name
	if final_name.is_empty():
		final_name = summary.layer_name if not summary.layer_name.is_empty() else node_name
	assert(not final_name.is_empty(), "Scene Manager: wrapper node name cannot be empty.")

	var layer: SMgrSceneLayer = _SCENE_LAYER.instantiate()
	layer.prepare(
		scene_id, final_name, summary.max_priority, summary.pauses_lower, summary.follow_viewport
	)
	layer.layer_disposed.connect(_on_layer_disposed)

	# Pause lower layers if necessary
	if summary.pauses_lower:
		_ebus.pause_threshold_changed.emit(summary.max_priority)
	if summary.always_process:
		layer.process_mode = Node.PROCESS_MODE_ALWAYS

	return layer


func _on_layer_disposed(_scene_id: Scenes.Id) -> void:
	var max_p := _C.MIN_LAYER_PRIORITY
	_ebus.process_scene_layer.emit(
		func(sc: SMgrSceneLayer) -> void:
			if sc.pause_lower:
				max_p = max(max_p, sc.l_priority)
	)

	if max_p != _C.MIN_LAYER_PRIORITY:
		_ebus.pause_threshold_changed.emit(max_p)
	else:
		# If no such scene exists, send a default value (or invalid value) to unpause all
		_ebus.pause_threshold_changed.emit(_C.DEFAULT_LAYER_PRIORITY - 1)


func _get_actual_scene_container() -> Node:
	var target_node := get_node_or_null(_actual_scene_container_path)
	if target_node:
		return target_node
	push_warning(
		"Scene Manager: _actual_scene_container_path is invalid. Falling back to root node."
	)
	return get_tree().root


func _on_initial_setup() -> void:
	if _wrap_initial_scene:
		var scene_node := get_tree().current_scene
		assert(scene_node != null, "Scene Manager: current_scene is null during initial setup.")

		# Find Scenes.Id enum by current scene's path
		var current_path := scene_node.scene_file_path
		_current_scene_enum = _scene_db.get_scene_enum_by_path(current_path)

		# Force using DEFAULT_TREE_NODE_NAME by passing it as override_name
		var layer := _create_scene_layer(_current_scene_enum, "", _C.DEFAULT_TREE_NODE_NAME)
		_get_actual_scene_container().add_child(layer)
		layer.add_node(scene_node)
		if _current_scene_enum == Scenes.Id.NONE:
			push_warning("Initial scene not found in DB (Scenes.Id.NONE).")

	# Initial fade-in effect
	_transition_player.set_clickable(false)
	await _transition_player.play_in(_initial_play_in_time)
	_transition_player.set_clickable(true)
	scene_transition_completed.emit(_current_scene_enum)


func _remove_node_safely(target_node: Node) -> void:
	assert(target_node != null, "Scene Manager: target_node to remove is null.")
	_trash_can.collect(target_node)


func _remove_name_node(sc: SMgrSceneLayer, p_name: String) -> void:
	if sc.name == p_name:
		_remove_node_safely(sc)


func _perform_scene_setup(scene: Scenes.Id, options: SceneLoadOptions) -> Node:
	var new_scene_node := _create_scene_instance_blocking(scene)
	if not new_scene_node:
		push_error("Scene Manager: Failed to instantiate scene: %s" % Scenes.Id.find_key(scene))
		return null

	# Create layer (node_name will be ignored if category has layer_name)
	var layer := _create_scene_layer(scene, options.node_name)
	layer.add_node(new_scene_node)

	options.call_pre_cb(layer, new_scene_node)
	_get_actual_scene_container().add_child(layer)

	scene_loaded.emit(scene)
	return new_scene_node


# ------------- [Public Methods] -------------
func get_history_list() -> Array[Scenes.Id]:
	return _history_stack.get_all_items()


func get_history_count() -> int:
	return _history_stack.size()


## Unloads a SceneLayer matching the specified node name.
func unload_scene_by_name(node_name: String) -> void:
	if node_name.is_empty():
		push_warning("Scene Manager: unload_scene_by_name called with empty name.")
		return

	# Leverages existing logic to safely move the node to the trash can
	_ebus.process_scene_layer.emit(_remove_name_node.bind(node_name))


## Discards the current main scene and switches to a new one. (Main Routine)
func switch_to_scene(
	scene_id: Scenes.Id, add_to_back: bool, options := SceneLoadOptions.new()
) -> Node:
	if scene_id == Scenes.Id.NONE:
		push_warning("Scene Manager: switch_to_scene called with NONE.")
		return null

	# Even if reloading the same scene, the instance is recreated.
	# We preserve the existing layer name and re-notify categories to maintain consistency.
	var is_reloading := scene_id == _current_scene_enum
	if is_reloading:
		var recv: Array[SMgrSceneLayer]
		_ebus.get_scene_by_id.emit(recv, scene_id)
		if not recv.is_empty():
			# Force the new instance to use the same node name as the current one.
			options.node_name = recv[0].name

	# --- Transition Start ---
	_transition_player.set_clickable(options.clickable)
	await _transition_player.play_out(options.play_out_time)

	# Remove existing layers before setting up the new scene
	_ebus.process_scene_layer.emit(_remove_node_safely)

	# Update history stack (only for new scene transitions)
	if not is_reloading and add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	# Instantiate and setup the scene (this internally emits 'scene_loaded')
	var new_scene_node := _perform_scene_setup(scene_id, options)
	if not new_scene_node:
		push_error(
			(
				"Scene Manager: Failed to instantiate switch_to_scene: %s"
				% Scenes.Id.find_key(scene_id)
			)
		)
		_transition_player.set_clickable(true)
		return null

	var category_diff := _scene_db.compare_scene_categories(_current_scene_enum, scene_id)
	_current_scene_enum = scene_id

	if is_reloading:
		var current_tags := _scene_db.get_category_ids_by_scene(scene_id)
		category_reapplied.emit(current_tags)
		category_tags_notified.emit(current_tags)
	else:
		category_changed.emit(category_diff)
		category_tags_notified.emit(category_diff.added)

	await _transition_player.play_in(options.play_in_time)
	_transition_player.set_clickable(true)
	scene_transition_completed.emit(scene_id)
	return new_scene_node


## Adds a scene while keeping the current scene. (Additive Routine)
func add_scene(
	scene_id: Scenes.Id,
	mode: DuplicateNameMode = DuplicateNameMode.WARN_AND_SKIP,
	options := SceneLoadOptions.new()
) -> Node:
	if scene_id == Scenes.Id.NONE:
		push_warning("Scene Manager: add_scene called with NONE.")
		return null

	var summary := _get_category_summary(scene_id)
	var target_name := (
		summary.layer_name if not summary.layer_name.is_empty() else options.node_name
	)

	var recv: Array[SMgrSceneLayer]
	_ebus.get_scene_by_name.emit(recv, target_name)

	if not recv.is_empty():
		match mode:
			DuplicateNameMode.REMOVE_OLD:
				unload_scene_by_name(target_name)

			DuplicateNameMode.WARN_AND_SKIP:
				push_warning(
					"Scene Manager: Scene with name '%s' is already loaded. Skipping." % target_name
				)
				return null

			DuplicateNameMode.RENAME_NEW:
				# Logic to find a unique name by appending a numeric suffix
				var suffix := 2
				var new_name := target_name + str(suffix)
				var check_recv: Array[SMgrSceneLayer]
				_ebus.get_scene_by_name.emit(check_recv, new_name)
				while not check_recv.is_empty():
					suffix += 1
					new_name = target_name + str(suffix)
					check_recv.clear()
					_ebus.get_scene_by_name.emit(check_recv, new_name)
				options.node_name = new_name

			DuplicateNameMode.APPEND:
				# Instead of creating a new layer, append the instance to the existing layer
				var target_layer := recv[0]
				var new_node := _create_scene_instance_blocking(scene_id)
				if new_node:
					target_layer.add_node(new_node)
					# Apply pre-callback to the existing layer and new node
					options.call_pre_cb(target_layer, new_node)
					# Manually emit since we bypass _perform_scene_setup
					scene_loaded.emit(scene_id)
				return new_node

	# For other modes (or if no duplicate was found), proceed with standard setup
	return _perform_scene_setup(scene_id, options)


func load_previous_scene(options := SceneLoadOptions.new()) -> bool:
	if _history_stack.size() == 0:
		push_warning("Scene Manager: Attempted to load previous scene, but history is empty.")
		return false

	back_to_previous_by_offset(1, options)
	return true


## Go back in history by the specified number (offset)
## from the current scene and transition to that scene.
func back_to_previous_by_offset(offset: int, options := SceneLoadOptions.new()) -> void:
	if offset <= 0:
		push_warning("Scene Manager: offset must be greater than 0.")
		return

	var target_scene := Scenes.Id.NONE
	for i in range(offset):
		var popped = _history_stack.pop()
		if popped != Scenes.Id.NONE:
			target_scene = popped
		else:
			break

	if target_scene == Scenes.Id.NONE:
		push_warning("Scene Manager: Failed to go back, history is empty or offset out of bounds.")
		return

	switch_to_scene(target_scene, false, options)


## Reloads the current scene.
## @return True if executed.
func reload_current_scene(options := SceneLoadOptions.new()) -> bool:
	# Use the same parent node the scene currently has to keep it consistent.
	if _current_scene_enum == Scenes.Id.NONE:
		push_warning("Attempted to reload current scene, but current scene is NONE.")
		return false

	# The reload logic is handled within switch_to_scene(), so simply calling it is sufficient.
	switch_to_scene(_current_scene_enum, false, options)
	return true


## Quits the game after a fade-out effect.
## @param fade_time Duration of the fade-out (seconds).
func exit_game(fade_time: float = 1.0) -> void:
	_transition_player.set_clickable(false)
	await _transition_player.play_out(fade_time)
	on_game_end.emit()
	get_tree().quit(0)


# ------------- [Async Loading] -------------
func start_async_load(scene: Scenes.Id, use_sub_threads: bool = true) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: start_async_load called with Scenes.Id.NONE.")
		return

	var path := _scene_db.get_scene_path_from_enum(scene)
	_load_scene_id = scene

	_loader_mgr.request(
		path,
		func(res: Resource):
			if res:
				load_finished.emit()
			else:
				load_failed.emit()
				push_error("Scene Manager: Async load failed for %s" % path),
		use_sub_threads
	)


func load_scene_with_transition(
	next_scene: Scenes.Id,
	transition_scene: Scenes.Id,
	add_to_back: bool = true,
	mode: DuplicateNameMode = DuplicateNameMode.WARN_AND_SKIP,
	opt_play_in := SceneLoadOptions.new(),
	opt_activate := opt_play_in
) -> void:
	assert(next_scene != Scenes.Id.NONE, "Scene Manager: next_scene cannot be NONE.")
	assert(transition_scene != Scenes.Id.NONE, "Scene Manager: transition_scene cannot be NONE.")

	_reserved.scene_id = next_scene
	_reserved.options = opt_activate.copy()
	_reserved.is_additive = false
	_reserved.add_to_back = add_to_back

	var trans_options := opt_play_in.copy()
	trans_options.node_name = _loading_node_name

	add_scene(transition_scene, mode, trans_options)


func instantiate_async_result() -> void:
	var path := _scene_db.get_scene_path_from_enum(_reserved.scene_id)
	if path == "" or _reserved.scene_id == Scenes.Id.NONE:
		push_warning("instantiate_async_result: No reserved scene to instantiate.")
		return

	# Add current scene to history before switching
	if _reserved.add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	# Load the resource (should be cached by the ResourceLoaderMgr)
	var res := load(path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = path

		# Create the layer with a temporary unique name.
		# This prevents name collisions with the current active scene
		# while this new layer sits hidden in the background.
		var layer := _create_scene_layer(
			_reserved.scene_id, "", _AF.to_tmp_name(_reserved.options.node_name)
		)

		# Keep the layer hidden until activate_prepared_scene() is called
		layer.visible = false
		layer.add_node(scene_node)

		_reserved.options.call_pre_cb(layer, scene_node)
		var target := _get_actual_scene_container()
		target.add_child(layer)


## Finalizes the transition by swapping the old scene with the pre-instantiated one.
## This is the final step of the 'load_scene_with_transition' flow.
func activate_prepared_scene() -> Node:
	if _reserved.scene_id == Scenes.Id.NONE:
		push_warning("activate_prepared_scene called but no scene is reserved.")
		return null

	var recv: Array[SMgrSceneLayer]
	_ebus.get_scene_by_id.emit(recv, _reserved.scene_id)
	assert(not recv.is_empty(), "Scene Manager: Reserved scene entry missing.")
	var layer := recv[0]

	_transition_player.set_clickable(_reserved.options.clickable)
	await _transition_player.play_out(_reserved.options.play_out_time)

	var diff := _scene_db.compare_scene_categories(_current_scene_enum, _reserved.scene_id)

	# Remove the transition/loading scene layer
	unload_scene_by_name(_loading_node_name)

	if not _reserved.is_additive:
		# Cleanup: Remove all layers except the new one and revert the temporary name
		_ebus.process_scene_layer.emit(
			func(sc: SMgrSceneLayer) -> void:
				if sc.scene_id != _reserved.scene_id:
					_remove_node_safely(sc)
		)

		# Now that the old scene is gone, revert the layer name to its intended original name
		layer.name = _AF.from_tmp_name(layer.name)
		layer.visible = true
		_current_scene_enum = _reserved.scene_id

	category_changed.emit(diff)
	category_tags_notified.emit(diff.added)
	scene_loaded.emit(_current_scene_enum)

	# Show the new scene
	await _transition_player.play_in(_reserved.options.play_in_time)

	_reserved.clear()
	_transition_player.set_clickable(true)
	scene_transition_completed.emit(_current_scene_enum)

	return layer.get_child(0)


# ------------- [Utils] -------------
func _get_scene_blocking(scene: Scenes.Id) -> PackedScene:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: _get_scene_blocking called with Scenes.Id.NONE.")
		return null
	return load(_scene_db.get_scene_path_from_enum(scene))


func _create_scene_instance_blocking(scene: Scenes.Id) -> Node:
	var pack := _get_scene_blocking(scene)
	return pack.instantiate() if pack else null


## Returns the currently reserved scene Enum.
## @return Reserved scene Enum.
func get_reserved_scene() -> Scenes.Id:
	return _reserved.scene_id


## Returns the reserved load options for the reserved scene.
func get_reserved_load_option() -> SceneLoadOptions:
	return _reserved.options


func get_scene_data() -> SMgrData:
	return _scene_db
