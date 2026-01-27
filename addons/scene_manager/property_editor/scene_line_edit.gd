@tool
class_name SceneLineEdit
extends LineEdit

const EBUS_I = preload("uid://bnwpfojr6e0dh")
@export var autocomplete: AutoCompleteAssistant


## Generates strings from the enum to feed into the autocomplete list
func generate_autocomplete() -> void:
	var str_list: Array[String]
	EBUS_I.get_scene_enums.emit(str_list)
	str_list.sort()

	autocomplete.load_terms(str_list, true)
