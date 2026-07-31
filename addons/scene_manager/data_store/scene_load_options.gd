## Parameter options to send when loading a new scene
class_name SceneLoadOptions
extends Resource

# ------------- [Constants] -------------

const _C = preload("uid://c3vvdktou45u")  # scene_manager_constants.gd
const DEFAULT_CLICKABLE_FLAG = false
static var _ps := preload("uid://dn6eh4s0h8jhi")  # project_settings.tres
static var _empty_cb := func(_arg: Node) -> void: pass

# ------------- [Exports] -------------

@export_group("Hierarchy")
## Where in the node structure the new scene will load.
@export var node_name: String = _C.DEFAULT_TREE_NODE_NAME

@export_group("Visuals")
## Duration of the fade out effect.
@export var play_out_time: float = _C.DEFAULT_PLAY_TIME_EXPORT
## Duration of the fade in effect.
@export var play_in_time: float = _C.DEFAULT_PLAY_TIME_EXPORT
## Override the default transitioner with a custom one by specifying its Scene ID.
@export var transition_id: int = -1
## Layer priority for the transition CanvasLayer. (-1 to use project default)
@export var transition_layer: int = -1

@export_group("Data")
## Parameters to pass to the scene via ISceneInitializer.
@export var params: Variant = null

@export_group("Interaction")
## Whether or not to block mouse input during the scene load.
@export var clickable: bool = DEFAULT_CLICKABLE_FLAG

# ------------- [Private Variable] -------------

var pre_wrap_cb: Callable
var pre_node_cb: Callable
var scene_loaded_cb: Callable


# ------------- [Public Method] -------------

## Helper (static method) to get default values from project settings, etc.
static func get_default_settings() -> SMgrProjectSettings:
	return _ps


func call_pre_cb(wrap_node: Node, node: Node) -> void:
	if pre_wrap_cb.is_valid():
		pre_wrap_cb.call(wrap_node)
	if pre_node_cb.is_valid():
		pre_node_cb.call(node)


## Creates options for loading a scene.
func _init(
	p_node: String = "",
	p_clickable: bool = DEFAULT_CLICKABLE_FLAG,
	p_play_out: float = -1.0,
	p_play_in: float = -1.0,
	p_pre_wrap_cb: Callable = _empty_cb,
	p_pre_node_cb: Callable = _empty_cb,
	p_transition_id: int = -1,
	p_transition_layer: int = -1,
	p_scene_loaded_cb: Callable = _empty_cb,
) -> void:
	# Logic for determining default values
	var settings := get_default_settings()

	# Set Node Name
	if p_node != "":
		node_name = p_node

	clickable = p_clickable

	# Determine fade times (if the argument is negative, get from the settings file)
	if p_play_out >= 0.0:
		play_out_time = p_play_out
	elif settings != null:
		play_out_time = settings.play_out_time

	if p_play_in >= 0.0:
		play_in_time = p_play_in
	elif settings != null:
		play_in_time = settings.play_in_time

	if p_transition_layer != -1:
		transition_layer = p_transition_layer
	elif settings != null:
		transition_layer = settings.transition_layer

	pre_wrap_cb = p_pre_wrap_cb
	pre_node_cb = p_pre_node_cb
	transition_id = p_transition_id
	scene_loaded_cb = p_scene_loaded_cb


## Create a deep copy of the SceneLoadOptions instance.
## Duplicate only shallow-copies @export properties, so Callables and
## nested Dictionary/Array/Resource values inside `params` must be
## deep-copied explicitly.
func copy() -> SceneLoadOptions:
	var c := self.duplicate() as SceneLoadOptions
	if c:
		# duplicate() copies Callable references — that's fine because
		# Callables are immutable value types in GDScript.
		c.pre_wrap_cb = pre_wrap_cb
		c.pre_node_cb = pre_node_cb
		c.scene_loaded_cb = scene_loaded_cb
		# params may contain mutable objects (Dict, Array, Resource).
		c.params = _deep_copy_variant(params)
	return c


## Recursively deep-copies Dictionary, Array, and Resource values.
## Primitive types (int, float, String, bool) and Callables are returned as-is.
static func _deep_copy_variant(value: Variant) -> Variant:
	if value is Dictionary:
		var copy := {}
		for key in value:
			copy[key] = _deep_copy_variant(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		copy.resize(value.size())
		for i in value.size():
			copy[i] = _deep_copy_variant(value[i])
		return copy
	if value is Resource:
		return value.duplicate(true)
	return value


func _to_string() -> String:
	return (
		(
			"SceneLoadOptions(node_name='%s', play_out_time=%.2f,"
			+ " play_in_time=%.2f, clickable=%s, transition_id=%s, transition_layer=%d, has_scene_loaded_cb=%s)"
		)
		% [
			node_name,
			play_out_time,
			play_in_time,
			clickable,
			transition_id,
			transition_layer,
			str(scene_loaded_cb.is_valid())
		]
	)
