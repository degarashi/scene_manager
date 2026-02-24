## Root layer of each scene managed by scene manager
class_name SMgrSceneLayer
extends CanvasLayer

signal layer_disposed(id: Scenes.Id)

var scene_id: Scenes.Id = Scenes.Id.NONE
var content_node: Node = null


func prepare(p_scene_id: Scenes.Id, p_name: String) -> void:
	self.scene_id = p_scene_id
	self.name = p_name
	# Connect to the signal that monitors the addition/removal of child nodes
	child_order_changed.connect(_on_child_order_changed)


## Set up scene nodes for content
func setup_content(p_node: Node) -> void:
	content_node = p_node
	if content_node.get_parent():
		content_node.reparent(self)
	else:
		add_child(content_node)


func _on_child_order_changed() -> void:
	# If the number of child nodes (content) becomes zero, self-destruct
	if get_child_count() == 0:
		layer_disposed.emit(scene_id)
		queue_free()
