# ============================================================
#  WARNING: AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.
#  This file was generated from an .ifc definition.
# ============================================================

# Generated at: 2026-05-16 15:33:45

class_name IFadeOutNotify
extends InterfaceBase

func on_fade_out_start() -> void:
	assert(is_valid(), "[Interface] Accessing freed instance")
	_impl.on_fade_out_start()

func on_fade_out_end() -> void:
	assert(is_valid(), "[Interface] Accessing freed instance")
	_impl.on_fade_out_end()

static func cast(obj: Object) -> IFadeOutNotify:
	return Interface.as_interface(obj, IFadeOutNotify) as IFadeOutNotify

static func cast_checked(obj: Object) -> IFadeOutNotify:
	var res := cast(obj)
	assert(res != null, "[Interface] Cast failed: Object does not implement IFadeOutNotify")
	return res
