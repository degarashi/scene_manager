class_name SMgrTrashCan
extends Control
## Management class for safely deleting unnecessary scene nodes.


# ------------- [Callbacks] -------------
func _init() -> void:
	name = "SMgrTrashCan"
	# Stop processing and hide to minimize load
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false


# ------------- [Public Method] -------------
## Moves the node to the trash can, frees its name, and then calls queue_free.
func collect(target_node: Node) -> void:
	if not is_instance_valid(target_node):
		return

	# If it already has a parent, reparent it and change its name to avoid conflicts.
	# This immediately frees the name from the original parent node's direct children.
	if target_node.get_parent():
		target_node.reparent(self)

	target_node.name = "dying_" + str(target_node.get_instance_id())
	target_node.queue_free()
