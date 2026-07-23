@tool
extends SMgrCategoryGUIBase

var _subs: SMgrSection


func _ready() -> void:
	_subs = _SUB_SECTION.instantiate()
	_subsection_cont.add_child(_subs)
	_subs.setup("No Name")
	_subs.set_header_visible(false)
	_subs.open()


func _refilter() -> void:
	_subs.filter_items(_search_filter)


func _refresh_ui() -> void:
	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scenes.emit(recv, _category_id)
	_populate_section(_subs, recv)
