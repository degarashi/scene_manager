@tool
class_name SMgrSection
extends Control

signal on_remove(section_name: String)

const _SCENE_ITEM = preload("uid://hh0sw1g7upfc")
const _SUB_SECTION = preload("uid://b4edho3whn67t")
const _C = preload("uid://c3vvdktou45u")
const _EBUS := preload("uid://ra25t5in8erp")

var _section_name: String
@onready var _subsection_cont: VBoxContainer = %container
@onready var _remove_list_button: Button = %remove_list
@onready var _unsaved_label: Label = %unsaved_label


func _setup() -> void:
	pass


func setup(name_a: String) -> void:
	_section_name = name_a
	name = name_a
	_setup()


func _on_remove_list_button_up() -> void:
	on_remove.emit(_section_name)
