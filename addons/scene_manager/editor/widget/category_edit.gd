@tool
extends VBoxContainer

# ------------- [Constants] -------------
const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd
const _C = preload("uid://c3vvdktou45u")  # scene_manager_constants.gd

## UI style constants
const BORDER_WIDTH := 1
const SELECTED_BG_COLOR := Color(0.4, 0.7, 1.0, 0.04)
const SELECTED_BORDER_COLOR := Color(0.4, 0.7, 1.0, 0.5)
const BAR_BG_HEIGHT := 16
const BAR_BG_COLOR := Color(0.15, 0.15, 0.15, 0.3)
const BAR_HEIGHT := 12
const SELECTED_BAR_COLOR := Color(0.4, 0.7, 1.0, 0.9)
const UNSELECTED_BAR_COLOR := Color(0.3, 0.6, 0.9, 0.5)
const PRIORITY_LABEL_WIDTH := 48
# ------------- [Exports] -------------
@export var _ebus_editor: SMgrEbusEditor
# ------------- [Private Variable] -------------
var _category_id: int
@onready var _layer_name_edit: LineEdit = %LayerNameEdit
@onready var _follow_viewport_cb: CheckBox = %FollowViewportCB
@onready var _pause_flag_cb: CheckBox = %PauseFlagCB
@onready var _layer_priority_box: SpinBox = %LayerPriorityBox
@onready var _always_process_cb: CheckBox = %AlwaysProcessCB
@onready var _delete_button: Button = %DeleteButton
@onready var _delete_confirm: ConfirmationDialog = %DeleteConfirm
@onready var _priority_map_container: VBoxContainer = %PriorityMapContainer
var _priority_debouncer: Debouncer

# ------------- [Callbacks] -------------
func _ready() -> void:
	_ebus_editor.on_category_selected.connect(_on_category_selected)

	_priority_debouncer = Debouncer.new(_C.SHORT_DEBOUNCE_DELAY)
	add_child(_priority_debouncer)
	_priority_debouncer.timeout.connect(_build_priority_map)

# ------------- [Private Method] -------------
func _fetch_category(id: int) -> SMgrCategoryData:
	return _AF.fetch_category_from_ebus(_ebus_editor, id)


func _on_category_selected(id: int) -> void:
	if not is_inside_tree():
		return

	_category_id = id
	var cat := _fetch_category(id)
	if cat:
		self.visible = true

		_delete_button.visible = true
		_layer_name_edit.text = cat.layer_name
		# Set SpinBox before building map so _build_priority_map reads the correct value.
		# Cancel any debounce triggered by value_changed above.
		_layer_priority_box.value = cat.layer_priority
		_priority_debouncer.cancel()
		_build_priority_map()
		_pause_flag_cb.button_pressed = cat.pauses_lower_priority_layers
		_always_process_cb.button_pressed = cat.always_process
		_follow_viewport_cb.button_pressed = cat.follow_viewport
	else:
		self.visible = false


func _build_priority_map() -> void:
	# Apply the pending priority value before building the map.
	# Writing here (debounced) instead of on every value_changed avoids
	# triggering expensive signal cascades on each SpinBox increment.
	_update_category_property("layer_priority", int(_layer_priority_box.value))

	# Clear previous entries
	for child in _priority_map_container.get_children():
		child.queue_free()

	var entries := _fetch_category_entries()
	if entries.is_empty():
		return

	# Determine range for bar normalization
	var min_p: int = entries[0].priority
	var max_p: int = entries[0].priority
	for e in entries:
		min_p = mini(min_p, e.priority)
		max_p = maxi(max_p, e.priority)

	for e in entries:
		var is_selected: bool = e.id == _category_id
		_priority_map_container.add_child(_create_priority_bar_row(e, is_selected, min_p, max_p))


func _fetch_category_entries() -> Array[Dictionary]:
	# Fetch all category IDs
	var cat_ids: Array[int]
	_ebus_editor.get_categories.emit(cat_ids)
	if cat_ids.is_empty():
		return []

	# Fetch category data for each ID
	var entries: Array[Dictionary] = []
	for cid in cat_ids:
		var recv: Array[SMgrCategoryData]
		_ebus_editor.get_category_by_id.emit(recv, cid)
		if not recv.is_empty():
			entries.append(
				{
					"id": cid,
					"name": recv[0].name,
					"priority": recv[0].layer_priority
				}
			)

	if entries.is_empty():
		return []

	# Sort by priority descending
	entries.sort_custom(func(a, b): return a.priority > b.priority)
	return entries


func _create_priority_bar_row(entry: Dictionary, is_selected: bool, min_p: int, max_p: int) -> Control:
	var range_p: int = max_p - min_p
	var row: Control

	if is_selected:
		# Use PanelContainer with border to highlight the selected row
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.border_width_left = BORDER_WIDTH
		style.border_width_top = BORDER_WIDTH
		style.border_width_right = BORDER_WIDTH
		style.border_width_bottom = BORDER_WIDTH
		style.bg_color = SELECTED_BG_COLOR
		style.border_color = SELECTED_BORDER_COLOR
		panel.add_theme_stylebox_override("panel", style)
		row = panel
	else:
		row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Inner HBox for layout (PanelContainer needs a child to layout)
	var inner: HBoxContainer
	if is_selected:
		inner = HBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(inner)
	else:
		inner = row as HBoxContainer

	var name_label := Label.new()
	name_label.text = entry.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_stretch_ratio = 1.0
	inner.add_child(name_label)

	# Bar container to give the ColorRect a fixed height context
	var bar_bg := ColorRect.new()
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.size_flags_stretch_ratio = 2.0
	bar_bg.custom_minimum_size.y = BAR_BG_HEIGHT
	bar_bg.color = BAR_BG_COLOR

	var bar := ColorRect.new()
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.anchor_right = 0.0
	if range_p > 0:
		bar.anchor_right = float(entry.priority - min_p) / range_p
	else:
		bar.anchor_right = 1.0

	if is_selected:
		bar.color = SELECTED_BAR_COLOR
	else:
		bar.color = UNSELECTED_BAR_COLOR

	bar_bg.add_child(bar)
	inner.add_child(bar_bg)

	var prio_label := Label.new()
	prio_label.text = str(entry.priority)
	prio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prio_label.custom_minimum_size.x = PRIORITY_LABEL_WIDTH
	inner.add_child(prio_label)

	return row


func _update_category_property(property: String, value: Variant) -> void:
	var cat := _fetch_category(_category_id)
	if not cat:
		return
	cat.set(property, value)


func _on_layer_priority_box_value_changed(_value: float) -> void:
	# Defer property write - writing on every value change triggers
	# expensive signal cascades (data sort, full UI rebuild).
	_priority_debouncer.call_debounced()


func _on_pause_flag_cb_toggled(toggled_on: bool) -> void:
	_update_category_property("pauses_lower_priority_layers", toggled_on)


func _on_always_process_cb_toggled(toggled_on: bool) -> void:
	_update_category_property("always_process", toggled_on)


func _on_follow_viewport_cb_toggled(toggled_on: bool) -> void:
	_update_category_property("follow_viewport", toggled_on)


func _on_delete_button_button_up() -> void:
	_delete_confirm.popup_centered()


func _on_delete_confirm_confirmed() -> void:
	_ebus_editor.remove_category.emit(_category_id)


func _on_layer_name_confirmed() -> void:
	_update_category_property("layer_name", _layer_name_edit.text)


func _on_layer_name_edit_focus_exited() -> void:
	_on_layer_name_confirmed()


func _on_layer_name_edit_text_submitted(_new_text: String) -> void:
	_on_layer_name_confirmed()
	# Remove focus and complete input
	_layer_name_edit.release_focus()
