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
	var container_node: Node
	var scene_node: Node

	## Initialize the instance.
	## @param p_wrapper The parent wrapper node.
	## @param p_scene The main scene node.
	func _init(p_wrapper: Node, p_scene: Node) -> void:
		container_node = p_wrapper
		scene_node = p_scene


## Definition of animation keys.
class _AnimKey:
	const FADE = &"fade"


static var _ps := preload("uid://dn6eh4s0h8jhi")
## Path of the scene currently being loaded.
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
## Scene database.
var _scene_db: SMgrData
@onready var _fade_color_rect: ColorRect = %fade
@onready var _animation_player: AnimationPlayer = %animation_player
## Flag indicating if a transition is in progress.
@onready var _is_transitioning: bool = false
## Stack for scene transition history.
@onready var _history_stack := _RING_BUFFER.new()
## Current scene ID.
@onready var _current_scene_enum: Scenes.Id = Scenes.Id.NONE


# ------------- [Callbacks] -------------
## Initialization process when ready.
func _ready() -> void:
	set_process(false)

	_scene_db = SMgrData.load_data(_ps.scene_path)
	var path: String = get_tree().current_scene.scene_file_path
	_current_scene_enum = _scene_db.get_scene_enum_by_path(path)

	call_deferred("_on_initial_setup")


## Monitors loading progress.
## @param _delta Frame elapsed time.
func _process(_delta: float) -> void:
	_check_loading_progress()


# ------------- [Private Method] -------------
## Checks progress during interactive scene switching and emits signals.
func _check_loading_progress() -> void:
	var prev_percent: int = 0
	if len(_load_progress) != 0:
		prev_percent = int(_load_progress[0] * 100)

	var status := ResourceLoader.load_threaded_get_status(_loading_scene_path, _load_progress)
	var next_percent: int = int(_load_progress[0] * 100)
	if prev_percent != next_percent:
		load_percent_changed.emit(next_percent)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_load_progress = []
		load_finished.emit()
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		pass
	else:
		assert(false, "Scene Manager Error: for some reason, loading failed.")


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


## Initial setup: moves the current scene to the default parent node and stores it in the map.
func _on_initial_setup() -> void:
	var scene_node := get_tree().current_scene
	var root := get_tree().root

	# Create wrapper using the helper function.
	var default_node := _create_ui_wrapper(_C.DEFAULT_TREE_NODE_NAME)

	# Order: Add to root first, then reparent.
	root.add_child(default_node)
	scene_node.reparent(default_node)

	# Don't map a NONE scene as that shouldn't be here. It's possible to reach here
	# if the loaded scene wasn't part of the enums and loaded some other way.
	if _current_scene_enum != Scenes.Id.NONE:
		_loaded_scene_map[_current_scene_enum] = _SceneEntry.new(default_node, scene_node)
	else:
		push_warning("Loaded scene not added to the mapping due to being NONE.")

	# Execute fade-in on application start.
	_execute_fade_async(_INITIAL_FADE_IN_TIME, false)


## Executes fade effect and waits for completion.
## @param speed Playback speed (seconds).
## @param is_out True for fade-out, false for fade-in.
func _execute_fade_async(speed: float, is_out: bool) -> void:
	var executed := false
	if is_out:
		executed = _fade_out(speed)
	else:
		executed = _fade_in(speed)

	if executed:
		await _animation_player.animation_finished
		if is_out:
			fade_out_finished.emit()
		else:
			fade_in_finished.emit()


## Plays fade-in animation.
## @param speed Playback speed (seconds).
## @return True if executed.
func _fade_in(speed: float) -> bool:
	if speed <= 0:
		return false

	fade_in_started.emit()
	_animation_player.play(_AnimKey.FADE, -1, -1 / speed, true)
	return true


## Plays fade-out animation.
## @param speed Playback speed (seconds).
## @return True if executed.
func _fade_out(speed: float) -> bool:
	if speed <= 0:
		return false

	fade_out_started.emit()
	_animation_player.play(_AnimKey.FADE, -1, 1 / speed, false)
	return true


## Sets the transition start flag.
func _set_transition_started() -> void:
	_is_transitioning = true


## Sets the transition finished flag.
func _set_transition_finished() -> void:
	_is_transitioning = false


## Appends current scene to the history stack.
## @param scene ID of the scene to add.
func _append_history(scene: Scenes.Id) -> void:
	_history_stack.push(scene)


## Retrieves and removes the latest scene from the history stack.
## @return The retrieved scene ID.
func _pop_history() -> Scenes.Id:
	var target_scene := _history_stack.pop()
	if target_scene:
		return target_scene
	return Scenes.Id.NONE


## Configures mouse event transparency during transitions.
## @param clickable True if clicks should be allowed.
func _set_clickable(clickable: bool) -> void:
	if clickable:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP


## Attaches a specified node to the scene tree based on load options.
## @param node The instance to add.
## @param load_options Loading configuration options.
## @return The parent node where the scene was added.
func _attach_scene_to_tree(node: Node, load_options := SceneLoadOptions.new()) -> Node:
	# For single scene loading, remove specified nodes and load the scene into a default node.
	var root := get_tree().get_root()
	var parent_node: Node = root.get_node_or_null(load_options.node_name)

	if (
		load_options.mode == _C.SceneLoadingMode.SINGLE
		or load_options.mode == _C.SceneLoadingMode.SINGLE_NODE
	):
		# SINGLE: Remove all nodes.
		# SINGLE_NODE: Remove only the node specified in options.
		if load_options.mode == _C.SceneLoadingMode.SINGLE:
			_unload_all_nodes()
		elif parent_node:
			_unload_node(load_options.node_name)

		# Create using the helper function.
		parent_node = _create_ui_wrapper(load_options.node_name)
		root.add_child(parent_node)
		parent_node.add_child(node)

		# Add the "current scene" to history, not the incoming one,
		# so we can return to it later if needed.
		if load_options.add_to_back:
			_append_history(_current_scene_enum)
	else:
		# ADDITIVE: Create node if it doesn't exist, then load the scene into it.
		if not parent_node:
			parent_node = _create_ui_wrapper(load_options.node_name)
			root.add_child(parent_node)

		assert(parent_node, "Error: Could not retrieve node %s." % load_options.node_name)
		parent_node.add_child(node)

	return parent_node


## Frees all scenes under a specified parent node and removes them from the map.
## @param node_name Name of the parent node to release.
func _unload_node(node_name: String) -> void:
	if not get_tree().root.has_node(node_name):
		assert(false, "Error: Parent node %s does not exist." % node_name)

	# Use the node name to identify all scenes loaded under it.
	# Release those scenes and remove from mapping before deleting the parent node itself.
	for scene in _loaded_scene_map.keys():
		var ent := _loaded_scene_map[scene]
		if ent.container_node.name == node_name:
			ent.scene_node.free()
			_loaded_scene_map.erase(scene)

	get_tree().root.get_node(node_name).free()


## Frees all nodes related to the loaded scene map.
func _unload_all_nodes() -> void:
	# Extract unique parent node names to prevent errors while modifying the map during iteration.
	var node_names_to_unload: Array[String] = []
	for entry in _loaded_scene_map.values():
		var n_name: String = entry.container_node.name
		if not n_name in node_names_to_unload:
			node_names_to_unload.append(n_name)

	# Delete extracted nodes in bulk.
	for n_name in node_names_to_unload:
		_unload_node(n_name)


# ------------- [Public Method] -------------
## Sets the history stack capacity (number of times you can go back).
## @param input Allowed number of history entries (0 to disable).
func set_back_limit(input: int) -> void:
	input = maxi(input, 0)
	_history_stack.set_capacity(input)


## Clears the entire history stack.
func clear_history() -> void:
	_history_stack.clear()


## Blocking generation of an instance from a scene ID.
## @param scene Scene ID.
## @return Generated node.
func create_scene_instance_blocking(scene: Scenes.Id) -> Node:
	var pack := get_scene_blocking(scene)
	if pack:
		return pack.instantiate()
	return null


## Blocking load of a PackedScene from a scene ID.
## @param scene Scene ID.
## @return Loaded PackedScene.
func get_scene_blocking(scene: Scenes.Id) -> PackedScene:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to get PackedScene for a NONE scene. Skipping.")
		return null

	var address := _scene_db.get_scene_path_from_enum(scene)
	assert(not address.is_empty())
	return load(address)


## Switches to a specified scene (replaces the existing scene by default).
## @param scene Target scene ID.
## @param load_options Loading configuration options.
func switch_to_scene(scene: Scenes.Id, load_options := SceneLoadOptions.new()) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to get PackedScene for a NONE scene. Skipping.")
		return

	# Start fade-out.
	_set_transition_started()
	_set_clickable(load_options.clickable)
	await _execute_fade_async(load_options.fade_out_time, true)

	# Load new scene.
	var new_scene_node: Node = create_scene_instance_blocking(scene)
	var parent_node: Node = _attach_scene_to_tree(new_scene_node, load_options)
	# Track the relationship between the loaded scene ID and its parent node.
	_loaded_scene_map[scene] = _SceneEntry.new(parent_node, new_scene_node)
	_current_scene_enum = scene
	scene_loaded.emit()

	# Start fade-in.
	await _execute_fade_async(load_options.fade_in_time, false)
	_set_clickable(true)
	_set_transition_finished()


## Goes back to the previous scene from history.
## @return True if the transition started successfully.
func load_previous_scene() -> bool:
	var target_scene: Scenes.Id = _pop_history()
	if target_scene != Scenes.Id.NONE and _current_scene_enum != Scenes.Id.NONE:
		# Use the same parent node the scene currently has to keep it consistent.
		var load_options := SceneLoadOptions.new()
		load_options.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
		load_options.add_to_back = false
		switch_to_scene(target_scene, load_options)
		return true
	return false


## Reloads the current scene.
## @return True if executed.
func reload_current_scene() -> bool:
	# Use the same parent node the scene currently has to keep it consistent.
	if _current_scene_enum == Scenes.Id.NONE:
		push_warning("Attempted to reload current scene, but current scene is NONE.")
		return false

	var load_options := SceneLoadOptions.new()
	load_options.node_name = _loaded_scene_map[_current_scene_enum].container_node.name
	load_options.add_to_back = false
	switch_to_scene(_current_scene_enum, load_options)
	return true


## Quits the game after a fade-out effect.
## @param fade_time Duration of the fade-out (seconds).
func exit_game(fade_time: float = 1.0) -> void:
	# Set transition flag to block input.
	_set_transition_started()
	_set_clickable(false)

	# Execute and wait for fade-out.
	await _execute_fade_async(fade_time, true)

	# Exit.
	get_tree().quit(0)


## Instantiates the loaded scene into the tree (initially hidden).
## Should be called after load_finished following a preload_scene_async call.
func instantiate_async_result() -> void:
	if _loading_scene_path != "":
		var scene_resource := ResourceLoader.load_threaded_get(_loading_scene_path) as PackedScene
		if scene_resource:
			var scene_node := scene_resource.instantiate()
			scene_node.scene_file_path = _loading_scene_path

			var temp_options := _reserved_options.copy()
			if temp_options.mode == _C.SceneLoadingMode.SINGLE:
				temp_options.mode = _C.SceneLoadingMode.SINGLE_NODE
			var parent_node: Node = _attach_scene_to_tree(scene_node, temp_options)

			# Ensure the parent_node is not the last node to keep the transition scene on top.
			var root := get_tree().get_root()
			root.move_child(parent_node, root.get_child_count() - 2)

			_loading_scene_path = ""
			_load_scene_id = Scenes.Id.NONE

			_loaded_scene_map[_reserved_scene_id] = _SceneEntry.new(parent_node, scene_node)


## When you added the loaded scene to the scene tree by `instantiate_async_result`
## function, you call this function after you are sure that the added scene to scene tree
## is completely ready and functional to change the active scene.[br]
## This is used in the `load_scene_with_transition` flow and uses the reserved information for
## switching scenes.
func activate_prepared_scene() -> void:
	_set_transition_started()
	_set_clickable(_reserved_options.clickable)

	await _execute_fade_async(_reserved_options.fade_out_time, true)

	# Unload the transition/loading scene, which should be at the end.
	_unload_node(_C.DEFAULT_LOADING_NODE_NAME)

	# If the original load options was SINGLE loading mode, then also remove any other
	# node that isn't part of the load option node name.
	if _reserved_options.mode == _C.SceneLoadingMode.SINGLE:
		var remove_nodes := {}
		for scene in _loaded_scene_map:
			if (
				_loaded_scene_map[scene].container_node.name != _reserved_options.node_name
				and not remove_nodes.has(_loaded_scene_map[scene].container_node)
			):
				remove_nodes[_loaded_scene_map[scene].container_node] = null

		# Go through each parent node and unload them.
		for node in remove_nodes:
			_unload_node(node.name)

	# Get the reserved scene to switch to from the loaded scene map.
	_current_scene_enum = _reserved_scene_id

	await _execute_fade_async(_reserved_options.fade_in_time, false)

	_set_clickable(true)
	_set_transition_finished()

	# Reset the reserved scene information now that the scene has fully loaded.
	_reserved_scene_id = Scenes.Id.NONE
	_reserved_options = null


## Starts interactive (asynchronous) scene loading.
## @param scene Target scene ID.
## @param use_sub_threads Whether to use sub-threads.
func preload_scene_async(scene: Scenes.Id, use_sub_threads = false) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to preload_scene_async a NONE scene. Skipping.")
		return

	set_process(true)
	_loading_scene_path = _scene_db.get_scene_path_from_enum(scene)
	_load_scene_id = scene
	ResourceLoader.load_threaded_request(
		_loading_scene_path, "", use_sub_threads, ResourceLoader.CACHE_MODE_REUSE
	)


## Executes scene transition via a loading/transition scene.
## @param next_scene Final destination scene ID.
## @param transition_scene Scene to display during loading.
## @param load_options Load options for the final scene.
func load_scene_with_transition(
	next_scene: Scenes.Id, transition_scene: Scenes.Id, load_options := SceneLoadOptions.new()
) -> void:
	_reserve_next_scene(next_scene, load_options)

	# The transition scene will be on its own node on top of everything else.
	load_options.node_name = _C.DEFAULT_LOADING_NODE_NAME
	load_options.mode = _C.SceneLoadingMode.ADDITIVE
	load_options.add_to_back = false
	switch_to_scene(transition_scene, load_options)


## Pre-reserves the next scene and its options.
## @param scene ID of the scene to reserve.
## @param load_options Load options to apply.
func _reserve_next_scene(scene: Scenes.Id, load_options := SceneLoadOptions.new()) -> void:
	if scene == Scenes.Id.NONE:
		push_warning("Attempted to reserve a NONE scene. Skipping.")
		return

	_reserved_scene_id = scene
	# Store a copy of the options so external changes don't affect the reservation.
	_reserved_options = load_options.copy()
