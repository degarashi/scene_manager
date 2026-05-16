# ============================================================
#  WARNING: AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.
#  This file was generated from an .ifc definition.
# ============================================================

# Generated at: 2026-05-16 14:13:26

class_name IFadeInNotify
extends InterfaceBase

func on_fade_in_end() -> void:
	assert(is_valid(), "[Interface] Accessing freed instance")
	_impl.on_fade_in_end()

static func cast(obj: Object) -> IFadeInNotify:
	return Interface.as_interface(obj, IFadeInNotify) as IFadeInNotify

static func cast_checked(obj: Object) -> IFadeInNotify:
	var res := cast(obj)
	assert(res != null, "[Interface] Cast failed: Object does not implement IFadeInNotify")
	return res
