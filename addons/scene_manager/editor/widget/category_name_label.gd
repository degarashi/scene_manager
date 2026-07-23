@tool
extends HBoxContainer

# ------------- [Constants] -------------
const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd

# ------------- [Exports] -------------
@export var _ebus_editor: SMgrEbusEditor

# ------------- [Private Variable] -------------
var _current_category_id: int = ResourceUID.INVALID_ID
var _previous_name: String = ""

@onready var _name_edit: LineEdit = %NameEdit
@onready var _edit_button: Button = %EditButton
@onready var _scene_count_label: Label = %SceneCountLabel


# ------------- [Callbacks] -------------
func _ready() -> void:
	_ebus_editor.on_category_selected.connect(_on_category_selected)
	if Engine.is_editor_hint():
		_edit_button.icon = get_theme_icon("Edit", "EditorIcons")


func _on_category_selected(id: int) -> void:
	_current_category_id = id
	_refresh_ui()


func _refresh_ui() -> void:
	if _current_category_id == ResourceUID.INVALID_ID:
		_name_edit.text = "----"
		_edit_button.visible = false
		return

	var cat := _AF.fetch_category_from_ebus(
		_ebus_editor, _current_category_id
	)

	if cat:
		_name_edit.text = cat.name
		_edit_button.visible = true

		# Fetch scene count for this category
		var recv: Array[SMgrDataScene]
		_ebus_editor.get_scenes.emit(recv, _current_category_id)
		_scene_count_label.text = "(%d)" % recv.size()
		_scene_count_label.show()
	else:
		_name_edit.text = "----"
		_edit_button.visible = false
		_scene_count_label.hide()

	_name_edit.editable = false
	_name_edit.flat = true


func _on_edit_button_button_up() -> void:
	if _current_category_id == ResourceUID.INVALID_ID:
		return

	_previous_name = _name_edit.text
	_name_edit.editable = true
	_name_edit.flat = false
	_name_edit.grab_focus()
	_name_edit.select_all()


func _on_name_edit_text_submitted(new_text: String) -> void:
	_submit_rename(new_text)


func _on_name_edit_focus_exited() -> void:
	if _name_edit.editable:
		_submit_rename(_name_edit.text)


func _submit_rename(new_name: String) -> void:
	var sanitized := new_name.strip_edges()
	if sanitized == _previous_name or sanitized.is_empty():
		_refresh_ui()
		return

	# Duplication check
	var recv: Array[bool]
	_ebus_editor.category_name_duplication_check.emit(recv, sanitized)
	if recv.is_empty() or recv[0]:
		# Reset to previous
		_refresh_ui()
		return

	_ebus_editor.rename_category.emit(_current_category_id, sanitized)
	# After renaming, the ID will change, so we might need to update _current_category_id
	# but the ebus will notify on_data_changed, and the main panel will reload categories.
	# Actually, the category ID is the hash of the name.
	_current_category_id = sanitized.hash()
	_refresh_ui()
