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

# ------------- [Constants] -------------
const _C = preload("uid://c3vvdktou45u")
const _RING_BUFFER = preload("uid://b6phac21mxnxr")
const _LOADING_NODE_NAME: String = "===Transition==="
const _TRANSITION_PLAYER = preload("uid://2iy8wfgenjka")
const _RESOURCE_LOADER = preload("uid://dabq3s83q0iku")
@export var _initial_fade_in_time = 1.0
@export var _actual_scene_container_path: NodePath = "/root"


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


# ------------- [Private Variable] -------------
var _scene_db: SMgrData
## ID of the scene currently being loaded.
var _load_scene_id: Scenes.Id = Scenes.Id.NONE

# Reservation info for asynchronous loading
var _reserved_scene_id: Scenes.Id = Scenes.Id.NONE
## Load options for the reserved scene.
var _reserved_options: SceneLoadOptions
var _is_reserved_as_additive: bool = false
## Whether the reserved scene should be added to history when activated.
var _reserved_add_to_back: bool = false

## Scenes currently present in the field (Key: Scene-Id, Value: _SceneEntry).
var _loaded_scene_map: Dictionary[Scenes.Id, _SceneEntry] = {}
var _current_scene_enum: Scenes.Id = Scenes.Id.NONE
var _trash_node: Control
var _transition_player: Node = null

@onready var _history_stack := _RING_BUFFER.new()

## ResourceLoaderMgr instance
@onready var _loader_mgr := _RESOURCE_LOADER.new()


# ------------- [Callbacks] -------------
func _ready() -> void:
	# Add ResourceLoaderMgr as a child to let it process
	add_child(_loader_mgr)
	_loader_mgr.progress_changed.connect(_on_loader_progress_changed)

	_init_trash_node()
	_init_effector()

	var PS := preload("uid://dn6eh4s0h8jhi")
	# SMgrData is a Resource, so read it with the loader
	_scene_db = load(PS.scene_data_path)
	assert(_scene_db != null, "Scene Manager: Failed to load scene database resource.")

	var current_path := get_tree().current_scene.scene_file_path
	_current_scene_enum = _scene_db.get_scene_enum_by_path(current_path)

	_on_initial_setup.call_deferred()


# ------------- [Private Methods] -------------
func _init_effector() -> void:
	_transition_player = _TRANSITION_PLAYER.instantiate()
	_transition_player.name = "TransitionPlayer"
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


## Initial setup: moves the current scene to the manager's control.
func _on_initial_setup() -> void:
	var scene_node := get_tree().current_scene
	assert(scene_node != null, "Scene Manager: current_scene is null during initial setup.")

	var default_wrapper := _create_ui_wrapper(_C.DEFAULT_TREE_NODE_NAME)
	_get_actual_scene_container().add_child(default_wrapper)
	scene_node.reparent(default_wrapper)

	# Don't map a NONE scene as that shouldn't be here. It's possible to reach here
	# if the loaded scene wasn't part of the enums and loaded some other way.
	if _current_scene_enum != Scenes.Id.NONE:
		_loaded_scene_map[_current_scene_enum] = _SceneEntry.new(default_wrapper, scene_node)
	else:
		push_warning("Initial scene not found in DB (Scenes.Id.NONE).")

	_transition_player.set_clickable(false)
	await _transition_player.fade_in(_initial_fade_in_time)
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
	await _transition_player.fade_out(options.fade_out_time)

	# --- Scene Replacement ---
	# Unload everything for a clean switch
	_unload_all_nodes()
	if add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	var new_scene_node := _create_scene_instance_blocking(scene)
	if not new_scene_node:
		push_error(
			"Scene Manager: Failed to instantiate switch_to_scene: %s" % Scenes.Id.find_key(scene)
		)
		_transition_player.set_clickable(true)
		return null

	var parent_node := _create_ui_wrapper(options.node_name)
	parent_node.add_child(new_scene_node)
	options.call_pre_cb(parent_node, new_scene_node)
	_get_actual_scene_container().add_child(parent_node)

	# --- Register and Finalize ---
	_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)
	_current_scene_enum = scene
	scene_loaded.emit(scene)

	await _transition_player.fade_in(options.fade_in_time)
	_transition_player.set_clickable(true)
	scene_transition_completed.emit(scene)
	return new_scene_node


## Adds a scene while keeping the current scene. (Additive Routine)
func add_scene(scene: Scenes.Id, options := SceneLoadOptions.new()) -> Node:
	if scene == Scenes.Id.NONE:
		push_warning("Scene Manager: add_scene called with NONE.")
		return null

	if _loaded_scene_map.has(scene):
		push_warning(
			"Scene Manager: Scene %s is already loaded (additive)." % Scenes.Id.find_key(scene)
		)
		return null

	# Additive mode: No fading, only name conflict resolution
	_unload_scene(options.node_name, false)

	var new_scene_node := _create_scene_instance_blocking(scene)
	if not new_scene_node:
		push_error("Scene Manager: Failed to instantiate add_scene: %s" % Scenes.Id.find_key(scene))
		return null

	var parent_node := _create_ui_wrapper(options.node_name)
	parent_node.add_child(new_scene_node)
	_get_actual_scene_container().add_child(parent_node)
	options.call_pre_cb(parent_node, new_scene_node)

	# Register additive scene
	_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)
	scene_loaded.emit(scene)
	return new_scene_node


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
	await _transition_player.fade_out(fade_time)
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
	opt_fade_in := SceneLoadOptions.new(),
	opt_activate := opt_fade_in
) -> void:
	assert(next_scene != Scenes.Id.NONE, "Scene Manager: next_scene cannot be NONE.")
	assert(transition_scene != Scenes.Id.NONE, "Scene Manager: transition_scene cannot be NONE.")

	_reserved_scene_id = next_scene
	_reserved_options = opt_activate.copy()
	_is_reserved_as_additive = false
	_reserved_add_to_back = add_to_back

	var trans_options := opt_fade_in.copy()
	trans_options.node_name = _LOADING_NODE_NAME

	add_scene(transition_scene, trans_options)


func instantiate_async_result() -> void:
	var path := _scene_db.get_scene_path_from_enum(_reserved_scene_id)
	if path == "" or _reserved_scene_id == Scenes.Id.NONE:
		push_warning("instantiate_async_result: No reserved scene to instantiate.")
		return

	# Add current scene to history before switching
	if _reserved_add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	# Load directly (it should be cached in ResourceLoader by ResourceLoaderMgr)
	var res := load(path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = path
		# Temporary additive attachment
		var tmp_name := _to_tmp_name(_reserved_options.node_name)
		var parent_node := _create_ui_wrapper(tmp_name)
		parent_node.add_child(scene_node)
		_reserved_options.call_pre_cb(parent_node, scene_node)

		var target_node := _get_actual_scene_container()
		target_node.add_child(parent_node)

		# Place it right behind the loading screen (which is at the top).
		target_node.move_child(parent_node, target_node.get_child_count() - 2)

		_loaded_scene_map[_reserved_scene_id] = _SceneEntry.new(parent_node, scene_node)
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
	if _reserved_scene_id == Scenes.Id.NONE:
		push_warning("activate_prepared_scene called but no scene is reserved.")
		return null
	assert(
		_loaded_scene_map.has(_reserved_scene_id), "Scene Manager: Reserved scene entry missing."
	)

	_transition_player.set_clickable(_reserved_options.clickable)
	await _transition_player.fade_out(_reserved_options.fade_out_time)

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

	await _transition_player.fade_in(_reserved_options.fade_in_time)

	var ret := _loaded_scene_map[_reserved_scene_id].scene_node
	# Reset the reserved scene information now that the scene has fully loaded.
	_reserved_scene_id = Scenes.Id.NONE
	_reserved_options = null
	_reserved_add_to_back = false

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
	return _reserved_scene_id


## Returns the reserved load options for the reserved scene.
func get_reserved_load_option() -> SceneLoadOptions:
	return _reserved_options
