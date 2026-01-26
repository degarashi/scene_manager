extends Node
## Main SceneManager that handles adding scenes and transitions.

const C = preload("./scene_manager_constants.gd")
const FADE: String = "fade"
# Index to the loaded scene map for the parent node
const _IDX_WRAPPER_NODE: int = 0
# Index to the loaded scene map for the scene node
const _IDX_SCENE_NODE: int = 1

# Built in fade in/out for scene loading
@onready var _fade_color_rect: ColorRect = %fade
@onready var _animation_player: AnimationPlayer = %animation_player
@onready var _in_transition: bool = false
@onready var _back_buffer: RingBuffer = RingBuffer.new()
@onready var _current_scene_name: Scenes.SceneName = Scenes.SceneName.NONE

## Scene path that is currently loading
var _loading_scene_path: String = ""
## Scene Enum of the scene that's currently loading
var _load_scene_enum: Scenes.SceneName = Scenes.SceneName.NONE
var _load_status_buffer: Array = []
var _reserved_scene: Scenes.SceneName = Scenes.SceneName.NONE
var _reserved_load_options: SceneLoadOptions
## Keeps track of all loaded scenes (SceneName key)
##   and the node they belong to in an array (parent node: Node, scene node: Node)
var _loaded_scene_map: Dictionary = {}
var _scene_db: SceneManagerData = SceneManagerData.new()

signal load_finished
signal load_percent_changed(value: int)
signal scene_loaded
signal fade_in_started
signal fade_out_started
signal fade_in_finished
signal fade_out_finished


func _ready() -> void:
	set_process(false)

	_scene_db.load()
	var scene_file_path_a: String = get_tree().current_scene.scene_file_path
	_current_scene_name = _get_scene_key_by_path(scene_file_path_a)

	call_deferred("_on_initial_setup")


# Used for interactive change scene
func _check_loading_progress() -> void:
	var prev_percent: int = 0
	if len(_load_status_buffer) != 0:
		prev_percent = int(_load_status_buffer[0] * 100)

	var status := ResourceLoader.load_threaded_get_status(_loading_scene_path, _load_status_buffer)
	var next_percent: int = int(_load_status_buffer[0] * 100)
	if prev_percent != next_percent:
		load_percent_changed.emit(next_percent)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		_load_status_buffer = []
		load_finished.emit()
	elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		pass
	else:
		assert(false, "Scene Manager Error: for some reason, loading failed.")


func _process(_delta: float) -> void:
	_check_loading_progress()


func _current_scene_is_included(scene_file_path: String) -> bool:
	for include_path: String in Scenes.scenes._include_list:
		if scene_file_path.begins_with(include_path):
			return true
	return false


# For the initial setup,
# move the current scene to the default parent node and store it in the mapping.
func _on_initial_setup() -> void:
	var scene_node := get_tree().current_scene
	var root := get_tree().root

	var default_node := Node.new()
	default_node.name = C.DEFAULT_TREE_NODE_NAME

	root.remove_child(scene_node)
	default_node.add_child(scene_node)
	root.add_child(default_node)

	# Don't map a NONE scene as that shouldn't be here. It's possible to reach here
	# if the loaded scene wasn't part of the enums and loaded some other way.
	if _current_scene_name != Scenes.SceneName.NONE:
		_loaded_scene_map[_current_scene_name] = [default_node, scene_node]
	else:
		push_warning("Loaded scene not added to the mapping due to being NONE.")


# `speed` unit is in seconds
func _fade_in(speed: float) -> bool:
	if speed <= 0:
		return false

	fade_in_started.emit()
	_animation_player.play(FADE, -1, -1 / speed, true)
	return true


# `speed` unit is in seconds
func _fade_out(speed: float) -> bool:
	if speed <= 0:
		return false

	fade_out_started.emit()
	_animation_player.play(FADE, -1, 1 / speed, false)
	return true


# Activates `in_transition` mode
func _set_in_transition() -> void:
	_in_transition = true


# Deactivates `in_transition` mode
func _set_out_transition() -> void:
	_in_transition = false


# Adds current scene to `_back_buffer`
func _append_stack(key: Scenes.SceneName) -> void:
	_back_buffer.push(key)


# Pops most recent added scene from `_back_buffer`
func _pop_stack() -> Scenes.SceneName:
	var pop := _back_buffer.pop()
	if pop:
		return pop
	return Scenes.SceneName.NONE


# Returns the scene key of the passed scene value (scene address)
func _get_scene_key_by_path(path: String) -> Scenes.SceneName:
	for key in _scene_db.scenes:
		if _scene_db.scenes[key]["value"] == path:
			# Convert the string into an enum
			return SceneManagerUtils.get_enum_from_string(key)

	return Scenes.SceneName.NONE


# Returns the raw dictionary values for the scene
func _get_scene_value(scene: Scenes.SceneName) -> String:
	# The enums are normalized to have all caps, but the keys in the scenes may not have that,
	# do a string comparison with everything normalized.
	var scene_name: String = SceneManagerUtils.get_string_from_enum(scene)
	for key in _scene_db.scenes:
		if scene_name == SceneManagerUtils.normalize_enum_string(key):
			return _scene_db.scenes[key]["value"]

	return ""


# Restart the currently loaded scene
func _reload_current_scene() -> bool:
	# Use the same parent node the scene currently has to keep it consistent.
	var load_options := SceneLoadOptions.new()
	load_options.node_name = _loaded_scene_map[_current_scene_name][_IDX_WRAPPER_NODE].name
	load_options.add_to_back = false
	load_scene(_current_scene_name, load_options)
	return true


# Makes menu clickable or unclickable during transitions
func _set_clickable(clickable: bool) -> void:
	if clickable:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		_fade_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP


## Limits how deep the scene manager is allowed to reserved previous scenes which
## affects in changing scene to `back`(previous scene) functionality.[br]
##
## allowed `input` values:[br]
## input =  0 => we can not go back to any previous scenes[br]
## input >  0 => we can go back to `input` or less previous scenes[br]
func set_back_limit(input: int) -> void:
	input = maxi(input, 0)
	_back_buffer.set_capacity(input)


## Clears the `_back_buffer`.
func clear_back_buffer() -> void:
	_back_buffer.clear()


## Creates options for loading a scene.[br]
##
## add_to_back means that you can go back to the scene if you
## change scene to `back` scene
func create_load_options(
	node: String = C.DEFAULT_TREE_NODE_NAME,
	mode: C.SceneLoadingMode = C.SceneLoadingMode.SINGLE,
	clickable: bool = true,
	fade_out_time: float = ProjectSettings.get_setting(
		C.SETTINGS_FADE_OUT_PROPERTY_NAME, C.DEFAULT_FADE_OUT_TIME
	),
	fade_in_time: float = ProjectSettings.get_setting(
		C.SETTINGS_FADE_IN_PROPERTY_NAME, C.DEFAULT_FADE_IN_TIME
	),
	add_to_back: bool = true
) -> SceneLoadOptions:
	var options: SceneLoadOptions = SceneLoadOptions.new()
	options.node_name = node
	options.mode = mode
	options.fade_out_time = fade_out_time
	options.fade_in_time = fade_in_time
	options.clickable = clickable
	options.add_to_back = add_to_back
	return options


## Returns scene instance of passed scene key (blocking).[br]
##
## Note: you can activate `use_sub_threads` but just know that In the newest
## versions of Godot there seems to be a bug that can cause a threadlock in
## the resource loader that will result in infinite loading of the scene
## without any error.[br]
##
## Related Github Issues About `use_sub_threads`:[br]
##
## https://github.com/godotengine/godot/issues/85255[br]
## https://github.com/godotengine/godot/issues/84012
func create_scene_instance(key: Scenes.SceneName, use_sub_threads = false) -> Node:
	return get_scene(key, use_sub_threads).instantiate()


## Returns PackedScene of passed scene key (blocking).[br]
##
## Note: you can activate `use_sub_threads` but just know that In the newest
## versions of Godot there seems to be a bug that can cause a threadlock in
## the resource loader that will result in infinite loading of the scene
## without any error.[br]
##
## Related Github Issues About `use_sub_threads`:[br]
##
## https://github.com/godotengine/godot/issues/85255[br]
## https://github.com/godotengine/godot/issues/84012
func get_scene(key: Scenes.SceneName, use_sub_threads = false) -> PackedScene:
	var address = _scene_db.scenes[key]["value"]
	ResourceLoader.load_threaded_request(
		address, "", use_sub_threads, ResourceLoader.CACHE_MODE_REUSE
	)
	return ResourceLoader.load_threaded_get(address)


## Loads a specified scene to the tree.[br]
## By default it will swap the scene with the one already loaded in the default tree node.
func load_scene(
	scene: Scenes.SceneName, load_options: SceneLoadOptions = create_load_options()
) -> void:
	if scene == Scenes.SceneName.NONE:
		push_warning("Attempted to load a NONE scene. Skipping load as it won't work.")
		return

	_set_in_transition()
	_set_clickable(load_options.clickable)

	if _fade_out(load_options.fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()

	var new_scene_node: Node = _load_scene_node_from_path(_get_scene_value(scene))
	var parent_node: Node = _add_scene_node(new_scene_node, load_options)

	# Keep track of the loaded scene enum to the node it's a child of.
	_loaded_scene_map[scene] = [parent_node, new_scene_node]
	_current_scene_name = scene
	scene_loaded.emit()

	if _fade_in(load_options.fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_clickable(true)
	_set_out_transition()


## Unloads the scene from the tree.
func unload_scene(scene: Scenes.SceneName) -> void:
	# Get the node from the map, free it, and cleans up the map
	if not _loaded_scene_map.has(scene):
		assert(
			(
				"ERROR: Attempting to remove a scene %s that has not been loaded."
				% SceneManagerUtils.get_string_from_enum(scene)
			)
		)

	_loaded_scene_map[scene][_IDX_SCENE_NODE].free()
	_loaded_scene_map.erase(scene)


## Adds the specified node to the scene based on the load_options.[br]
## Returns the parent_node the node is under.
func _add_scene_node(node: Node, load_options: SceneLoadOptions = create_load_options()) -> Node:
	var root := get_tree().get_root()

	# If doing single scene loading, delete the specified node and load
	# the scene into the default node.
	var parent_node: Node = null
	if (
		load_options.mode == C.SceneLoadingMode.SINGLE
		or load_options.mode == C.SceneLoadingMode.SINGLE_NODE
	):
		# For the Single case, remove all nodes. For the Single Node case, only remove the specified
		# node in the options.
		if load_options.mode == C.SceneLoadingMode.SINGLE:
			_unload_all_nodes()
		else:
			# If the node currently exists, completely remove it and recreate a blank node after
			if root.has_node(load_options.node_name):
				_unload_node(load_options.node_name)

		parent_node = Node.new()
		parent_node.name = load_options.node_name
		root.add_child(parent_node)
		parent_node.add_child(node)

		# Note we add the current scene to back buffer and not the new scene coming in
		# as we want the old scene to revert to if needed.
		if load_options.add_to_back:
			_append_stack(_current_scene_name)
	else:
		# For additive, add the node if it doesn't exist then load the scene into that node.
		if not root.has_node(load_options.node_name):
			parent_node = Node.new()
			parent_node.name = load_options.node_name
			root.add_child(parent_node)
		else:
			parent_node = root.get_node(load_options.node_name)

		assert(
			parent_node,
			(
				"ERROR: Could not get the node %s to use for the additive scene."
				% load_options.node_name
			)
		)

		parent_node.add_child(node)

	return parent_node


## Frees the node and all children node underneath
##   while removing the scenes in the map assocaited with them.[br]
## Mainly used when removing the parent node, which will cause all the scenes to be removed.
func _unload_node(node_name: String) -> void:
	if not get_tree().root.has_node(node_name):
		assert("ERROR: Attempting to remove the parent node %s that doesn't exist." % node_name)

	# Using the node name, find all the scenes that are loaded under it and free them before
	# removing the parent node itself.
	for key in _loaded_scene_map.keys():
		if _loaded_scene_map[key][_IDX_WRAPPER_NODE].name == node_name:
			_loaded_scene_map[key][_IDX_SCENE_NODE].free()
			_loaded_scene_map.erase(key)

	get_tree().root.get_node(node_name).free()


## Frees all scene related nodes in the loaded scene map.[br]
## Used mainly for Single scene loading which will unload all scenes.
func _unload_all_nodes() -> void:
	# Get a list of all unique parent nodes to remove
	# Using the dictionary keys as a set.
	var unique_nodes := {}
	for key in _loaded_scene_map:
		if not unique_nodes.has(_loaded_scene_map[key][_IDX_WRAPPER_NODE]):
			unique_nodes[_loaded_scene_map[key][_IDX_WRAPPER_NODE]] = null

	# Go through each parent node and unload them
	for node in unique_nodes:
		_unload_node(node.name)


## Loads a scene from the specified file path and returns the Node for it.[br]
## Returns null if the scene doesn't exist.
func _load_scene_node_from_path(path: String) -> Node:
	var result: Node = null
	if ResourceLoader.exists(path):
		var scene: PackedScene = ResourceLoader.load(path)
		if scene:
			result = scene.instantiate()
		if not result:
			printerr("ERROR: %s scene path can't load" % path)

	return result


## Changes the scene to the previous.[br]
## Note this assumes Single loading and will remove any additive scenes with default options.
func load_previous_scene() -> bool:
	var pop: Scenes.SceneName = _pop_stack()
	if pop != Scenes.SceneName.NONE and _current_scene_name != Scenes.SceneName.NONE:
		# Use the same parent node the scene currently has to keep it consistent.
		var load_options := SceneLoadOptions.new()
		load_options.node_name = _loaded_scene_map[_current_scene_name][_IDX_WRAPPER_NODE].name
		load_options.add_to_back = false
		load_scene(pop, load_options)
		return true
	return false


## Reload the currently loaded scene.
func reload_current_scene() -> void:
	_reload_current_scene()


# Exits the game completely.
func exit_game() -> void:
	get_tree().quit(0)


## Imports loaded scene into the scene tree but doesn't change the scene.
## Mainly used when your new loaded scene has a loading phase when added to scene tree
## so to use this, first has to call `load_scene_interactive` to load your scene
## and then have to listen on `load_finished` signal. After the signal emits,
## you call this function and this function adds the loaded scene to the scene
## tree but exactly behind the current scene so that you still can not see the new scene.[br]
## This uses the reserved load options that was saved when loading the scene with
## an transition/loading scene except it loads as a SINGLE_NODE if SINGLE is specified
## in order not to conflict with unloading the transition scene.
func instantiate_loaded_scene() -> void:
	if _loading_scene_path != "":
		var scene_resource := ResourceLoader.load_threaded_get(_loading_scene_path) as PackedScene
		if scene_resource:
			var scene_node := scene_resource.instantiate()
			scene_node.scene_file_path = _loading_scene_path

			var temp_options := _reserved_load_options.copy()
			if temp_options.mode == C.SceneLoadingMode.SINGLE:
				temp_options.mode = C.SceneLoadingMode.SINGLE_NODE
			var parent_node: Node = _add_scene_node(scene_node, temp_options)

			# Make sure the parent_node is not the last node in order to make sure
			# the transition scene is on top.
			var root := get_tree().get_root()
			root.move_child(parent_node, root.get_child_count() - 2)

			_loading_scene_path = ""
			_load_scene_enum = Scenes.SceneName.NONE

			# Keep track of the loaded scene enum to the node it's a child of.
			_loaded_scene_map[_reserved_scene] = [parent_node, scene_node]


## When you added the loaded scene to the scene tree by `instantiate_loaded_scene`
## function, you call this function after you are sure that the added scene to scene tree
## is completely ready and functional to change the active scene.[br]
## This is used in the `load_scene_with_transition` flow and uses the reserved information for
## switching scenes.
func activate_loaded_scene() -> void:
	_set_in_transition()
	_set_clickable(_reserved_load_options.clickable)

	if _fade_out(_reserved_load_options.fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()

	# Unload the transition/loading scene, which should be at the end
	_unload_node(C.DEFAULT_LOADING_NODE_NAME)

	# If the original load options was SINGLE loading mode, then also remove any other
	# node that isn't part of the load option node name.
	if _reserved_load_options.mode == C.SceneLoadingMode.SINGLE:
		var remove_nodes := {}
		for key in _loaded_scene_map:
			if (
				_loaded_scene_map[key][_IDX_WRAPPER_NODE].name != _reserved_load_options.node_name
				and not remove_nodes.has(_loaded_scene_map[key][_IDX_WRAPPER_NODE])
			):
				remove_nodes[_loaded_scene_map[key][_IDX_WRAPPER_NODE]] = null

		# Go through each parent node and unload them
		for node in remove_nodes:
			_unload_node(node.name)

	# Get the reserved scene to switch to from the loaded scene map
	#get_tree().set_current_scene(_loaded_scene_map[_reserved_scene][_IDX_SCENE_NODE])
	_current_scene_name = _reserved_scene

	if _fade_in(_reserved_load_options.fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_clickable(true)
	_set_out_transition()

	# Reset the reserved scene information now that the scene has fully loaded and is
	# the active scene.
	_reserved_scene = Scenes.SceneName.NONE
	_reserved_load_options = null


## Loads scene interactive[br]
##
## Connect to `load_percent_changed(value: int)` and `load_finished` signals
## to listen to updates on your scene loading status.[br]
##
## Note: You can activate `use_sub_threads` but just know that in the newest
## versions of Godot there seems to be a bug that can cause a threadlock in
## the resource loader that will result in infinite loading of the scene
## without any error.[br]
##
## Related Github Issues About `use_sub_threads`:[br]
##
## https://github.com/godotengine/godot/issues/85255[br]
## https://github.com/godotengine/godot/issues/84012
func load_scene_interactive(key: Scenes.SceneName, use_sub_threads = false) -> void:
	set_process(true)
	_loading_scene_path = _get_scene_value(key)
	_load_scene_enum = key
	ResourceLoader.load_threaded_request(
		_loading_scene_path, "", use_sub_threads, ResourceLoader.CACHE_MODE_IGNORE
	)


## Loads a scene with a loading/transition scene.[br]
##
## This sets the reserved scene to the specified next_scene and loads the transition_scene.
## The transition_scene is the loading scene that should subscribe to the `load_finished` signal
func load_scene_with_transition(
	next_scene: Scenes.SceneName,
	transition_scene: Scenes.SceneName,
	load_options: SceneLoadOptions = create_load_options()
) -> void:
	reserve_next_scene(next_scene, load_options)

	# The load scene will be on it's own node that will be on top of everything else
	load_options.node_name = C.DEFAULT_LOADING_NODE_NAME
	load_options.mode = C.SceneLoadingMode.ADDITIVE
	load_options.add_to_back = false
	load_scene(transition_scene, load_options)


## Returns the loaded scene.[br]
##
## If scene is not loaded, blocks and waits until scene is ready (acts blocking in code
## and may freeze your game, make sure scene is ready to get).
func get_loaded_scene() -> PackedScene:
	if _loading_scene_path != "":
		return ResourceLoader.load_threaded_get(_loading_scene_path) as PackedScene
	return null


## Pops from the back stack and returns previous scene (scene before current scene)
func pop_previous_scene() -> Scenes.SceneName:
	return _pop_stack()


## Returns how many scenes there are in list of previous scenes.
func get_history_count() -> int:
	return _back_buffer.size()


## Reserves a scene key to be used for loading scenes to know where to go after getting loaded
## into loading scene or just for next scene to know where to go next.
func reserve_next_scene(
	key: Scenes.SceneName, load_options: SceneLoadOptions = create_load_options()
) -> void:
	_reserved_scene = key
	# Make sure to make a copy of the load options so it doesn't get affected by changes outside.
	_reserved_load_options = load_options.copy()


## Returns the reserved scene.
func get_reserved_scene() -> Scenes.SceneName:
	return _reserved_scene


## Returns the reserved load options for the reserved scene.
func get_reserved_load_option() -> SceneLoadOptions:
	return _reserved_load_options


## Pause (fadeout). You can resume afterwards.
func pause(fade_out_time: float, general_options: SceneLoadOptions = create_load_options()) -> void:
	_set_in_transition()
	_set_clickable(general_options.clickable)

	if _fade_out(fade_out_time):
		await _animation_player.animation_finished
		fade_out_finished.emit()


## Resume (fadein) after pause
func resume(fade_in_time: float, general_options: SceneLoadOptions = create_load_options()) -> void:
	_set_clickable(general_options.clickable)

	if _fade_in(fade_in_time):
		await _animation_player.animation_finished
		fade_in_finished.emit()

	_set_out_transition()
	_set_clickable(true)
