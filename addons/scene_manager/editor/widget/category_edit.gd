@tool
extends VBoxContainer

const _AF = preload("uid://dlgh4u64a7qxk")
@export var _ebus_editor: SMgrEbusEditor
var _category_id: int
@onready var _pause_flag_cb: CheckBox = %PauseFlagCB
@onready var _layer_priority_box: SpinBox = %LayerPriorityBox
@onready var _always_process_cb: CheckBox = %AlwaysProcessCB


func _ready() -> void:
	if _AF.is_in_main_screen(self):
		return
	_ebus_editor.on_category_selected.connect(_on_category_selected)


func _fetch_category(id: int) -> SMgrCategoryData:
	var recv: Array[SMgrCategoryData]
	_ebus_editor.get_category_by_id.emit(recv, id)
	if recv.is_empty():
		return null
	return recv[0]


func _on_category_selected(id: int) -> void:
	if not is_inside_tree():
		return

	_category_id = id
	var cat := _fetch_category(id)
	if cat:
		self.visible = true
		_layer_priority_box.value = cat.layer_priority
		_pause_flag_cb.button_pressed = cat.pauses_lower_priority_layers
		_always_process_cb.button_pressed = cat.always_process
	else:
		self.visible = false


func _on_layer_priority_box_value_changed(value: float) -> void:
	var cat := _fetch_category(_category_id)
	if not cat:
		return

	cat.layer_priority = int(value)


func _on_pause_flag_cb_toggled(toggled_on: bool) -> void:
	var cat := _fetch_category(_category_id)
	if not cat:
		return

	cat.pauses_lower_priority_layers = toggled_on


func _on_always_process_cb_toggled(toggled_on: bool) -> void:
	var cat := _fetch_category(_category_id)
	if not cat:
		return

	cat.always_process = toggled_on
