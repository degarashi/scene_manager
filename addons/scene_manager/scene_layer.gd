## Root layer of each scene managed by scene manager
class_name SMgrSceneLayer
extends CanvasLayer

signal layer_disposed(id: Scenes.Id)

@export var _ebus: SMgrEbusRuntime
var scene_id: Scenes.Id = Scenes.Id.NONE
var pause_lower: bool = false
var l_priority: int = 1


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


func _get_scene_by_id(recv: Array[SMgrSceneLayer], q_id: int) -> void:
	if q_id == self.scene_id:
		recv.append(self)


func _get_scene_by_name(recv: Array[SMgrSceneLayer], q_name: String) -> void:
	if q_name == self.name:
		recv.append(self)


func _process_scene_layer(proc: Callable) -> void:
	proc.call(self)


func _pause_threshold_changed(priority: int) -> void:
	# In the current implementation, there are two options: INHERIT or DISABLED
	process_mode = (
		Node.PROCESS_MODE_DISABLED if self.layer < priority else Node.PROCESS_MODE_INHERIT
	)


## Set up scene nodes for content
func add_node(p_node: Node) -> void:
	if p_node.get_parent():
		p_node.reparent(self)
	else:
		add_child(p_node)


func _on_child_order_changed() -> void:
	# If the number of child nodes (content) becomes zero, self-destruct
	if get_child_count() == 0:
		layer_disposed.emit(scene_id)
		queue_free()
