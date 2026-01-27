@tool
class_name SMgrPrimarySection
extends SMgrSection


class _Name:
	const UNCATEGORIZED = "Uncategorized"
	const CATEGORIZED = "Categorized"


var _categorized_sec: SMgrSubSection
var _uncategorized_sec: SMgrSubSection


func _create_sub_section(base_name: String) -> SMgrSubSection:
	var sub: SMgrSubSection = _SUB_SECTION.instantiate()
	_subsection_cont.add_child(sub)
	sub.setup(base_name)
	sub.open()
	return sub


func _ready() -> void:
	_remove_list_button.icon = null
	_remove_list_button.disabled = true
	_remove_list_button.visible = false
	_remove_list_button.focus_mode = Control.FOCUS_NONE

	_categorized_sec = _create_sub_section(_Name.CATEGORIZED)
	_uncategorized_sec = _create_sub_section(_Name.UNCATEGORIZED)


func _update_sub_section(target_sec: SMgrSubSection, signal_obj: Signal) -> void:
	assert(target_sec)
	target_sec.clear_list()

	# get data by a signal
	var recv: Array[SMgrDataScene]
	signal_obj.emit(recv)

	if recv.is_empty():
		return

	recv.sort_custom(
		func(a: SMgrDataScene, b: SMgrDataScene) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for sc in recv:
		var item: SMgrSceneItem = _SCENE_ITEM.instantiate()
		target_sec.add_item(item)
		item.setup(sc.uid)


func _refresh_ui() -> void:
	_update_sub_section(_categorized_sec, _EBUS.get_scenes_categorized)
	_update_sub_section(_uncategorized_sec, _EBUS.get_scenes_uncategorized)


func _setup() -> void:
	_refresh_ui()
