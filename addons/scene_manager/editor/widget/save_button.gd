@tool
extends Button

@export var _ebus_editor: SMgrEbusEditor
var _ps := preload("uid://dn6eh4s0h8jhi")  # project_settings.tres
var _dirty_style: StyleBoxFlat


func _ready() -> void:
	_ebus_editor.on_dirty_flag_changed.connect(_adapter_func)
	_ps.on_auto_save_changed.connect(_adapter_func)

	_dirty_style = StyleBoxFlat.new()
	_dirty_style.bg_color = Color(0.2, 0.5, 1.0, 0.2)
	_dirty_style.border_color = Color(0.2, 0.5, 1.0, 0.5)
	_dirty_style.border_width_left = 1
	_dirty_style.border_width_top = 1
	_dirty_style.border_width_right = 1
	_dirty_style.border_width_bottom = 1
	_dirty_style.corner_radius_top_left = 3
	_dirty_style.corner_radius_top_right = 3
	_dirty_style.corner_radius_bottom_right = 3
	_dirty_style.corner_radius_bottom_left = 3

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

	if dirty and not _ps.auto_save:
		add_theme_stylebox_override("normal", _dirty_style)
	else:
		remove_theme_stylebox_override("normal")
