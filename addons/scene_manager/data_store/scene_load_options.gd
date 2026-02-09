## Parameter options to send when loading a new scene
class_name SceneLoadOptions
extends Resource

const _C = preload("uid://c3vvdktou45u")
static var _ps := preload("uid://dn6eh4s0h8jhi")

@export_group("Hierarchy")
## Where in the node structure the new scene will load.
@export var node_name: String = _C.DEFAULT_TREE_NODE_NAME

@export_group("Visuals")
## Duration of the fade out effect.
@export var fade_out_time: float = 0.5
## Duration of the fade in effect.
@export var fade_in_time: float = 0.5

@export_group("Interaction")
## Whether or not to block mouse input during the scene load.
@export var clickable: bool = true


## Helper (static method) to get default values from project settings, etc.
static func get_default_settings() -> SMgrProjectSettings:
	return _ps


## Creates options for loading a scene.
func _init(
	p_node: String = "",
	p_clickable: bool = true,
	p_fade_out: float = -1.0,
	p_fade_in: float = -1.0,
) -> void:
	# Logic for determining default values
	var settings := get_default_settings()

	# Set Node Name
	if p_node != "":
		node_name = p_node

	clickable = p_clickable

	# Determine fade times (if the argument is negative, get from the settings file)
	if p_fade_out >= 0.0:
		fade_out_time = p_fade_out
	elif settings != null:
		fade_out_time = settings.fade_out_time

	if p_fade_in >= 0.0:
		fade_in_time = p_fade_in
	elif settings != null:
		fade_in_time = settings.fade_in_time


## Create a deep copy of the SceneLoadOptions instance.
func copy() -> SceneLoadOptions:
	return self.duplicate() as SceneLoadOptions


func _to_string() -> String:
	return (
		"SceneLoadOptions(node_name='%s', fade_out_time=%.2f, fade_in_time=%.2f, clickable=%s)"
		% [node_name, fade_out_time, fade_in_time, clickable]
	)
