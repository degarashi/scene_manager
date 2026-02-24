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

# ------------- [Constants] -------------
const _C = preload("uid://c3vvdktou45u")
const _RING_BUFFER = preload("uid://b6phac21mxnxr")
const _RESOURCE_LOADER = preload("uid://dabq3s83q0iku")
const DEFAULT_LAYER_PRIORITY = 1

@export var _loading_node_name: String = "===Transition==="
@export var _initial_play_in_time = 1.0
@export var _actual_scene_container_path: NodePath = "/root"
@export var _wrap_initial_scene := true
@export var _transitioner_source: PackedScene = preload("uid://2iy8wfgenjka")


# ------------- [Defines] -------------
## Internal class to hold entries of loaded scenes.
class _SceneEntry:
	var container_node: CanvasLayer
	var scene_node: Node

	## Initialize the instance.
	## @param p_container The parent wrapper node.
	## @param p_scene The main scene node.
	func _init(p_container: CanvasLayer, p_scene: Node) -> void:
		assert(p_container != null, "SceneEntry: container_node cannot be null.")
		assert(p_scene != null, "SceneEntry: scene_node cannot be null.")
		container_node = p_container
		scene_node = p_scene


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
	var max_priority: int = DEFAULT_LAYER_PRIORITY
	var pauses_lower: bool = false

	func _init(p_categories: Array[SMgrCategoryData]) -> void:
		categories = p_categories
		if categories.is_empty():
			return

		# Set initial value to a very low number
		max_priority = -10000
		for category in categories:
			# Calculate maximum priority
			if category.layer_priority > max_priority:
				max_priority = category.layer_priority

			# Determine whether to pause lower priority layers
			if category.pauses_lower_priority_layers:
				pauses_lower = true

		# Fallback if no categories were found (safety measure)
		if max_priority == -10000:
			max_priority = 1


# ------------- [Private Variable] -------------
var _scene_db: SMgrData
## ID of the scene currently being loaded.
var _load_scene_id: Scenes.Id = Scenes.Id.NONE

## Reservation info for asynchronous loading.
var _reserved := _ReservedInfo.new()

## Scenes currently present in the field (Key: Scene-Id, Value: _SceneEntry).
var _loaded_scene_map: Dictionary[Scenes.Id, _SceneEntry] = {}
var _current_scene_enum: Scenes.Id = Scenes.Id.NONE
var _trash_node: Control
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
	_trash_node = Control.new()
	_trash_node.name = "trash_node"
	_trash_node.process_mode = Node.PROCESS_MODE_DISABLED
	_trash_node.visible = false
	add_child(_trash_node)


func _on_loader_progress_changed(_path: String, percent: int) -> void:
	# If the progress is for our currently loading scene, emit signal
	var loading_path := _scene_db.get_scene_path_from_enum(_load_scene_id)
	if _path == loading_path:
		load_percent_changed.emit(percent)


func _create_ui_wrapper(node_name: String) -> CanvasLayer:
	assert(not node_name.is_empty(), "Scene Manager: wrapper node name cannot be empty.")
	var wrapper := CanvasLayer.new()
	wrapper.name = node_name
	return wrapper


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
		## Wrap current_scene and place it under management
		var default_wrapper := _create_ui_wrapper(_C.DEFAULT_TREE_NODE_NAME)
		_get_actual_scene_container().add_child(default_wrapper)

		var scene_node := get_tree().current_scene
		assert(scene_node != null, "Scene Manager: current_scene is null during initial setup.")
		scene_node.reparent(default_wrapper)

		# Find Scenes.Id enum by current scene's path
		var current_path := scene_node.scene_file_path
		_current_scene_enum = _scene_db.get_scene_enum_by_path(current_path)
		if _current_scene_enum != Scenes.Id.NONE:
			_loaded_scene_map[_current_scene_enum] = _SceneEntry.new(default_wrapper, scene_node)
			# Apply priority for initial scene
			default_wrapper.layer = _get_max_priority_for_scene(_current_scene_enum)
		else:
			push_warning("Initial scene not found in DB (Scenes.Id.NONE).")

	# Initial fade-in effect
	_transition_player.set_clickable(false)
	await _transition_player.play_in(_initial_play_in_time)
	_transition_player.set_clickable(true)
	scene_transition_completed.emit(_current_scene_enum)


## Frees all scenes under a specified parent node and removes them from the map.
## @param node_name Name of the parent node to release.
func _unload_scene(node_name: String, should_found: bool = true) -> void:
	# If a node with the specified name exists directly under scene container node, remove it.
	var target_node := _get_actual_scene_container().get_node_or_null(node_name)
	if not target_node:
		if should_found:
			push_warning(
				"Scene Manager: Attempted to unload node '%s', but it was not found." % node_name
			)
		return

	# Remove from the loaded scenes map
	var ids_to_remove: Array[Scenes.Id] = []
	for id in _loaded_scene_map:
		if _loaded_scene_map[id].container_node.name == node_name:
			ids_to_remove.append(id)

	for id in ids_to_remove:
		_loaded_scene_map.erase(id)

	# Delete the node itself
	_remove_node_safely(target_node)


func _remove_node_safely(target_node: Node) -> void:
	assert(target_node != null, "Scene Manager: target_node to remove is null.")
	assert(_trash_node != null, "Scene Manager: trash_node is not initialized.")

	# Move to trash and then remove
	# (This will immediately release the name directly under scene container node)
	target_node.reparent(_trash_node)
	# Change the name just in case
	target_node.name = "dying_" + str(target_node.get_instance_id())
	target_node.queue_free()


## Frees all nodes related to the loaded scene map.
func _unload_all_nodes() -> void:
	var unique_names: Array[String] = []
	for entry: _SceneEntry in _loaded_scene_map.values():
		var n_name := entry.container_node.name
		if n_name not in unique_names:
			unique_names.append(n_name)

	for n_name in unique_names:
		_unload_scene(n_name)


## Returns a list of category data assigned to the scene.
func _get_categories_for_scene(scene_id: Scenes.Id) -> Array[SMgrCategoryData]:
	var category_ids := _scene_db.get_category_ids_by_scene(scene_id)
	var categories: Array[SMgrCategoryData] = []
	for c_id in category_ids:
		var category_data := _scene_db.get_category_from_id(c_id)
		categories.append(category_data)
	return categories


## Returns the maximum layer priority from all categories assigned to the scene.
func _get_max_priority_for_scene(scene_id: Scenes.Id) -> int:
	var categories := _get_categories_for_scene(scene_id)
	if categories.is_empty():
		return DEFAULT_LAYER_PRIORITY

	var max_priority := -10000
	for category in categories:
		max_priority = max(max_priority, category.layer_priority)

	return max_priority


func _get_pause_for_scene(scene_id: Scenes.Id) -> bool:
	var categories := _get_categories_for_scene(scene_id)
	for category in categories:
		if category.pauses_lower_priority_layers:
			return true
	return false


func _pause_lower_priority_layers(scene_id: Scenes.Id, cur_priority: int) -> void:
	if _get_pause_for_scene(scene_id):
		# Pause nodes on layers with lower priority
		for entry: _SceneEntry in _loaded_scene_map.values():
			if entry.container_node.layer < cur_priority:
				entry.container_node.process_mode = Node.PROCESS_MODE_DISABLED


func _perform_scene_setup(scene: Scenes.Id, options: SceneLoadOptions) -> Node:
	var new_scene_node := _create_scene_instance_blocking(scene)
	if not new_scene_node:
		push_error("Scene Manager: Failed to instantiate scene: %s" % Scenes.Id.find_key(scene))
		return null

	# --- Aggregate category information at once ---
	var summary := _get_category_summary(scene)
	var parent_node := _create_ui_wrapper(options.node_name)
	parent_node.layer = summary.max_priority

	# Pause lower layers if necessary
	if summary.pauses_lower:
		_pause_lower_priority_layers_by_value(summary.max_priority)

	parent_node.add_child(new_scene_node)

	# Execute user-defined callback before adding to tree
	options.call_pre_cb(parent_node, new_scene_node)

	_get_actual_scene_container().add_child(parent_node)
	_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)

	scene_loaded.emit(scene)
	return new_scene_node


func _pause_lower_priority_layers_by_value(cur_priority: int) -> void:
	for entry: _SceneEntry in _loaded_scene_map.values():
		if entry.container_node.layer < cur_priority:
			entry.container_node.process_mode = Node.PROCESS_MODE_DISABLED


# ------------- [Public Methods] -------------
func get_history_list() -> Array[Scenes.Id]:
	return _history_stack.get_all_items()


func get_history_count() -> int:
	return _history_stack.size()


## Discards the current main scene and switches to a new one. (Main Routine)
func switch_to_scene(
	scene: Scenes.Id, add_to_back: bool, options := SceneLoadOptions.new()
) -> Node:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: switch_to_scene called with NONE.")
		return null

	# --- Transition Start ---
	_transition_player.set_clickable(options.clickable)
	await _transition_player.play_out(options.play_out_time)

	# --- Category Comparison ---
	var category_diff: SMgrData.CategoryDiff = _scene_db.compare_scene_categories(
		_current_scene_enum, scene
	)

	# --- Scene Replacement ---
	# Unload everything for a clean switch
	_unload_all_nodes()

	# Add to history
	if add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	var new_scene_node := _perform_scene_setup(scene, options)
	if not new_scene_node:
		push_error(
			"Scene Manager: Failed to instantiate switch_to_scene: %s" % Scenes.Id.find_key(scene)
		)
		_transition_player.set_clickable(true)
		return null

	_current_scene_enum = scene

	# Emit category change signal along with scene_loaded
	category_changed.emit(category_diff)

	await _transition_player.play_in(options.play_in_time)
	_transition_player.set_clickable(true)
	scene_transition_completed.emit(scene)
	return new_scene_node


## Adds a scene while keeping the current scene. (Additive Routine)
func add_scene(
	scene: Scenes.Id, remove_old: bool = false, options := SceneLoadOptions.new()
) -> Node:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: add_scene called with NONE.")
		return null

	# Handle existing instances of the same ID
	if _loaded_scene_map.has(scene):
		if not remove_old:
			push_warning(
				"Scene Manager: Scene %s is already loaded (additive)." % Scenes.Id.find_key(scene)
			)
			return null
		_unload_scene(_loaded_scene_map[scene].container_node.name)

	# Resolve name conflicts for the wrapper node
	_unload_scene(options.node_name, false)

	return _perform_scene_setup(scene, options)


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

	var opt := options.copy()
	opt.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
	switch_to_scene(_current_scene_enum, false, opt)
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
	remove_old: bool = false,
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

	add_scene(transition_scene, remove_old, trans_options)


func instantiate_async_result() -> void:
	var path := _scene_db.get_scene_path_from_enum(_reserved.scene_id)
	if path == "" or _reserved.scene_id == Scenes.Id.NONE:
		push_warning("instantiate_async_result: No reserved scene to instantiate.")
		return

	# Add current scene to history before switching
	if _reserved.add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	# Load directly (it should be cached in ResourceLoader by ResourceLoaderMgr)
	var res := load(path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = path
		# Temporary additive attachment
		var tmp_name := _to_tmp_name(_reserved.options.node_name)
		var parent_node := _create_ui_wrapper(tmp_name)
		# Apply layer priority even during async prep
		parent_node.layer = _get_max_priority_for_scene(_reserved.scene_id)
		_pause_lower_priority_layers(_reserved.scene_id, parent_node.layer)
		parent_node.add_child(scene_node)

		_reserved.options.call_pre_cb(parent_node, scene_node)

		var target_node := _get_actual_scene_container()
		target_node.add_child(parent_node)

		# Place it right behind the loading screen (which is at the top).
		target_node.move_child(parent_node, target_node.get_child_count() - 2)

		_loaded_scene_map[_reserved.scene_id] = _SceneEntry.new(parent_node, scene_node)
	else:
		push_error("Scene Manager: Failed to get threaded load result for %s" % path)


static func _to_tmp_name(node_name: String) -> String:
	return node_name + "_" + str(ResourceUID.create_id())


static func _from_tmp_name(tmp_name: String) -> String:
	var parts := tmp_name.split("_")
	if parts.size() > 1:
		parts.remove_at(parts.size() - 1)
		return "_".join(parts)
	return tmp_name


## When you added the loaded scene to the scene tree by `instantiate_async_result`
## function, you call this function after you are sure that the added scene to scene tree
## is completely ready and functional to change the active scene.[br]
## This is used in the `load_scene_with_transition` flow and uses the reserved information for
## switching scenes.
func activate_prepared_scene() -> Node:
	if _reserved.scene_id == Scenes.Id.NONE:
		push_warning("activate_prepared_scene called but no scene is reserved.")
		return null
	assert(
		_loaded_scene_map.has(_reserved.scene_id), "Scene Manager: Reserved scene entry missing."
	)

	_transition_player.set_clickable(_reserved.options.clickable)
	await _transition_player.play_out(_reserved.options.play_out_time)

	# --- Category Comparison ---
	# Calculate category differences before updating _current_scene_enum
	var category_diff := _scene_db.compare_scene_categories(_current_scene_enum, _reserved.scene_id)

	# Remove the loading screen
	_unload_scene(_loading_node_name)

	if not _reserved.is_additive:
		# Remove everything except _reserved scene
		var target_names: Array[String] = []
		for id in _loaded_scene_map:
			if id == _reserved.scene_id:
				continue
			target_names.append(_loaded_scene_map[id].container_node.name)

		for t_name in target_names:
			_unload_scene(t_name)

		# Revert the temporary name back to the original name to avoid conflicts
		var cont := _loaded_scene_map[_reserved.scene_id].container_node
		cont.name = _from_tmp_name(cont.name)

		# Priority is already set in instantiate_async_result
		_current_scene_enum = _reserved.scene_id

	# Emit category change signal along with scene_loaded (for consistency with switch_to_scene)
	category_changed.emit(category_diff)
	scene_loaded.emit(_current_scene_enum)

	await _transition_player.play_in(_reserved.options.play_in_time)

	var ret := _loaded_scene_map[_reserved.scene_id].scene_node
	# Reset the reserved scene information now that the scene has fully loaded.
	_reserved.clear()

	_transition_player.set_clickable(true)
	scene_transition_completed.emit(_current_scene_enum)
	return ret


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
