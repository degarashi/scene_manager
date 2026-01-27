@tool
extends Button

const _EBUS := preload("uid://ra25t5in8erp")
var _ps := preload("uid://dn6eh4s0h8jhi")


func _ready() -> void:
	_EBUS.on_dirty_flag_changed.connect(_adapter_func)
	_ps.on_auto_save_changed.connect(_adapter_func)
	call_deferred("_update_state")


func _adapter_func(_dirty: bool) -> void:
	_update_state()


func _update_state() -> void:
	var recv: Array[bool]
	_EBUS.get_dirty_flag.emit(recv)
	if recv.is_empty():
		return

	var dirty := recv[0]
	disabled = _ps.auto_save or not dirty
