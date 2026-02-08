## Parameter options to send when loading a new scene
class_name SceneLoadOptions
extends Resource

const _C = preload("uid://c3vvdktou45u")
static var _ps := preload("uid://dn6eh4s0h8jhi")

## Default fade out time retrieved from ProjectSettings
static var default_fade_out: float:
	get:
		return _ps.fade_out_time

## Default fade in time retrieved from ProjectSettings
static var default_fade_in: float:
	get:
		return _ps.fade_in_time

@export_group("Hierarchy")
## Where in the node structure the new scene will load.
@export var node_name: String = _C.DEFAULT_TREE_NODE_NAME

@export_group("Visuals")
## Duration of the fade out effect.
@export var fade_out_time: float = default_fade_out
## Duration of the fade in effect.
@export var fade_in_time: float = default_fade_in

@export_group("Interaction")
## Whether or not to block mouse input during the scene load. Defaults to true.
@export var clickable: bool = true


## Creates options for loading a scene.
##
## [param node]: Target node name for loading.
## [param clickable]: If true, allows interaction during transition.
## [param fade_out_time]: Custom fade out duration.
## [param fade_in_time]: Custom fade in duration.
func _init(
	node: String = _C.DEFAULT_TREE_NODE_NAME,
	clickable: bool = true,
	fade_out_time: float = default_fade_out,
	fade_in_time: float = default_fade_in
) -> void:
	self.node_name = node
	self.clickable = clickable
	self.fade_out_time = fade_out_time
	self.fade_in_time = fade_in_time


## Create a copy of the SceneLoadOptions instance.
func copy() -> SceneLoadOptions:
	return self.duplicate() as SceneLoadOptions
