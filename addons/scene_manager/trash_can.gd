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
## Immediately frees all pending nodes in the trash can.
## Call this before adding a new scene instance to prevent
## duplicate nodes from coexisting for a single frame.
func flush() -> void:
	for child in get_children():
		if is_instance_valid(child):
			child.free()


## Moves the node to the trash can, frees its name, and then calls queue_free.
func collect(target_node: Node) -> void:
	if not is_instance_valid(target_node):
		return

	# If it already has a parent, reparent it and change its name to avoid conflicts.
	# This immediately frees the name from the original parent node's direct children.
	if target_node.get_parent():
		target_node.reparent(self)

	target_node.name = "dying_" + String.num_uint64(target_node.get_instance_id())
	target_node.queue_free()
