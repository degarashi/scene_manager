class_name SMgrConstants
## Constants used by the editor and the scene manager in the game

## Enums for how to load the scene.
enum SceneLoadingMode {
	## Will make it so only one scene will exist for the whole tree. Default option.
	SINGLE,
	## Will make it so only one scene will exist for the specified node.
	SINGLE_NODE,
	## Will add the scene to the node along with anything else loaded.
	ADDITIVE
}

## Default node name to be used for scenes
const DEFAULT_TREE_NODE_NAME: String = "World"
## Default node name for loading/transition scenes
const DEFAULT_LOADING_NODE_NAME: String = "===Transition==="