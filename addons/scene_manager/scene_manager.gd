class_name SMgrInstance
extends Node
## Main SceneManager that handles adding and transitioning between scenes.

# ------------- [Signal] -------------
## Emitted when loading progress (0-100) changes.
signal load_percent_changed(value: int)
signal load_finished
signal load_failed

## Emitted when scene instantiation is completed.
signal scene_loaded(scene_id: Scenes.Id, node: Node)
## Emitted when the entire transition (including visual effects) is finished.
signal scene_transition_completed(scene_id: Scenes.Id)
signal on_game_end

signal category_changed(diff: SMgrData.CategoryDiff)
## Emitted when a scene is reloaded
signal category_reapplied(tags: Array[Scenes.CategoryId])
## Emitted to notify added or current categories depending on the transition type.
signal category_tags_notified(tags: Array[Scenes.CategoryId])

# ------------- [Constants] -------------
const _C = preload("uid://c3vvdktou45u")
const _RING_BUFFER = preload("uid://b6phac21mxnxr")
const _RESOURCE_LOADER = preload("uid://dabq3s83q0iku")
const _AF = preload("uid://dlgh4u64a7qxk")
const _PS := preload("uid://dn6eh4s0h8jhi")

# ------------- [Defines] -------------
## Defines how to handle cases where a SceneLayer name already exists.
enum DuplicateNameMode {
	REMOVE_OLD,  ## Remove the existing SceneLayer before adding the new one.
	WARN_AND_SKIP,  ## Print a warning and abort the addition.
	RENAME_NEW,  ## Append a numeric suffix to the new SceneLayer to avoid collision.
	APPEND,  ## Add the new scene to the existing SceneLayer.
}

# ------------- [Static Variable] -------------
static var _log := DLoggerClass.new("Scene Manager")

# ------------- [Exports] -------------
@export_group("General Settings")
@export var _loading_node_name: String = "===Transition==="
@export var _initial_play_in_time: float = 1.0
@export var _actual_scene_container_path: NodePath = "/root"
@export var _wrap_initial_scene := true
@export var _transitioner_source: PackedScene = preload("uid://2iy8wfgenjka")
@export_group("EBus")
@export var _ebus: SMgrEbusRuntime

# ------------- [Private Variable] -------------
var _scene_db: SMgrData
## ID of the scene currently being loaded.
var _load_scene_id: Scenes.Id = Scenes.Id.NONE

## Reservation info for asynchronous loading.
var _reserved := SMgrReservedInfo.new()

## Scenes currently present (Key: Scene-Id, Value: SMgrSceneLayer).
var _current_scene_enum: Scenes.Id = Scenes.Id.NONE
var _trash_can: SMgrTrashCan

@onready var _history_stack := _RING_BUFFER.new()

## ResourceLoaderMgr instance
@onready var _loader_mgr: _RESOURCE_LOADER

## Layer management helper
var _layer_mgr: SMgrLayerManager

## Transition management service
var _transition_service: SMgrTransitionService


# ------------- [Callbacks] -------------
func _ready() -> void:
	if _ebus:
		if not _ebus._instance_check.get_connections().is_empty():
			_log.error("Multiple SceneManager instances detected. This may cause unexpected behavior.")
		_ebus._instance_check.connect(_instance_dummy)

	_init_resource_loader()
	_init_trash_node()

	# SMgrData is a Resource, so read it with the loader
	_scene_db = load(_PS.scene_data_path)
	assert(_scene_db != null, "Scene Manager: Failed to load scene database resource.")

	_layer_mgr = SMgrLayerManager.new(_scene_db, _ebus, _log)
	_transition_service = SMgrTransitionService.new(_scene_db, _log, _transitioner_source)
	add_child(_transition_service)

	_on_initial_setup.call_deferred()


# ------------- [Private Method] -------------
func _init_resource_loader() -> void:
	_loader_mgr = _RESOURCE_LOADER.new()
	_loader_mgr.name = "ResourceLoader"
	_loader_mgr.progress_changed.connect(_on_loader_progress_changed)
	add_child(_loader_mgr)


func _init_trash_node() -> void:
	_trash_can = SMgrTrashCan.new()
	add_child(_trash_can)


func _instance_dummy() -> void:
	pass


func _on_loader_progress_changed(_path: String, percent: int) -> void:
	# If the progress is for our currently loading scene, emit signal
	var loading_path := _scene_db.get_scene_path_from_enum(_load_scene_id)
	if _path == loading_path:
		load_percent_changed.emit(percent)


func _get_actual_scene_container() -> Node:
	var target_node := get_node_or_null(_actual_scene_container_path)
	if target_node:
		return target_node
	_log.warn(
		"_actual_scene_container_path '%s' is invalid. Falling back to root node.",
		[_actual_scene_container_path]
	)
	return get_tree().root


func _on_initial_setup() -> void:
	var initial_node: Node = null
	if _wrap_initial_scene:
		var scene_node := get_tree().current_scene
		if scene_node == null:
			_log.warn("Scene Manager: current_scene is null during initial setup. Skipping wrap.")
			return

		initial_node = scene_node

		# Find Scenes.Id enum by current scene's path
		var current_path := scene_node.scene_file_path
		_current_scene_enum = _scene_db.get_scene_enum_by_path(current_path)

		_log.info(
			"Initial setup: wrapping current scene '{0}' (ID: {1})",
			[current_path, Scenes.Id.find_key(_current_scene_enum)]
		)

		# Force using DEFAULT_TREE_NODE_NAME by passing it as override_name
		var layer := _layer_mgr.create_scene_layer(
			_current_scene_enum, "", _C.DEFAULT_TREE_NODE_NAME
		)
		_get_actual_scene_container().add_child(layer)
		layer.add_node(scene_node)
		if _current_scene_enum == Scenes.Id.NONE:
			_log.warn("Initial scene not found in DB (Scenes.Id.NONE).")

	# Initial fade-in effect
	var player := _transition_service.get_main_player()
	player.set_clickable(false)
	await player.play_in(_initial_play_in_time)

	if initial_node:
		_notify_fade_in(initial_node)

	player.set_clickable(true)
	scene_transition_completed.emit(_current_scene_enum)


func _remove_node_safely(target_node: Node) -> void:
	assert(target_node != null, "Scene Manager: target_node to remove is null.")
	_trash_can.collect(target_node)


func _remove_name_node(sc: SMgrSceneLayer, p_name: String) -> void:
	if sc.name == p_name:
		_remove_node_safely(sc)


func _perform_scene_setup(scene_id: Scenes.Id, options: SceneLoadOptions) -> Node:
	var new_scene_node := _create_scene_instance_blocking(scene_id)
	if not new_scene_node:
		_log.error("Failed to instantiate scene: {0}", [Scenes.Id.find_key(scene_id)])
		return null

	_notify_scene_init(new_scene_node, options.params)

	# Create layer (node_name will be ignored if category has layer_name)
	var layer := _layer_mgr.create_scene_layer(scene_id, options.node_name)
	layer.add_node(new_scene_node)

	options.call_pre_cb(layer, new_scene_node)
	_get_actual_scene_container().add_child(layer)

	if options.scene_loaded_cb.is_valid():
		options.scene_loaded_cb.call(new_scene_node)

	scene_loaded.emit(scene_id, new_scene_node)
	return new_scene_node


func _get_layer_by_id(scene_id: Scenes.Id) -> SMgrSceneLayer:
	var recv: Array[SMgrSceneLayer] = []
	_ebus.get_scene_by_id.emit(recv, scene_id)
	return recv[0] if not recv.is_empty() else null


func _get_layer_by_name(node_name: String) -> SMgrSceneLayer:
	var recv: Array[SMgrSceneLayer] = []
	_ebus.get_scene_by_name.emit(recv, node_name)
	return recv[0] if not recv.is_empty() else null


# ------------- [Public Method] -------------
func get_history_list() -> Array[Scenes.Id]:
	return _history_stack.get_all_items()


func get_history_count() -> int:
	return _history_stack.size()


## Returns the root node of the currently active main scene.
func get_current_scene_node() -> Node:
	var layer := _get_layer_by_id(_current_scene_enum)
	return layer.get_main_node() if layer else null


## Unloads a SceneLayer matching the specified node name.
func unload_scene_by_name(node_name: String) -> void:
	if node_name.is_empty():
		_log.warn("unload_scene_by_name called with empty name.")
		return

	# Leverages existing logic to safely move the node to the trash can
	_ebus.process_scene_layer.emit(_remove_name_node.bind(node_name))


## Discards the current main scene and switches to a new one. (Main Routine)
func switch_to_scene(
	scene_id: Scenes.Id,
	add_to_back: bool,
	options := SceneLoadOptions.new(),
	scene_loaded_cb: Callable = Callable()
) -> Node:
	if scene_id == Scenes.Id.NONE:
		_log.warn("switch_to_scene called with NONE.")
		return null

	if scene_loaded_cb.is_valid():
		options.scene_loaded_cb = scene_loaded_cb

	# Even if reloading the same scene, the instance is recreated.
	# We preserve the existing layer name and re-notify categories to maintain consistency.
	var is_reloading := scene_id == _current_scene_enum

	_log.info(
		"Switching to scene: {0} (is_reloading: {1})", [Scenes.Id.find_key(scene_id), is_reloading]
	)

	if is_reloading:
		var layer := _get_layer_by_id(scene_id)
		if layer:
			# Force the new instance to use the same node name as the current one.
			options.node_name = layer.name

	# --- Transition Start ---
	var player := _transition_service.setup_transition_player(options)
	_notify_fade_out_start()
	await player.play_out(options.play_out_time)

	_notify_fade_out_end()

	# Remove existing layers before setting up the new scene
	_ebus.process_scene_layer.emit(_remove_node_safely)

	# Update history stack (only for new scene transitions)
	if not is_reloading and add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	# Instantiate and setup the scene (this internally emits 'scene_loaded')
	var new_scene_node := _perform_scene_setup(scene_id, options)
	if not new_scene_node:
		_log.error("Failed to instantiate switch_to_scene: {0}", [Scenes.Id.find_key(scene_id)])
		player.set_clickable(true)
		if player != _transition_service.get_main_player():
			player.queue_free()
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

	await player.play_in(options.play_in_time)
	_notify_fade_in(new_scene_node)
	player.set_clickable(true)

	if player != _transition_service.get_main_player():
		player.queue_free()

	_log.debug("Scene transition completed: {0}", [Scenes.Id.find_key(scene_id)])
	scene_transition_completed.emit(scene_id)
	return new_scene_node


## Adds a scene while keeping the current scene. (Additive Routine)
func add_scene(
	scene_id: Scenes.Id,
	mode: DuplicateNameMode = DuplicateNameMode.WARN_AND_SKIP,
	options := SceneLoadOptions.new()
) -> Node:
	if scene_id == Scenes.Id.NONE:
		_log.warn("add_scene called with NONE.")
		return null

	_log.info("Adding scene: {0}", [Scenes.Id.find_key(scene_id)])

	var summary := _layer_mgr.get_category_summary(scene_id)
	var target_name := (
		summary.layer_name if not summary.layer_name.is_empty() else options.node_name
	)

	var existing_layer := _get_layer_by_name(target_name)
	if existing_layer:
		match mode:
			DuplicateNameMode.REMOVE_OLD:
				unload_scene_by_name(target_name)

			DuplicateNameMode.WARN_AND_SKIP:
				_log.warn("Scene with name '{0}' is already loaded. Skipping.", [target_name])
				return null

			DuplicateNameMode.RENAME_NEW:
				options.node_name = _layer_mgr.get_unique_layer_name(target_name)

			DuplicateNameMode.APPEND:
				# Instead of creating a new layer, append the instance to the existing layer
				var new_node := _create_scene_instance_blocking(scene_id)
				if new_node:
					existing_layer.add_node(new_node)
					# Apply pre-callback to the existing layer and new node
					options.call_pre_cb(existing_layer, new_node)

					if options.scene_loaded_cb.is_valid():
						options.scene_loaded_cb.call(new_node)

					# Manually emit since we bypass _perform_scene_setup
					scene_loaded.emit(scene_id, new_node)
				return new_node

	# For other modes (or if no duplicate was found), proceed with standard setup
	return _perform_scene_setup(scene_id, options)


func load_previous_scene(options := SceneLoadOptions.new()) -> bool:
	if _history_stack.size() == 0:
		_log.warn("Attempted to load previous scene, but history is empty.")
		return false

	back_to_previous_by_offset(1, options)
	return true


## Go back in history by the specified number (offset)
## from the current scene and transition to that scene.
func back_to_previous_by_offset(offset: int, options := SceneLoadOptions.new()) -> void:
	if offset <= 0:
		_log.warn("Offset must be greater than 0.")
		return

	var target_scene := Scenes.Id.NONE
	for i in range(offset):
		var popped := _history_stack.pop() as Scenes.Id
		if popped != Scenes.Id.NONE:
			target_scene = popped
		else:
			break

	if target_scene == Scenes.Id.NONE:
		_log.warn("Failed to go back, history is empty or offset out of bounds.")
		return

	switch_to_scene(target_scene, false, options)


## Reloads the current scene.
## @return True if executed.
func reload_current_scene(options := SceneLoadOptions.new()) -> bool:
	# Use the same parent node the scene currently has to keep it consistent.
	if _current_scene_enum == Scenes.Id.NONE:
		_log.warn("Attempted to reload current scene, but current scene is NONE.")
		return false

	# The reload logic is handled within switch_to_scene(), so simply calling it is sufficient.
	switch_to_scene(_current_scene_enum, false, options)
	return true


## Quits the game after a fade-out effect.
## @param fade_time Duration of the fade-out (seconds).
func exit_game(fade_time: float = 1.0) -> void:
	var player := _transition_service.get_main_player()
	player.set_clickable(false)
	await player.play_out(fade_time)
	on_game_end.emit()
	get_tree().quit(0)


# ------------- [Async Loading] -------------
func start_async_load(scene_id: Scenes.Id, use_sub_threads: bool = true) -> void:
	if scene_id == Scenes.Id.NONE:
		_log.warn("Start_async_load called with Scenes.Id.NONE.")
		return

	var path := _scene_db.get_scene_path_from_enum(scene_id)
	_load_scene_id = scene_id

	_loader_mgr.request(
		path,
		func(res: Resource):
			if res:
				load_finished.emit()
			else:
				load_failed.emit()
				_log.error("Async load failed for {0}", [path]),
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

	_log.info(
		"Loading scene with transition: {0} -> {1}",
		[Scenes.Id.find_key(transition_scene), Scenes.Id.find_key(next_scene)]
	)

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
		_log.warn("instantiate_async_result: No reserved scene to instantiate.")
		return

	# Add current scene to history before switching
	if _reserved.add_to_back and _current_scene_enum != Scenes.Id.NONE:
		_history_stack.push(_current_scene_enum)

	# Load the resource (should be cached by the ResourceLoaderMgr)
	var res := load(path) as PackedScene
	if res:
		var scene_node := res.instantiate()
		scene_node.scene_file_path = path

		_notify_scene_init(scene_node, _reserved.options.params)

		# Create the layer with a temporary unique name.
		# This prevents name collisions with the current active scene
		# while this new layer sits hidden in the background.
		var layer := _layer_mgr.create_scene_layer(
			_reserved.scene_id, "", _AF.to_tmp_name(_reserved.options.node_name)
		)

		# Keep the layer hidden until activate_prepared_scene() is called
		layer.visible = false
		layer.add_node(scene_node)

		_reserved.options.call_pre_cb(layer, scene_node)
		var target := _get_actual_scene_container()
		target.add_child(layer)

		if _reserved.options.scene_loaded_cb.is_valid():
			_reserved.options.scene_loaded_cb.call(scene_node)

		scene_loaded.emit(_reserved.scene_id, scene_node)


## Finalizes the transition by swapping the old scene with the pre-instantiated one.
## This is the final step of the 'load_scene_with_transition' flow.
func activate_prepared_scene() -> Node:
	if _reserved.scene_id == Scenes.Id.NONE:
		_log.warn("activate_prepared_scene called but no scene is reserved.")
		return null

	_log.info("Activating prepared scene: {0}", [Scenes.Id.find_key(_reserved.scene_id)])

	var recv: Array[SMgrSceneLayer]
	_ebus.get_scene_by_id.emit(recv, _reserved.scene_id)
	assert(not recv.is_empty(), "Scene Manager: Reserved scene entry missing.")
	var layer := recv[0]

	var player := _transition_service.setup_transition_player(_reserved.options)

	if not _reserved.is_additive:
		_notify_fade_out_start(_reserved.scene_id)

	await player.play_out(_reserved.options.play_out_time)

	var diff := _scene_db.compare_scene_categories(_current_scene_enum, _reserved.scene_id)

	# Remove the transition/loading scene layer
	unload_scene_by_name(_loading_node_name)

	if not _reserved.is_additive:
		_notify_fade_out_end(_reserved.scene_id)
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

	var node := layer.get_child(0)
	scene_loaded.emit(_current_scene_enum, node)

	# Show the new scene
	await player.play_in(_reserved.options.play_in_time)
	_notify_fade_in(node)

	_reserved.clear()
	player.set_clickable(true)

	if player != _transition_service.get_main_player():
		player.queue_free()

	_log.debug("Scene transition completed: {0}", [Scenes.Id.find_key(_current_scene_enum)])
	scene_transition_completed.emit(_current_scene_enum)

	return layer.get_child(0)


# ------------- [Utils] -------------
func _get_scene_blocking(scene_id: Scenes.Id) -> PackedScene:
	if scene_id == Scenes.Id.NONE:
		_log.warn("_get_scene_blocking called with Scenes.Id.NONE.")
		return null
	return load(_scene_db.get_scene_path_from_enum(scene_id))


func _create_scene_instance_blocking(scene_id: Scenes.Id) -> Node:
	var pack := _get_scene_blocking(scene_id)
	return pack.instantiate() if pack else null


func _notify_fade_out_start(exclude_id: Scenes.Id = Scenes.Id.NONE) -> void:
	_ebus.process_scene_layer.emit(
		func(layer: SMgrSceneLayer) -> void:
			if exclude_id != Scenes.Id.NONE and layer.scene_id == exclude_id:
				return
			for child in layer.get_children():
				Interface.proc_interface(
					child,
					IFadeOutNotify,
					func(ifc: IFadeOutNotify) -> void: ifc.on_fade_out_start()
				)
	)


func _notify_fade_out_end(exclude_id: Scenes.Id = Scenes.Id.NONE) -> void:
	_ebus.process_scene_layer.emit(
		func(layer: SMgrSceneLayer) -> void:
			if exclude_id != Scenes.Id.NONE and layer.scene_id == exclude_id:
				return
			for child in layer.get_children():
				Interface.proc_interface(
					child, IFadeOutNotify, func(ifc: IFadeOutNotify) -> void: ifc.on_fade_out_end()
				)
	)


func _notify_fade_in(node: Node) -> void:
	Interface.proc_interface(
		node, IFadeInNotify, func(ifc: IFadeInNotify) -> void: ifc.on_fade_in_end()
	)


func _notify_scene_init(node: Node, params: Variant) -> void:
	Interface.proc_interface(
		node, ISceneInitializer, func(ifc: ISceneInitializer) -> void: ifc.on_scene_init(params)
	)


## Returns the currently reserved scene Enum.
## @return Reserved scene Enum.
func get_reserved_scene() -> Scenes.Id:
	return _reserved.scene_id


## Returns the reserved load options for the reserved scene.
func get_reserved_load_option() -> SceneLoadOptions:
	return _reserved.options


func get_scene_data() -> SMgrData:
	return _scene_db
