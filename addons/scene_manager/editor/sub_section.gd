@tool
class_name SMgrSubSection
extends Control

const OPEN_ICON = preload("res://addons/scene_manager/icons/GuiOptionArrowDown.svg")
const CLOSE_ICON = preload("res://addons/scene_manager/icons/GuiOptionArrowRight.svg")

var _is_closable: bool = true
var _header_visible: bool = true
var _is_open: bool = true

@onready var _button_header: Button = %Button
@onready var _scene_item_cont: VBoxContainer = %SceneItemContainer


func _ready() -> void:
	_button_header.text = name
	_button_header.visible = _header_visible
	# Update the icon according to the initial state
	_update_header_icon()
	visible = true


func setup(name_a: String) -> void:
	name = name_a


## Add child to the sub section list
func add_item(item: SMgrSceneItem) -> void:
	item.set_subsection(self)
	_scene_item_cont.add_child(item)


## Removes an item from sub section list
func remove_item(item: SMgrSceneItem) -> void:
	item.set_subsection(null)
	_scene_item_cont.remove_child(item)


func get_item(scene_name: String) -> SMgrSceneItem:
	for child: SMgrSceneItem in _scene_item_cont.get_children():
		if child.get_scene_name() == scene_name:
			return child

	return null


## Retrieves the raw list container.
func get_list_container() -> VBoxContainer:
	return _scene_item_cont


func open() -> void:
	_is_open = true
	_scene_item_cont.visible = true
	_update_header_icon()


func close() -> void:
	_is_open = false
	_scene_item_cont.visible = false
	_update_header_icon()


# Returns list of items
func get_items() -> Array:
	return _scene_item_cont.get_children()


## Bulk update icon display state based on internal flags
func _update_header_icon() -> void:
	if not is_inside_tree():
		# Prevent errors immediately after instantiation
		return

	if not _is_closable:
		_button_header.icon = null
		return

	_button_header.icon = OPEN_ICON if _is_open else CLOSE_ICON


# Handler when button is pressed
func _on_button_up() -> void:
	if _is_closable:
		if _is_open:
			close()
		else:
			open()


## Sets whether or not the subsection can close.
func set_closable(can_close: bool) -> void:
	_is_closable = can_close
	_update_header_icon()


## Sets whether or not the button on top for the sub section is visible.
func set_header_visible(visible_state: bool) -> void:
	_header_visible = visible_state
	_button_header.visible = _header_visible
