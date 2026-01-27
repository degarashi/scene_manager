@tool
class_name SMgrSecondarySection
extends SMgrSection

var _subs: SMgrSubSection


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
	_EBUS.get_scenes.emit(recv, _section_name)

	if recv.is_empty():
		return

	recv.sort_custom(
		func(a: SMgrDataScene, b: SMgrDataScene) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for sc: SMgrDataScene in recv:
		var item: SMgrSceneItem = _SCENE_ITEM.instantiate() as SMgrSceneItem
		_subs.add_item(item)
		item.setup(sc.uid)


func _setup() -> void:
	_refresh_ui()
