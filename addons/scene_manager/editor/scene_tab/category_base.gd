@tool
class_name SMgrCategoryGUIBase
extends Control

signal on_remove(category_id: int)

const _SCENE_ITEM = preload("uid://hh0sw1g7upfc")
const _SUB_SECTION = preload("uid://b4edho3whn67t")
const _C = preload("uid://c3vvdktou45u")

@export var _ebus_editor: SMgrEbusEditor
var _category_id: int
@onready var _subsection_cont: VBoxContainer = %container
@onready var _remove_list_button: Button = %remove_list
@onready var _unsaved_label: Label = %unsaved_label


func _activate() -> void:
	pass


func activate(category_id: int) -> void:
	_category_id = category_id

	if category_id == ResourceUID.INVALID_ID:
		name = _C.ALL_CATEGORY_NAME
	else:
		# get category-name from id
		var recv: Array[SMgrCategoryData]
		_ebus_editor.get_category_by_id.emit(recv, category_id)
		if not recv.is_empty():
			name = recv[0].name
	_activate()


func _on_remove_list_button_up() -> void:
	on_remove.emit(_category_id)
