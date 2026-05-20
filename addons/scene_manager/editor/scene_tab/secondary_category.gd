@tool
extends SMgrCategoryGUIBase

var _subs: SMgrSection


func _ready() -> void:
	_subs = _SUB_SECTION.instantiate()
	_subsection_cont.add_child(_subs)
	_subs.setup("No Name")
	_subs.set_header_visible(false)
	_subs.open()


func _refresh_ui() -> void:
	_subs.clear_list()

	# get data by a signal
	var recv: Array[SMgrDataScene]
	_ebus_editor.get_scenes.emit(recv, _category_id)

	if recv.is_empty():
		return

	if not _search_filter.is_empty():
		recv = recv.filter(
			func(sc: SMgrDataScene): return _search_filter.to_lower() in sc.name.to_lower()
		)

	recv.sort_custom(
		func(a: SMgrDataScene, b: SMgrDataScene) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for sc: SMgrDataScene in recv:
		var item: SMgrSceneItem = _SCENE_ITEM.instantiate()
		_subs.add_item(item)
		item.activate(sc.uid)
