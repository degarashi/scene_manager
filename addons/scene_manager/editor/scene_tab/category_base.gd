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
var _search_filter: String = ""


func _activate() -> void:
	pass


func set_search_filter(filter: String) -> void:
	if _search_filter != filter:
		_search_filter = filter
		_refresh_ui()


func activate(category_id: int) -> void:
	assert(is_inside_tree())
	_category_id = category_id

	if category_id == ResourceUID.INVALID_ID:
		name = _C.ALL_CATEGORY_NAME
		_activate()
	else:
		# get category-name from id
		var recv: Array[SMgrCategoryData]
		_ebus_editor.get_category_by_id.emit(recv, category_id)
		if not recv.is_empty():
			name = recv[0].name
			_activate()

	# Force update on the first call; subsequent updates are handled via EventBus notifications.
	_ebus_editor.on_data_changed.connect(_on_data_changed)
	_refresh_ui()


func _populate_section(section: SMgrSection, scenes: Array[SMgrDataScene]) -> void:
	section.clear_list()

	if scenes.is_empty():
		return

	if not _search_filter.is_empty():
		scenes = scenes.filter(
			func(sc: SMgrDataScene): return _search_filter.to_lower() in sc.name.to_lower()
		)

	scenes.sort_custom(
		func(a: SMgrDataScene, b: SMgrDataScene) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for sc: SMgrDataScene in scenes:
		var item: SMgrSceneItem = _SCENE_ITEM.instantiate()
		section.add_item(item)
		item.activate(sc.uid)


func _refresh_ui() -> void:
	pass


func _on_data_changed() -> void:
	_refresh_ui()


func _on_remove_list_button_up() -> void:
	on_remove.emit(_category_id)


func get_category_id() -> int:
	return _category_id
