extends Object


## Safely traverse parents to find the root manager node using match
static func find_manager_root(node: Node) -> SMgrManager:
	if not node:
		return null
	var current: Node = node.get_parent()
	while current != null:
		match current.name:
			"Scene Manager", "menu":
				return current
		current = current.get_parent()
	return null
