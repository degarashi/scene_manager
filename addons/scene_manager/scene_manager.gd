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
	## @param p_wrapper The parent wrapper node.
	## @param p_scene The main scene node.
	func _init(p_wrapper: Control, p_scene: Node) -> void:
		container_node = p_wrapper
		scene_node = p_scene


## Definition of animation keys.
class _AnimKey:
	const FADE = &"fade"


# ------------- [Private Variable] -------------
static var _ps := preload("uid://dn6eh4s0h8jhi")

var _scene_db: SMgrData
var _loading_scene_path: String = ""
## ID of the scene currently being loaded.
var _load_scene_id: Scenes.Id = Scenes.Id.NONE
## Array for holding raw loading progress data.
var _load_progress: Array = []
## Reserved scene ID for the next scheduled load.
var _reserved_scene_id: Scenes.Id = Scenes.Id.NONE
## Load options for the reserved scene.
var _reserved_options: SceneLoadOptions

## Map of loaded scenes (Key: Id, Value: _SceneEntry).
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

	_scene_db = SMgrData.load_data(_ps.scene_path)

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
	var status := ResourceLoader.load_threaded_get_status(_loading_scene_path, _load_progress)
	var next_percent := int(_load_progress[0] * 100)

	if prev_percent != next_percent:
		load_percent_changed.emit(next_percent)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_load_progress.clear()
			load_finished.emit()
		ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
			push_error("Scene Manager: Loading failed for path: %s" % _loading_scene_path)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_error("Scene Manager: Invalid resource at path: %s" % _loading_scene_path)


## Creates a full-screen Control wrapper to hold scenes.
## @param node_name Name of the wrapper node.
## @return Configured Control node.
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
func _attach_scene_to_tree(node: Node, options: SceneLoadOptions) -> Control:
	var root := get_tree().root

	# If SINGLE, send all existing nodes to the trash
	if options.mode == _C.SceneLoadingMode.SINGLE:
		_unload_all_nodes()
	elif options.mode == _C.SceneLoadingMode.SINGLE_NODE:
		_unload_node(options.node_name)

	# At this point, the node with options.node_name has been removed from root (moved to trash).
	# This ensures the newly created wrapper will have the exact name specified.
	var parent_node := _create_ui_wrapper(options.node_name)
	root.add_child(parent_node)

	parent_node.add_child(node)

	if options.add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	return parent_node


## Frees all scenes under a specified parent node and removes them from the map.
## @param node_name Name of the parent node to release.
func _unload_node(node_name: String) -> void:
	var root := get_tree().root
	var target_node := root.get_node_or_null(node_name)

	if not target_node:
		push_warning(
			"Scene Manager: Attempted to unload node '%s', but it was not found." % node_name
		)
		return

	# remove from Id map
	var ids_to_remove: Array[Scenes.Id] = []
	for id in _loaded_scene_map:
		if _loaded_scene_map[id].container_node.name == node_name:
			ids_to_remove.append(id)

	for id in ids_to_remove:
		_loaded_scene_map.erase(id)

	# Move to trash and then delete
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
		_unload_node(n_name)


# ------------- [Public Method] -------------
## Sets the history stack capacity (number of times you can go back).
## @param input Allowed number of history entries (0 to disable).
func set_back_limit(input: int) -> void:
	_history_stack.set_capacity(maxi(input, 0))


## Clears the entire history stack.
func clear_history() -> void:
	_history_stack.clear()


## Blocking generation of an instance from a scene ID.
## @param scene Scene ID.
## @return Generated node.
func create_scene_instance_blocking(scene: Scenes.Id) -> Node:
	var pack := get_scene_blocking(scene)
	return pack.instantiate() if pack else null


## Blocking load of a PackedScene from a scene ID.
## @param scene Scene ID.
## @return Loaded PackedScene.
func get_scene_blocking(scene: Scenes.Id) -> PackedScene:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to get PackedScene for a NONE scene. Skipping.")
		return null

	var address := _scene_db.get_scene_path_from_enum(scene)
	assert(
		not address.is_empty(),
		(
			"Scene Manager: The path for Scene ID '%s' was not found in the database.\n
				 Ensure the scene is correctly registered."
			% Scenes.Id.keys()[scene]
		)
	)
	return load(address)


## Switches to a specified scene (replaces the existing scene by default).
## @param scene Target scene ID.
## @param options Loading configuration options.
func switch_to_scene(scene: Scenes.Id, options := SceneLoadOptions.new()) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to get PackedScene for a NONE scene. Skipping.")
		return

	_is_transitioning = true
	_set_clickable(options.clickable)

	await _execute_fade_async(options.fade_out_time, true)

	# --- Actual scene switching ---
	var new_scene_node := create_scene_instance_blocking(scene)
	if new_scene_node:
		var parent_node := _attach_scene_to_tree(new_scene_node, options)
		_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)
		_current_scene_enum = scene
		scene_loaded.emit()
	# ------

	await _execute_fade_async(options.fade_in_time, false)

	_set_clickable(true)
	_is_transitioning = false


## Goes back to the previous scene from history.
## @return True if the transition started successfully.
func load_previous_scene() -> bool:
	var target_scene: Scenes.Id = _history_stack.pop()
	if target_scene != Scenes.Id.NONE and _current_scene_enum != Scenes.Id.NONE:
		var options := SceneLoadOptions.new()
		options.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
		options.add_to_back = false
		switch_to_scene(target_scene, options)
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
	options.add_to_back = false
	switch_to_scene(_current_scene_enum, options)
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


## Instantiates the loaded scene into the tree (initially hidden).
## Should be called after load_finished following a preload_scene_async call.
func instantiate_async_result() -> void:
	if _loading_scene_path == "" or _reserved_scene_id == Scenes.Id.NONE:
		push_warning("instantiate_async_result: No reserved scene to instantiate.")
		return

	var res := ResourceLoader.load_threaded_get(_loading_scene_path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = _loading_scene_path

		var options := _reserved_options.copy()
		if options.mode == _C.SceneLoadingMode.SINGLE:
			options.mode = _C.SceneLoadingMode.SINGLE_NODE

		var parent_node := _attach_scene_to_tree(scene_node, options)

		# Ensure the parent_node is not the last node to keep the transition scene on top.
		var root := get_tree().get_root()
		root.move_child(parent_node, root.get_child_count() - 2)

		_loaded_scene_map[_reserved_scene_id] = _SceneEntry.new(parent_node, scene_node)

		_loading_scene_path = ""
		_load_scene_id = Scenes.Id.NONE


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

	# Unload the temporary transition/loading scene node.
	_unload_node(_C.DEFAULT_LOADING_NODE_NAME)

	# If the original load options was SINGLE loading mode, then also remove any other
	# node that isn't part of the load option node name.
	if _reserved_options.mode == _C.SceneLoadingMode.SINGLE:
		var current_node_name := _reserved_options.node_name
		var targets: Array[String] = []
		for id in _loaded_scene_map:
			var n_name := _loaded_scene_map[id].container_node.name
			if n_name != current_node_name and n_name not in targets:
				targets.append(n_name)

		for n_name in targets:
			_unload_node(n_name)

	_current_scene_enum = _reserved_scene_id

	await _execute_fade_async(_reserved_options.fade_in_time, false)

	_set_clickable(true)
	# Reset the reserved scene information now that the scene has fully loaded.
	_is_transitioning = false
	_reserved_scene_id = Scenes.Id.NONE
	_reserved_options = null


## Starts interactive (asynchronous) scene loading.
## @param scene Target scene ID.
## @param use_sub_threads Whether to use sub-threads.
func preload_scene_async(scene: Scenes.Id, use_sub_threads = false) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to preload_scene_async a NONE scene. Skipping.")
		return

	_loading_scene_path = _scene_db.get_scene_path_from_enum(scene)
	_load_scene_id = scene
	set_process(true)
	ResourceLoader.load_threaded_request(_loading_scene_path, "", use_sub_threads)


## Executes scene transition via a loading/transition scene.
## @param next_scene Final destination scene ID.
## @param transition_scene Scene to display during loading.
## @param options Load options for the final scene.
func load_scene_with_transition(
	next_scene: Scenes.Id, transition_scene: Scenes.Id, options := SceneLoadOptions.new()
) -> void:
	# Reserve the target scene.
	_reserved_scene_id = next_scene
	_reserved_options = options.copy()

	# Configure the transition scene to appear on a separate node on top.
	var trans_options := SceneLoadOptions.new()
	trans_options.node_name = _C.DEFAULT_LOADING_NODE_NAME
	trans_options.mode = _C.SceneLoadingMode.ADDITIVE
	trans_options.add_to_back = false

	switch_to_scene(transition_scene, trans_options)


## Returns the currently reserved scene Enum.
## @return Reserved scene Enum.
func get_reserved_scene() -> Scenes.Id:
	return _reserved_scene_id


## Returns the reserved load options for the reserved scene.
func get_reserved_load_option() -> SceneLoadOptions:
	return _reserved_options
