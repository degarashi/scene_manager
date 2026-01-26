## Parameter options to send when loading a new scene
class_name SceneLoadOptions
extends Resource

const C = preload("./scene_manager_constants.gd")
## Where in the node structure the new scene will load.
var node_name: String = C.DEFAULT_TREE_NODE_NAME
## Whether to only have a single scene or an additive load. Defaults to SINGLE.
var mode: C.SceneLoadingMode = C.SceneLoadingMode.SINGLE
var fade_out_time: float = ProjectSettings.get_setting(
	C.SETTINGS_FADE_OUT_PROPERTY_NAME, C.DEFAULT_FADE_OUT_TIME
)
var fade_in_time: float = ProjectSettings.get_setting(
	C.SETTINGS_FADE_IN_PROPERTY_NAME, C.DEFAULT_FADE_IN_TIME
)
## Whether or not to block mouse input during the scene load. Defaults to true.
var clickable: bool = true
## Whether or not to add the scene onto the stack so the scene can go back to it.
var add_to_back: bool = true


## Create a copy of the `SceneLoadOptions` class
func copy() -> SceneLoadOptions:
	var options := SceneLoadOptions.new()
	options.node_name = node_name
	options.mode = mode
	options.fade_out_time = fade_out_time
	options.fade_in_time = fade_in_time
	options.clickable = clickable
	options.add_to_back = add_to_back
	return options
