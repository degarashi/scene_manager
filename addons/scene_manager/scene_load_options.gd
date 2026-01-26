## Parameter options to send when loading a new scene
class_name SceneLoadOptions
extends Resource

const C = preload("./scene_manager_constants.gd")

## Default fade out time retrieved from ProjectSettings
static var default_fade_out: float:
	get:
		return ProjectSettings.get_setting(
			C.SETTINGS_FADE_OUT_PROPERTY_NAME, C.DEFAULT_FADE_OUT_TIME
		)

## Default fade in time retrieved from ProjectSettings
static var default_fade_in: float:
	get:
		return ProjectSettings.get_setting(C.SETTINGS_FADE_IN_PROPERTY_NAME, C.DEFAULT_FADE_IN_TIME)

@export_group("Hierarchy")
## Where in the node structure the new scene will load.
@export var node_name: String = C.DEFAULT_TREE_NODE_NAME
## Whether to only have a single scene or an additive load. Defaults to SINGLE.
@export var mode: C.SceneLoadingMode = C.SceneLoadingMode.SINGLE

@export_group("Visuals")
## Duration of the fade out effect.
@export var fade_out_time: float = default_fade_out
## Duration of the fade in effect.
@export var fade_in_time: float = default_fade_in

@export_group("Interaction")
## Whether or not to block mouse input during the scene load. Defaults to true.
@export var clickable: bool = true

@export_group("")
## Whether or not to add the scene onto the stack so the scene can go back to it.
@export var add_to_back: bool = true


## Creates options for loading a scene.
##
## [param node]: Target node name for loading.
## [param mode]: Loading mode (Single/Additive).
## [param clickable]: If true, allows interaction during transition.
## [param fade_out_time]: Custom fade out duration.
## [param fade_in_time]: Custom fade in duration.
## [param add_to_back]: If true, enables navigation back to this scene.
func _init(
	node: String = C.DEFAULT_TREE_NODE_NAME,
	mode: C.SceneLoadingMode = C.SceneLoadingMode.SINGLE,
	clickable: bool = true,
	fade_out_time: float = default_fade_out,
	fade_in_time: float = default_fade_in,
	add_to_back: bool = true
) -> void:
	self.node_name = node
	self.mode = mode
	self.clickable = clickable
	self.fade_out_time = fade_out_time
	self.fade_in_time = fade_in_time
	self.add_to_back = add_to_back


## Create a copy of the SceneLoadOptions instance.
func copy() -> SceneLoadOptions:
	return self.duplicate() as SceneLoadOptions
