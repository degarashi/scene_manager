@tool
extends VBoxContainer

const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd
@export var _ebus_editor: SMgrEbusEditor
var _category_id: int
@onready var _layer_name_edit: LineEdit = %LayerNameEdit
@onready var _follow_viewport_cb: CheckBox = %FollowViewportCB
@onready var _pause_flag_cb: CheckBox = %PauseFlagCB
@onready var _layer_priority_box: SpinBox = %LayerPriorityBox
@onready var _always_process_cb: CheckBox = %AlwaysProcessCB


func _ready() -> void:
	if _AF.is_in_main_screen(self):
		return
	_ebus_editor.on_category_selected.connect(_on_category_selected)


func _fetch_category(id: int) -> SMgrCategoryData:
	return _AF.fetch_category_from_ebus(_ebus_editor, id)


func _on_category_selected(id: int) -> void:
	if not is_inside_tree():
		return

	_category_id = id
	var cat := _fetch_category(id)
	if cat:
		self.visible = true
		_layer_name_edit.text = cat.layer_name
		_layer_priority_box.value = cat.layer_priority
		_pause_flag_cb.button_pressed = cat.pauses_lower_priority_layers
		_always_process_cb.button_pressed = cat.always_process
		_follow_viewport_cb.button_pressed = cat.follow_viewport
	else:
		self.visible = false


func _update_category_property(
	property: String, value: Variant
) -> void:
	var cat := _fetch_category(_category_id)
	if not cat:
		return
	cat.set(property, value)


func _on_layer_priority_box_value_changed(value: float) -> void:
	_update_category_property("layer_priority", int(value))


func _on_pause_flag_cb_toggled(toggled_on: bool) -> void:
	_update_category_property(
		"pauses_lower_priority_layers", toggled_on
	)


func _on_always_process_cb_toggled(toggled_on: bool) -> void:
	_update_category_property("always_process", toggled_on)


func _on_follow_viewport_cb_toggled(toggled_on: bool) -> void:
	_update_category_property("follow_viewport", toggled_on)


func _on_layer_name_confirmed() -> void:
	_update_category_property("layer_name", _layer_name_edit.text)


func _on_layer_name_edit_focus_exited() -> void:
	_on_layer_name_confirmed()


func _on_layer_name_edit_text_submitted(_new_text: String) -> void:
	_on_layer_name_confirmed()
	# Remove focus and complete input
	_layer_name_edit.release_focus()
