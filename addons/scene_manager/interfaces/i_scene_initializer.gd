# ============================================================
#  WARNING: AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.
#  This file was generated from an .ifc definition.
# ============================================================

# Generated at: 2026-05-16 15:26:18

class_name ISceneInitializer
extends InterfaceBase

## Interface for initializing a scene with parameters.
func on_scene_init(params: Variant) -> void:
	assert(is_valid(), "[Interface] Accessing freed instance")
	_impl.on_scene_init(params)

static func cast(obj: Object) -> ISceneInitializer:
	return Interface.as_interface(obj, ISceneInitializer) as ISceneInitializer

static func cast_checked(obj: Object) -> ISceneInitializer:
	var res := cast(obj)
	assert(res != null, "[Interface] Cast failed: Object does not implement ISceneInitializer")
	return res
