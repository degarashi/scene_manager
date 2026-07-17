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
@onready var _scene_list_container: VBoxContainer = %SceneListContainer
@onready var _delete_button: Button = %DeleteButton
@onready var _delete_confirm: ConfirmationDialog = %DeleteConfirm
@onready var _priority_map_container: VBoxContainer = %PriorityMapContainer


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

		# Count and list scenes in this category
		var recv: Array[SMgrDataScene]
		_ebus_editor.get_scenes.emit(recv, _category_id)
		_scene_count_label.text = "Scenes: %d" % recv.size()

		# Populate scene list
		for child in _scene_list_container.get_children():
			child.queue_free()
		for sc in recv:
			var label := Label.new()
			label.text = sc.name
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			label.layout_mode = 2
			_scene_list_container.add_child(label)

		_delete_button.visible = true
		_build_priority_map()
		_layer_name_edit.text = cat.layer_name
		_layer_priority_box.value = cat.layer_priority
		_pause_flag_cb.button_pressed = cat.pauses_lower_priority_layers
		_always_process_cb.button_pressed = cat.always_process
		_follow_viewport_cb.button_pressed = cat.follow_viewport
	else:
		self.visible = false


func _build_priority_map() -> void:
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
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.layout_mode = 2

		var name_label := Label.new()
		name_label.text = e.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.size_flags_stretch_ratio = 1.0
		name_label.layout_mode = 2
		row.add_child(name_label)

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

		# Highlight selected category row with a background
		if e.id == _category_id:
			var bg := ColorRect.new()
			bg.layout_mode = 2
			bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bg.color = Color(0.3, 0.6, 1.0, 0.12)
			row.add_child(bg)
			row.move_child(bg, 0)  # Keep at bottom

		# Highlight selected category
		if e.id == _category_id:
			bar.color = Color(0.4, 0.7, 1.0, 0.9)
		else:
			bar.color = Color(0.3, 0.6, 0.9, 0.5)

		bar_bg.add_child(bar)
		row.add_child(bar_bg)

		var prio_label := Label.new()
		prio_label.text = str(e.priority)
		prio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prio_label.custom_minimum_size.x = 48
		prio_label.layout_mode = 2
		row.add_child(prio_label)

		_priority_map_container.add_child(row)


func _update_category_property(property: String, value: Variant) -> void:
	var cat := _fetch_category(_category_id)
	if not cat:
		return
	cat.set(property, value)


func _on_layer_priority_box_value_changed(value: float) -> void:
	_update_category_property("layer_priority", int(value))
	_build_priority_map()


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
