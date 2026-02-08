extends Node
## Main SceneManager that handles adding and transitioning between scenes.

# ------------- [Signal] -------------
## Emitted when loading is completed.
signal load_finished
## Emitted when loading progress (0-100) changes.
signal load_percent_changed(value: int)
## Emitted when scene instantiation is completed.
signal scene_loaded
## Emitted at the start of the fade-in effect.
signal fade_in_started
## Emitted at the start of the fade-out effect.
signal fade_out_started
## Emitted when the fade-in effect finishes.
signal fade_in_finished
## Emitted when the fade-out effect finishes.
signal fade_out_finished

# ------------- [Constants] -------------
const _C = preload("uid://c3vvdktou45u")
const _RING_BUFFER = preload("uid://t3tlcswbndjo")
const _INITIAL_FADE_IN_TIME = 1.0


# ------------- [Defines] -------------
## Internal class to hold entries of loaded scenes.
class _SceneEntry:
	var container_node: Control
	var scene_node: Node

	## Initialize the instance.
	## @param p_container The parent wrapper node.
	## @param p_scene The main scene node.
	func _init(p_container: Control, p_scene: Node) -> void:
		container_node = p_container
		scene_node = p_scene


## Definition of animation keys.
class _AnimKey:
	const FADE = &"fade"


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
var _reserved_mode: _C.SceneLoadingMode = _C.SceneLoadingMode.SINGLE

## Scenes currently present in the field (Key: Scene-Id, Value: _SceneEntry).
var _loaded_scene_map: Dictionary[Scenes.Id, _SceneEntry] = {}
var _current_scene_enum: Scenes.Id = Scenes.Id.NONE
var _is_transitioning: bool = false
var _trash_node: Control

@onready var _fade_color_rect: ColorRect = %fade
@onready var _animation_player: AnimationPlayer = %animation_player
@onready var _history_stack := _RING_BUFFER.new()


# ------------- [Callbacks] -------------
func _ready() -> void:
	_init_trash_node()
	set_process(false)

	# SMgrData is a Resource, so read it with the loader
	_scene_db = load(_ps.scene_data_path)

	var current_path := get_tree().current_scene.scene_file_path
	_current_scene_enum = _scene_db.get_scene_enum_by_path(current_path)

	_on_initial_setup.call_deferred()


func _process(_delta: float) -> void:
	_check_loading_progress()


# ------------- [Private Methods] -------------
func _init_trash_node() -> void:
	_trash_node = Control.new()
	_trash_node.name = "trash_node"
	_trash_node.process_mode = Node.PROCESS_MODE_DISABLED
	_trash_node.visible = false
	add_child(_trash_node)


## Checks progress during asynchronous scene loading and emits signals.
func _check_loading_progress() -> void:
	var prev_percent := int(_load_progress[0] * 100) if not _load_progress.is_empty() else 0
	var status := ResourceLoader.load_threaded_get_status(_load_scene_path, _load_progress)
	var next_percent := int(_load_progress[0] * 100)

	if prev_percent != next_percent:
		load_percent_changed.emit(next_percent)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_load_progress.clear()
		load_finished.emit()
	elif status in [ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]:
		set_process(false)
		push_error("Scene Manager: Loading failed for: %s" % _load_scene_path)


func _create_ui_wrapper(node_name: String) -> Control:
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

	# Execute fade-in on application start.
	_execute_fade_async(_INITIAL_FADE_IN_TIME, false)


## Executes fade effect and waits for completion.
## @param speed Playback speed (seconds).
## @param is_out True for fade-out, false for fade-in.
func _execute_fade_async(speed: float, is_out: bool) -> void:
	if speed <= 0:
		if is_out:
			fade_out_finished.emit()
		else:
			fade_in_finished.emit()
		return

	if is_out:
		fade_out_started.emit()
		_animation_player.play(_AnimKey.FADE, -1, 1.0 / speed, false)
	else:
		fade_in_started.emit()
		_animation_player.play(_AnimKey.FADE, -1, -1.0 / speed, true)

	await _animation_player.animation_finished

	if is_out:
		fade_out_finished.emit()
	else:
		fade_in_finished.emit()


## Toggles mouse event transparency during transitions.
func _set_clickable(clickable: bool) -> void:
	_fade_color_rect.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if clickable else Control.MOUSE_FILTER_STOP
	)


## Attaches a specified node to the scene tree and unloads existing nodes if necessary.
func _attach_scene_to_tree(
	node: Node, mode: _C.SceneLoadingMode, node_name: String, add_to_back: bool
) -> Control:
	var root := get_tree().root

	# If SINGLE, send all existing nodes to the trash
	if mode == _C.SceneLoadingMode.SINGLE:
		_unload_all_nodes()
	elif mode == _C.SceneLoadingMode.SINGLE_NODE:
		_unload_scene(node_name)

	# At this point, the node with node_name has been removed from root (moved to trash).
	# This ensures the newly created wrapper will have the exact name specified.
	var parent_node := _create_ui_wrapper(node_name)
	root.add_child(parent_node)

	parent_node.add_child(node)

	if add_to_back and _current_scene_enum != Scenes.Id.NONE and mode == _C.SceneLoadingMode.SINGLE:
		_history_stack.push(_current_scene_enum)

	return parent_node


## Frees all scenes under a specified parent node and removes them from the map.
## @param node_name Name of the parent node to release.
func _unload_scene(node_name: String) -> void:
	# If a node with the specified name exists directly under root, remove it.
	var root := get_tree().root
	var target_node := root.get_node_or_null(node_name)
	if not target_node:
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


# Internal common transition logic
func _perform_transition(
	scene: Scenes.Id, mode: _C.SceneLoadingMode, add_to_back: bool, options: SceneLoadOptions
) -> void:
	_is_transitioning = true
	_set_clickable(options.clickable)

	await _execute_fade_async(options.fade_out_time, true)

	# --- Actual scene switching ---
	var new_scene_node := create_scene_instance_blocking(scene)
	if new_scene_node:
		var parent_node := _attach_scene_to_tree(
			new_scene_node, mode, options.node_name, add_to_back
		)
		_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)
		if mode == _C.SceneLoadingMode.SINGLE:
			_current_scene_enum = scene
		scene_loaded.emit()
	# ------

	await _execute_fade_async(options.fade_in_time, false)

	_set_clickable(true)
	_is_transitioning = false


# ------------- [Public Methods] -------------
## Discards the current main scene and switches to a new one.
func switch_to_scene(
	scene: Scenes.Id, add_to_back: bool, options := SceneLoadOptions.new()
) -> void:
	if scene == Scenes.Id.NONE:
		return
	_perform_transition(scene, _C.SceneLoadingMode.SINGLE, add_to_back, options)


## Adds a scene while keeping the current scene (for UI or sub-screens).
func add_scene(scene: Scenes.Id, options := SceneLoadOptions.new()) -> void:
	if scene == Scenes.Id.NONE:
		return
	_perform_transition(scene, _C.SceneLoadingMode.ADDITIVE, false, options)


func load_previous_scene() -> bool:
	var target_scene: Scenes.Id = _history_stack.pop()
	if target_scene != Scenes.Id.NONE and _current_scene_enum != Scenes.Id.NONE:
		var options := SceneLoadOptions.new()
		options.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
		switch_to_scene(target_scene, false, options)
		return true
	return false


## Reloads the current scene.
## @return True if executed.
func reload_current_scene() -> bool:
	# Use the same parent node the scene currently has to keep it consistent.
	if _current_scene_enum == Scenes.Id.NONE:
		push_warning("Attempted to reload current scene, but current scene is NONE.")
		return false

	var options := SceneLoadOptions.new()
	options.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
	switch_to_scene(_current_scene_enum, false, options)
	return true


## Quits the game after a fade-out effect.
## @param fade_time Duration of the fade-out (seconds).
func exit_game(fade_time: float = 1.0) -> void:
	_is_transitioning = true
	_set_clickable(false)
	# Execute and wait for fade-out.
	await _execute_fade_async(fade_time, true)
	# Exit.
	get_tree().quit(0)


# ------------- [Async Loading] -------------
func preload_scene_async(scene: Scenes.Id, use_sub_threads = false) -> void:
	if scene == Scenes.Id.NONE:
		return
	_load_scene_path = _scene_db.get_scene_path_from_enum(scene)
	_load_scene_id = scene
	set_process(true)
	ResourceLoader.load_threaded_request(_load_scene_path, "", use_sub_threads)


func load_scene_with_transition(
	next_scene: Scenes.Id, transition_scene: Scenes.Id, options := SceneLoadOptions.new()
) -> void:
	_reserved_scene_id = next_scene
	_reserved_options = options.copy()
	_reserved_mode = _C.SceneLoadingMode.SINGLE

	var trans_options := SceneLoadOptions.new()
	trans_options.node_name = _C.DEFAULT_LOADING_NODE_NAME

	add_scene(transition_scene, trans_options)


func instantiate_async_result() -> void:
	if _load_scene_path == "" or _reserved_scene_id == Scenes.Id.NONE:
		push_warning("instantiate_async_result: No reserved scene to instantiate.")
		return

	var res := ResourceLoader.load_threaded_get(_load_scene_path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = _load_scene_path

		# Temporarily add in ADDITIVE mode.
		# To avoid name conflicts if _reserved_options.node_name is the same as an existing scene,
		# we use a temporary unique name here.
		var parent_node := _attach_scene_to_tree(
			scene_node,
			_C.SceneLoadingMode.ADDITIVE,
			_to_tmp_name(_reserved_options.node_name),
			false
		)

		# Place it right behind the loading screen (which is at the top).
		var root := get_tree().root
		root.move_child(parent_node, root.get_child_count() - 2)

		_loaded_scene_map[_reserved_scene_id] = _SceneEntry.new(parent_node, scene_node)
		_load_scene_path = ""


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

	_is_transitioning = true
	_set_clickable(_reserved_options.clickable)

	await _execute_fade_async(_reserved_options.fade_out_time, true)

	# Remove the loading screen
	_unload_scene(_C.DEFAULT_LOADING_NODE_NAME)

	# In SINGLE mode, remove everything except the new scene (reserved_scene_id)
	if _reserved_mode == _C.SceneLoadingMode.SINGLE:
		var target_names: Array[String] = []
		for id in _loaded_scene_map:
			if id == _reserved_scene_id:
				continue

			var n_name := _loaded_scene_map[id].container_node.name
			if n_name not in target_names:
				target_names.append(n_name)

		for t_name in target_names:
			_unload_scene(t_name)

		# Revert the temporary name back to the original name to avoid conflicts
		var cont := _loaded_scene_map[_reserved_scene_id].container_node
		cont.name = _from_tmp_name(cont.name)

		_current_scene_enum = _reserved_scene_id

	await _execute_fade_async(_reserved_options.fade_in_time, false)

	_set_clickable(true)
	# Reset the reserved scene information now that the scene has fully loaded.
	_is_transitioning = false
	_reserved_scene_id = Scenes.Id.NONE
	_reserved_options = null


# ------------- [Utils] -------------
func get_scene_blocking(scene: Scenes.Id) -> PackedScene:
	if scene == Scenes.Id.NONE:
		return null
	var address := _scene_db.get_scene_path_from_enum(scene)
	return load(address)


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
