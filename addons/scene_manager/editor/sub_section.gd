@tool
class_name SMgrSubSection
extends Control

const _OPEN_ICON = preload("uid://c7o4wjygnjhjc")
const _CLOSE_ICON = preload("uid://dhsmjlnpmbcwm")

var _is_open: bool = true

@onready var _button_header: Button = %Button
@onready var _scene_item_cont: VBoxContainer = %SceneItemContainer


func setup(name_a: String) -> void:
	_button_header.text = name_a


func clear_list() -> void:
	for child in _scene_item_cont.get_children():
		child.queue_free()


func add_item(item: SMgrSceneItem) -> void:
	_scene_item_cont.add_child(item)


func open() -> void:
	_is_open = true
	_scene_item_cont.visible = true
	_update_header_icon()


func close() -> void:
	_is_open = false
	_scene_item_cont.visible = false
	_update_header_icon()


func set_header_visible(visible: bool) -> void:
	_button_header.visible = visible


func _update_header_icon() -> void:
	_button_header.icon = _OPEN_ICON if _is_open else _CLOSE_ICON


func toggle_expand() -> void:
	if _is_open:
		close()
	else:
		open()
