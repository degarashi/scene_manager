extends Node
## Main SceneManager that handles adding and transitioning between scenes.

# ------------- [Signal] -------------
## Emitted when loading progress (0-100) changes.
signal load_percent_changed(value: int)
signal load_finished
signal load_failed

## Emitted when scene instantiation is completed.
signal scene_loaded

# ------------- [Constants] -------------
const _C = preload("uid://c3vvdktou45u")
const _RING_BUFFER = preload("uid://t3tlcswbndjo")
const _INITIAL_FADE_IN_TIME = 1.0
const _LOADING_NODE_NAME: String = "===Transition==="
const _EFFECTOR_SCENE = preload("uid://2iy8wfgenjka")


# ------------- [Defines] -------------
## Internal class to hold entries of loaded scenes.
class _SceneEntry:
	var container_node: Control
	var scene_node: Node

	## Initialize the instance.
	## @param p_container The parent wrapper node.
	## @param p_scene The main scene node.
	func _init(p_container: Control, p_scene: Node) -> void:
		assert(p_container != null, "SceneEntry: container_node cannot be null.")
		assert(p_scene != null, "SceneEntry: scene_node cannot be null.")
		container_node = p_container
		scene_node = p_scene


# ------------- [Private Variable] -------------
static var _ps := preload("uid://dn6eh4s0h8jhi")

var _scene_db: SMgrData
var _load_scene_path: String = ""
## ID of the scene currently being loaded.
var _load_scene_id: Scenes.Id = Scenes.Id.NONE
## Array for holding raw loading progress data.
var _load_progress: Array = []

# Reservation info for asynchronous loading
var _reserved_scene_id: Scenes.Id = Scenes.Id.NONE
## Load options for the reserved scene.
var _reserved_options: SceneLoadOptions
var _is_reserved_as_additive: bool = false

## Scenes currently present in the field (Key: Scene-Id, Value: _SceneEntry).
var _loaded_scene_map: Dictionary[Scenes.Id, _SceneEntry] = {}
var _current_scene_enum: Scenes.Id = Scenes.Id.NONE
var _is_transitioning: bool = false
var _trash_node: Control
var _effector: Node = null

@onready var _history_stack := _RING_BUFFER.new()


func _set_transitioning(clickable: bool) -> void:
	assert(not _is_transitioning)
	_is_transitioning = true
	_effector.set_clickable(clickable)


func _end_transitioning() -> void:
	assert(_is_transitioning)
	_is_transitioning = false
	_effector.set_clickable(true)


# ------------- [Callbacks] -------------
func _ready() -> void:
	_init_trash_node()
	_init_effector()
	_enable_process(false)

	# SMgrData is a Resource, so read it with the loader
	_scene_db = load(_ps.scene_data_path)
	assert(_scene_db != null, "Scene Manager: Failed to load scene database resource.")

	var current_path := get_tree().current_scene.scene_file_path
	_current_scene_enum = _scene_db.get_scene_enum_by_path(current_path)

	_on_initial_setup.call_deferred()


func _process(_delta: float) -> void:
	_check_loading_progress()


# ------------- [Private Methods] -------------
func _init_effector() -> void:
	_effector = _EFFECTOR_SCENE.instantiate()
	_effector.name = "SceneEffector"
	add_child(_effector)


func _init_trash_node() -> void:
	_trash_node = Control.new()
	_trash_node.name = "trash_node"
	_trash_node.process_mode = Node.PROCESS_MODE_DISABLED
	_trash_node.visible = false
	add_child(_trash_node)


func _enable_process(enable: bool) -> void:
	set_process(enable)
	if enable:
		assert(
			not _load_scene_path.is_empty(),
			"Scene Manager: _enable_process(true) called but _load_scene_path is empty."
		)


## Checks progress during asynchronous scene loading and emits signals.
func _check_loading_progress() -> void:
	assert(
		not _load_scene_path.is_empty(),
		"Scene Manager: _check_loading_progress called but _load_scene_path is empty."
	)
	var prev_percent := int(_load_progress[0] * 100) if not _load_progress.is_empty() else 0
	var status := ResourceLoader.load_threaded_get_status(_load_scene_path, _load_progress)
	var next_percent := int(_load_progress[0] * 100)

	if prev_percent != next_percent:
		load_percent_changed.emit(next_percent)

	var on_fail := func(reason: String) -> void:
		_enable_process(false)
		push_error("Scene Manager: Loading failed for: %s (%s)" % [_load_scene_path, reason])
		load_failed.emit()

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_enable_process(false)
		_load_progress.clear()
		load_finished.emit()
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		on_fail.call("Generic error")
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		on_fail.call("Invalid resource")
	else:
		assert(status == ResourceLoader.THREAD_LOAD_IN_PROGRESS)


func _create_ui_wrapper(node_name: String) -> Control:
	assert(not node_name.is_empty(), "Scene Manager: wrapper node name cannot be empty.")
	var wrapper := Control.new()
	wrapper.name = node_name

	# Set to expand across the whole screen (Full Rect).
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The wrapper itself should not block mouse events.
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return wrapper


## Initial setup: moves the current scene to the manager's control.
func _on_initial_setup() -> void:
	var scene_node := get_tree().current_scene
	assert(scene_node != null, "Scene Manager: current_scene is null during initial setup.")

	var root := get_tree().root
	var default_wrapper := _create_ui_wrapper(_C.DEFAULT_TREE_NODE_NAME)

	root.add_child(default_wrapper)
	scene_node.reparent(default_wrapper)

	# Don't map a NONE scene as that shouldn't be here. It's possible to reach here
	# if the loaded scene wasn't part of the enums and loaded some other way.
	if _current_scene_enum != Scenes.Id.NONE:
		_loaded_scene_map[_current_scene_enum] = _SceneEntry.new(default_wrapper, scene_node)
	else:
		push_warning("Initial scene not found in DB (Scenes.Id.NONE).")

	await _effector.fade_in(_INITIAL_FADE_IN_TIME)


## Attaches a specified node to the scene tree and unloads existing nodes if necessary.
func _attach_scene_to_tree(
	node: Node, is_additive: bool, node_name: String, add_to_back: bool
) -> Control:
	assert(node != null, "Scene Manager: Node to attach cannot be null.")

	if not is_additive:
		_unload_all_nodes()
		if add_to_back and _current_scene_enum != Scenes.Id.NONE:
			_history_stack.push(_current_scene_enum)
	else:
		# Additive mode: only remove if there is a name conflict
		_unload_scene(node_name, false)

	# At this point, the node with node_name has been removed from root (moved to trash).
	# This ensures the newly created wrapper will have the exact name specified.
	var parent_node := _create_ui_wrapper(node_name)
	get_tree().root.add_child(parent_node)

	parent_node.add_child(node)

	return parent_node


## Frees all scenes under a specified parent node and removes them from the map.
## @param node_name Name of the parent node to release.
func _unload_scene(node_name: String, should_found: bool = true) -> void:
	# If a node with the specified name exists directly under root, remove it.
	var root := get_tree().root
	var target_node := root.get_node_or_null(node_name)
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
	# (This will immediately release the name directly under root)
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


# Internal common transition logic (blocking)
func _perform_transition_blocking(
	scene: Scenes.Id, is_additive: bool, add_to_back: bool, options: SceneLoadOptions
) -> void:
	assert(scene != Scenes.Id.NONE, "Scene Manager: Cannot transition to Scenes.Id.NONE.")

	_set_transitioning(options.clickable)
	await _effector.fade_out(options.fade_out_time)

	var new_scene_node := create_scene_instance_blocking(scene)
	if not new_scene_node:
		push_error("Scene Manager: Failed to instantiate scene with ID %d" % scene)
		_end_transitioning()
		return

	var parent_node := _attach_scene_to_tree(
		new_scene_node, is_additive, options.node_name, add_to_back
	)
	_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)
	if not is_additive:
		_current_scene_enum = scene
	scene_loaded.emit()

	await _effector.fade_in(options.fade_in_time)
	_end_transitioning()


# ------------- [Public Methods] -------------
## Discards the current main scene and switches to a new one.
func switch_to_scene(
	scene: Scenes.Id, add_to_back: bool, options := SceneLoadOptions.new()
) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: switch_to_scene called with Scenes.Id.NONE.")
		return
	_perform_transition_blocking(scene, false, add_to_back, options)


## Adds a scene while keeping the current scene (for UI or sub-screens).
func add_scene(scene: Scenes.Id, options := SceneLoadOptions.new()) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: add_scene called with Scenes.Id.NONE.")
		return
	_perform_transition_blocking(scene, true, false, options)


func load_previous_scene(options := SceneLoadOptions.new()) -> bool:
	var target_scene: Scenes.Id = _history_stack.pop()
	if target_scene != Scenes.Id.NONE and _current_scene_enum != Scenes.Id.NONE:
		var opt := options.copy()
		opt.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
		switch_to_scene(target_scene, false, opt)
		return true
	return false


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
	_set_transitioning(false)
	await _effector.fade_out(fade_time)
	get_tree().quit(0)


# ------------- [Async Loading] -------------
func preload_scene_async(scene: Scenes.Id, use_sub_threads = false) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: preload_scene_async called with Scenes.Id.NONE.")
		return
	_load_scene_path = _scene_db.get_scene_path_from_enum(scene)
	_load_scene_id = scene
	_enable_process(true)
	ResourceLoader.load_threaded_request(_load_scene_path, "", use_sub_threads)


func load_scene_with_transition(
	next_scene: Scenes.Id,
	transition_scene: Scenes.Id,
	opt_fade_in := SceneLoadOptions.new(),
	opt_activate := opt_fade_in
) -> void:
	assert(next_scene != Scenes.Id.NONE, "Scene Manager: next_scene cannot be NONE.")
	assert(transition_scene != Scenes.Id.NONE, "Scene Manager: transition_scene cannot be NONE.")

	_reserved_scene_id = next_scene
	_reserved_options = opt_activate.copy()
	_is_reserved_as_additive = false

	var trans_options := opt_fade_in.copy()
	trans_options.node_name = _LOADING_NODE_NAME

	add_scene(transition_scene, trans_options)


func instantiate_async_result() -> void:
	if _load_scene_path == "" or _reserved_scene_id == Scenes.Id.NONE:
		push_warning("instantiate_async_result: No reserved scene to instantiate.")
		return

	_enable_process(false)
	var res := ResourceLoader.load_threaded_get(_load_scene_path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = _load_scene_path

		# Temporarily additive to coexist with loading screen
		var parent_node := _attach_scene_to_tree(
			scene_node, true, _to_tmp_name(_reserved_options.node_name), false
		)

		# Place it right behind the loading screen (which is at the top).
		var root := get_tree().root
		root.move_child(parent_node, root.get_child_count() - 2)

		_loaded_scene_map[_reserved_scene_id] = _SceneEntry.new(parent_node, scene_node)
		_load_scene_path = ""
	else:
		push_error(
			false, "Scene Manager: Failed to get threaded load result for %s" % _load_scene_path
		)


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
func activate_prepared_scene() -> void:
	if _reserved_scene_id == Scenes.Id.NONE:
		push_warning(
			"activate_prepared_scene called but no scene is reserved. Ensure you are in an async load flow."
		)
		return
	assert(
		_loaded_scene_map.has(_reserved_scene_id), "Scene Manager: Reserved scene entry missing."
	)

	_set_transitioning(_reserved_options.clickable)
	await _effector.fade_out(_reserved_options.fade_out_time)

	# Remove the loading screen
	_unload_scene(_LOADING_NODE_NAME)

	if not _is_reserved_as_additive:
		# Remove everything except _reserved scene
		var target_names: Array[String] = []
		for id in _loaded_scene_map:
			if id == _reserved_scene_id:
				continue
			target_names.append(_loaded_scene_map[id].container_node.name)

		for t_name in target_names:
			_unload_scene(t_name)

		# Revert the temporary name back to the original name to avoid conflicts
		var cont := _loaded_scene_map[_reserved_scene_id].container_node
		cont.name = _from_tmp_name(cont.name)

		_current_scene_enum = _reserved_scene_id

	await _effector.fade_in(_reserved_options.fade_in_time)

	# Reset the reserved scene information now that the scene has fully loaded.
	_reserved_scene_id = Scenes.Id.NONE
	_reserved_options = null

	_end_transitioning()


# ------------- [Utils] -------------
func get_scene_blocking(scene: Scenes.Id) -> PackedScene:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: get_scene_blocking called with Scenes.Id.NONE.")
		return null
	return load(_scene_db.get_scene_path_from_enum(scene))


func create_scene_instance_blocking(scene: Scenes.Id) -> Node:
	var pack := get_scene_blocking(scene)
	return pack.instantiate() if pack else null


## Returns the currently reserved scene Enum.
## @return Reserved scene Enum.
func get_reserved_scene() -> Scenes.Id:
	return _reserved_scene_id


## Returns the reserved load options for the reserved scene.
func get_reserved_load_option() -> SceneLoadOptions:
	return _reserved_options
