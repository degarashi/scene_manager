@tool
class_name SMgrCategoryGUIBase
extends Control

# ------------- [Constants] -------------
const _SCENE_ITEM = preload("uid://hh0sw1g7upfc")  # scene_item.tscn
const _SUB_SECTION = preload("uid://b4edho3whn67t")  # section.tscn
const _C = preload("uid://c3vvdktou45u")  # scene_manager_constants.gd
const _AF = preload("uid://dlgh4u64a7qxk")  # aux_func.gd

@export var _ebus_editor: SMgrEbusEditor

# ------------- [Private Variable] -------------
var _category_id: int
@onready var _subsection_cont: VBoxContainer = %container
var _search_filter: String = ""


func _activate() -> void:
	pass


# ------------- [Public Method] -------------
func set_search_filter(filter: String) -> void:
	if _search_filter != filter:
		_search_filter = filter
		_refilter()


## Lightweight search filtering that toggles visibility on existing items
## instead of rebuilding the entire scene list. Override in subclasses.
func _refilter() -> void:
	_refresh_ui()


func activate(category_id: int) -> void:
	assert(is_inside_tree())
	_category_id = category_id

	if category_id == ResourceUID.INVALID_ID:
		name = _C.ALL_CATEGORY_NAME
		_activate()
	else:
		# get category-name from id
		var cat := _AF.fetch_category_from_ebus(_ebus_editor, category_id)
		if cat:
			name = cat.name
			_activate()

	# Force update on the first call; subsequent updates are handled via EventBus notifications.
	_ebus_editor.on_data_changed.connect(_on_data_changed)
	_refresh_ui()


func _populate_section(
	section: SMgrSection, scenes: Array[SMgrDataScene]
) -> void:
	section.clear_list()

	if scenes.is_empty():
		return

	# Always create items for ALL scenes. Search filtering is applied afterward
	# via _refilter()/filter_items() to avoid destroying and recreating nodes
	# on every keystroke.
	scenes.sort_custom(SMgrUtil.natural_case_sort)

	for sc: SMgrDataScene in scenes:
		var item: SMgrSceneItem = _SCENE_ITEM.instantiate()
		section.add_item(item)
		item.activate(sc.uid)

	section.filter_items(_search_filter)


func _refresh_ui() -> void:
	pass


# ------------- [Callbacks] -------------
func _on_data_changed() -> void:
	_refresh_ui()


func get_category_id() -> int:
	return _category_id
