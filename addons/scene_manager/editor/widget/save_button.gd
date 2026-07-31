@tool
extends Button

# ------------- [Constants] -------------
const BORDER_WIDTH := 1
const CORNER_RADIUS := 3
const DIRTY_BG_COLOR := Color(0.2, 0.5, 1.0, 0.2)
const DIRTY_BORDER_COLOR := Color(0.2, 0.5, 1.0, 0.5)
const AUTO_SAVE_BG_COLOR := Color(0.0, 0.7, 0.3, 0.15)
const AUTO_SAVE_BORDER_COLOR := Color(0.0, 0.7, 0.3, 0.5)

# ------------- [Exports] -------------
@export var _ebus_editor: SMgrEbusEditor

# ------------- [Private Variable] -------------
var _ps := preload("uid://dn6eh4s0h8jhi")  # project_settings.tres
var _dirty_style: StyleBoxFlat
var _auto_save_style: StyleBoxFlat


# ------------- [Callbacks] -------------
func _ready() -> void:
	_ebus_editor.on_dirty_flag_changed.connect(_adapter_func)
	_ps.on_auto_save_changed.connect(_adapter_func)

	_dirty_style = StyleBoxFlat.new()
	_dirty_style.bg_color = DIRTY_BG_COLOR
	_dirty_style.border_color = DIRTY_BORDER_COLOR
	_dirty_style.border_width_left = BORDER_WIDTH
	_dirty_style.border_width_top = BORDER_WIDTH
	_dirty_style.border_width_right = BORDER_WIDTH
	_dirty_style.border_width_bottom = BORDER_WIDTH
	_dirty_style.corner_radius_top_left = CORNER_RADIUS
	_dirty_style.corner_radius_top_right = CORNER_RADIUS
	_dirty_style.corner_radius_bottom_right = CORNER_RADIUS
	_dirty_style.corner_radius_bottom_left = CORNER_RADIUS

	_auto_save_style = StyleBoxFlat.new()
	_auto_save_style.bg_color = AUTO_SAVE_BG_COLOR
	_auto_save_style.border_color = AUTO_SAVE_BORDER_COLOR
	_auto_save_style.border_width_left = BORDER_WIDTH
	_auto_save_style.border_width_top = BORDER_WIDTH
	_auto_save_style.border_width_right = BORDER_WIDTH
	_auto_save_style.border_width_bottom = BORDER_WIDTH
	_auto_save_style.corner_radius_top_left = CORNER_RADIUS
	_auto_save_style.corner_radius_top_right = CORNER_RADIUS
	_auto_save_style.corner_radius_bottom_right = CORNER_RADIUS
	_auto_save_style.corner_radius_bottom_left = CORNER_RADIUS

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

	if _ps.auto_save:
		add_theme_stylebox_override("normal", _auto_save_style)
		add_theme_stylebox_override("disabled", _auto_save_style)
	elif dirty:
		add_theme_stylebox_override("normal", _dirty_style)
		remove_theme_stylebox_override("disabled")
	else:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("disabled")
