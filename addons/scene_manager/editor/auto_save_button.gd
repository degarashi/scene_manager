@tool
extends Button

const _ICON_CHECKBOX_ON = preload("uid://c1ps4ed6wrx51")
const _ICON_CHECKBOX_OFF = preload("uid://bu5cjmgtiiwfp")
const _EBUS := preload("uid://ra25t5in8erp")
var _ps := preload("uid://dn6eh4s0h8jhi")


func _ready() -> void:
	_change_auto_save_state(_ps.auto_save)
	_ps.on_auto_save_changed.connect(_change_auto_save_state)


func _change_auto_save_state(value: bool) -> void:
	icon = _ICON_CHECKBOX_ON if value else _ICON_CHECKBOX_OFF


func _on_button_up() -> void:
	_ps.auto_save = not _ps.auto_save
