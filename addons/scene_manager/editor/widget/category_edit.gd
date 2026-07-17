@tool
extends VBoxContainer

const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd
@export var _ebus_editor: SMgrEbusEditor
var _category_id: int
@onready var _scene_count_label: Label = %SceneCountLabel
@onready var _layer_name_edit: LineEdit = %LayerNameEdit
@onready var _follow_viewport_cb: CheckBox = %FollowViewportCB
@onready var _pause_flag_cb: CheckBox = %PauseFlagCB
@onready var _layer_priority_box: SpinBox = %LayerPriorityBox
@onready var _always_process_cb: CheckBox = %AlwaysProcessCB
@onready var _scene_list_container: HFlowContainer = %SceneListContainer
@onready var _delete_button: Button = %DeleteButton
@onready var _delete_confirm: ConfirmationDialog = %DeleteConfirm
@onready var _priority_map_container: VBoxContainer = %PriorityMapContainer
var _priority_debouncer: Debouncer


func _ready() -> void:
	if _AF.is_in_main_screen(self):
		return
	_ebus_editor.on_category_selected.connect(_on_category_selected)

	_priority_debouncer = Debouncer.new(0.3)
	add_child(_priority_debouncer)
	_priority_debouncer.timeout.connect(_build_priority_map)


func _fetch_category(id: int) -> SMgrCategoryData:
	return _AF.fetch_category_from_ebus(_ebus_editor, id)


func _on_category_selected(id: int) -> void:
	if not is_inside_tree():
		return

	_category_id = id
	var cat := _fetch_category(id)
	if cat:
		self.visible = true

		# Count and list scenes in this category
		var recv: Array[SMgrDataScene]
		_ebus_editor.get_scenes.emit(recv, _category_id)
		_scene_count_label.text = "Scenes: %d" % recv.size()

		# Populate scene list
		for child in _scene_list_container.get_children():
			child.queue_free()
		for i in recv.size():
			var sc := recv[i]
			var row := _make_scene_list_item(sc.name, i)
			_scene_list_container.add_child(row)

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

	# Fetch all category IDs
	var cat_ids: Array[int]
	_ebus_editor.get_categories.emit(cat_ids)
	if cat_ids.is_empty():
		return

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
		return

	# Sort by priority descending
	entries.sort_custom(func(a, b): return a.priority > b.priority)

	# Determine range for bar normalization
	var min_p: int = entries[0].priority
	var max_p: int = entries[0].priority
	for e in entries:
		min_p = mini(min_p, e.priority)
		max_p = maxi(max_p, e.priority)

	var range_p: int = max_p - min_p

	for e in entries:
		var is_selected: bool = e.id == _category_id
		var row: Control

		if is_selected:
			# Use PanelContainer with border to highlight the selected row
			var panel := PanelContainer.new()
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.layout_mode = 2
			var style := StyleBoxFlat.new()
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.bg_color = Color(0.4, 0.7, 1.0, 0.04)
			style.border_color = Color(0.4, 0.7, 1.0, 0.5)
			panel.add_theme_stylebox_override("panel", style)
			row = panel
		else:
			row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.layout_mode = 2

		# Inner HBox for layout (PanelContainer needs a child to layout)
		var inner: HBoxContainer
		if is_selected:
			inner = HBoxContainer.new()
			inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inner.layout_mode = 2
			row.add_child(inner)
		else:
			inner = row as HBoxContainer

		var name_label := Label.new()
		name_label.text = e.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_stretch_ratio = 1.0
		name_label.layout_mode = 2
		inner.add_child(name_label)

		# Bar container to give the ColorRect a fixed height context
		var bar_bg := ColorRect.new()
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.size_flags_stretch_ratio = 2.0
		bar_bg.custom_minimum_size.y = 16
		bar_bg.color = Color(0.15, 0.15, 0.15, 0.3)
		bar_bg.layout_mode = 2

		var bar := ColorRect.new()
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size.y = 12
		bar.anchor_right = 0.0
		bar.layout_mode = 2
		if range_p > 0:
			bar.anchor_right = float(e.priority - min_p) / range_p
		else:
			bar.anchor_right = 1.0

		if is_selected:
			bar.color = Color(0.4, 0.7, 1.0, 0.9)
		else:
			bar.color = Color(0.3, 0.6, 0.9, 0.5)

		bar_bg.add_child(bar)
		inner.add_child(bar_bg)

		var prio_label := Label.new()
		prio_label.text = str(e.priority)
		prio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prio_label.custom_minimum_size.x = 48
		prio_label.layout_mode = 2
		inner.add_child(prio_label)

		_priority_map_container.add_child(row)


func _make_scene_list_item(scene_name: String, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.layout_mode = 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.5, 0.8, 0.06) if index % 2 == 0 else Color(0.3, 0.5, 0.8, 0.02)
	style.border_color = Color(0.3, 0.5, 0.8, 0.15)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var name_label := Label.new()
	name_label.text = scene_name
	name_label.layout_mode = 2
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(name_label)

	return panel


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
