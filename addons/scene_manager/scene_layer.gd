## Root layer of each scene managed by scene manager
class_name SMgrSceneLayer
extends CanvasLayer

signal layer_disposed(id: Scenes.Id)

var scene_id: Scenes.Id = Scenes.Id.NONE


func prepare(p_scene_id: Scenes.Id, p_name: String, p_priority: int) -> void:
	scene_id = p_scene_id
	name = p_name
	layer = p_priority

	# Connect to the signal that monitors the addition/removal of child nodes
	child_order_changed.connect(_on_child_order_changed)


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
