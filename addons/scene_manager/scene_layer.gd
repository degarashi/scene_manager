## Root layer of each scene managed by scene manager
class_name SMgrSceneLayer
extends CanvasLayer

# ------------- [Signal] -------------
signal layer_disposed(id: Scenes.Id)

# ------------- [Exports] -------------
@export var _ebus: SMgrEbusRuntime

# ------------- [Public Variable] -------------
var scene_id: Scenes.Id = Scenes.Id.NONE
var pause_lower: bool = false
var l_priority: int = 1
var _main_node: Node


# ------------- [Callbacks] -------------
func _exit_tree() -> void:
	# Disconnect all signals to prevent memory leaks and dangling references
	if child_order_changed.is_connected(_on_child_order_changed):
		child_order_changed.disconnect(_on_child_order_changed)
	if _ebus and _ebus.pause_threshold_changed.is_connected(_pause_threshold_changed):
		_ebus.pause_threshold_changed.disconnect(_pause_threshold_changed)
	if _ebus and _ebus.get_scene_by_id.is_connected(_get_scene_by_id):
		_ebus.get_scene_by_id.disconnect(_get_scene_by_id)
	if _ebus and _ebus.get_scene_by_name.is_connected(_get_scene_by_name):
		_ebus.get_scene_by_name.disconnect(_get_scene_by_name)
	if _ebus and _ebus.process_scene_layer.is_connected(_process_scene_layer):
		_ebus.process_scene_layer.disconnect(_process_scene_layer)


func _on_child_order_changed() -> void:
	# If the number of child nodes (content) becomes zero, self-destruct
	if get_child_count() == 0:
		queue_free()
		layer_disposed.emit(scene_id)


# ------------- [Private Method] -------------
func _get_scene_by_id(recv: Array[SMgrSceneLayer], q_id: int) -> void:
	if not is_queued_for_deletion() and q_id == self.scene_id:
		recv.append(self)


func _get_scene_by_name(recv: Array[SMgrSceneLayer], q_name: String) -> void:
	if not is_queued_for_deletion() and q_name == self.name:
		recv.append(self)


func _process_scene_layer(proc: Callable) -> void:
	if not is_queued_for_deletion():
		proc.call(self)


func _pause_threshold_changed(priority: int) -> void:
	# In the current implementation, there are two options: INHERIT or DISABLED
	process_mode = (
		Node.PROCESS_MODE_DISABLED if self.layer < priority else Node.PROCESS_MODE_INHERIT
	)


# ------------- [Public Method] -------------
func prepare(
	p_scene_id: Scenes.Id, p_name: String, p_priority: int, p_pause_lower: bool, p_follow: bool
) -> void:
	scene_id = p_scene_id
	name = p_name
	layer = p_priority
	l_priority = p_priority
	pause_lower = p_pause_lower
	follow_viewport_enabled = p_follow

	# Connect to the signal that monitors the addition/removal of child nodes
	child_order_changed.connect(_on_child_order_changed)
	# Receive notification of the layer priority to be paused from SceneManager
	_ebus.pause_threshold_changed.connect(_pause_threshold_changed)
	_ebus.get_scene_by_id.connect(_get_scene_by_id)
	_ebus.get_scene_by_name.connect(_get_scene_by_name)
	_ebus.process_scene_layer.connect(_process_scene_layer)


## Returns the main node of this layer.
func get_main_node() -> Node:
	return _main_node


## Set up scene nodes for content


func add_node(p_node: Node) -> void:
	if p_node.get_parent():
		p_node.reparent(self)
	else:
		add_child(p_node)
	_main_node = p_node
