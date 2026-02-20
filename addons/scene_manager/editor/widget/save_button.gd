@tool
extends Button

@export var _ebus_editor: SMgrEbusEditor
var _ps := preload("uid://dn6eh4s0h8jhi")


func _ready() -> void:
	_ebus_editor.on_dirty_flag_changed.connect(_adapter_func)
	_ps.on_auto_save_changed.connect(_adapter_func)
	_update_state.call_deferred()


func _adapter_func(_dirty: bool) -> void:
	_update_state()


func _update_state() -> void:
	var recv: Array[bool]
	_ebus_editor.get_dirty_flag.emit(recv)
	if recv.is_empty():
		return

	var dirty := recv[0]
	disabled = _ps.auto_save or not dirty
