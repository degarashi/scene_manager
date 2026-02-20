@tool
class_name SceneLineEdit
extends LineEdit

@export var _ebus_ins: SMgrEbusInspector
@export var autocomplete: AutoCompleteAssistant


## Generates strings from the enum to feed into the autocomplete list
func generate_autocomplete() -> void:
	var str_list: Array[String]
	_ebus_ins.get_scene_enums_as_string.emit(str_list)
	str_list.sort()

	autocomplete.load_terms(str_list, true)
