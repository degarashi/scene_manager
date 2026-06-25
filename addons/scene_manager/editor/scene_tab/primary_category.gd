@tool
extends SMgrCategoryGUIBase


class _Name:
	const UNCATEGORIZED = "Uncategorized"
	const CATEGORIZED = "Categorized"


var _categorized_sec: SMgrSection
var _uncategorized_sec: SMgrSection


func _create_sub_section(base_name: String) -> SMgrSection:
	var sub: SMgrSection = _SUB_SECTION.instantiate()
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


func _refresh_ui() -> void:
	for tup in [[_categorized_sec, _ebus_editor.get_scenes_categorized], [_uncategorized_sec, _ebus_editor.get_scenes_uncategorized]]:
		var recv: Array[SMgrDataScene]
		tup[1].emit(recv)
		_populate_section(tup[0], recv)
