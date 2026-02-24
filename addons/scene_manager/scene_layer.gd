## Root layer of each scene managed by scene manager
class_name SMgrSceneLayer
extends CanvasLayer

var scene_id: Scenes.Id = Scenes.Id.NONE
var content_node: Node = null


func _init(p_scene_id: Scenes.Id, p_name: String) -> void:
	self.scene_id = p_scene_id
	self.name = p_name


## Set up scene nodes for content
func setup_content(p_node: Node) -> void:
	content_node = p_node
	if content_node.get_parent():
		content_node.reparent(self)
	else:
		add_child(content_node)
