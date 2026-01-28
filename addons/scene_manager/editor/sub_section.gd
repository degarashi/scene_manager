@tool
class_name SMgrSubSection
extends Control

const SUBSECTION_OPEN_ICON = preload("res://addons/scene_manager/icons/GuiOptionArrowDown.svg")
const SUBSECTION_CLOSE_ICON = preload("res://addons/scene_manager/icons/GuiOptionArrowRight.svg")
const SCENE_ITEM = preload("res://addons/scene_manager/editor/scene_item.tscn")

var _main_panel: SMgrMainPanel
var _is_closable: bool = true
var _header_visible: bool = true

@onready var _button_header: Button = %Button
@onready var _delete_button: Button = %Delete
@onready var _list: VBoxContainer = %List


func _ready() -> void:
	_button_header.text = name
	_button_header.visible = _header_visible
	visible = true


func setup(main_panel: SMgrMainPanel, name_a: String) -> void:
	_main_panel = main_panel
	name = name_a


## Add child to the sub section list
func add_item(item: Node) -> void:
	item.set_subsection(self)
	_list.add_child(item)


## Removes an item from sub section list
func remove_item(item: Node) -> void:
	item.set_subsection(null)
	_list.remove_child(item)


## Retrieves an item from the sub section list that matches the key.[br]
## Returns null if the item isn't found.[br]
## The node returned is a scene_item.
func get_item(key: String) -> Node:
	for child in _list.get_children():
		if child.get_key() == key:
			return child

	return null


## Retrieves the raw list container.
func get_list_container() -> VBoxContainer:
	return _list


# Open list
func open() -> void:
	_list.visible = true
	_button_header.icon = SUBSECTION_OPEN_ICON


# Close list
func close() -> void:
	_list.visible = false
	_button_header.icon = SUBSECTION_CLOSE_ICON


# Returns list of items
func get_items() -> Array:
	return _list.get_children()


# Close Open Functionality
func _on_button_up():
	if _is_closable:
		if _button_header.icon == SUBSECTION_OPEN_ICON:
			close()
		else:
			open()


# Action on child counting
func _check_count():
	if _list.get_child_count() == 0:
		if name == "All":
			visible = false
		else:
			enable_delete_button(true)
	else:
		if name == "All":
			visible = true
		else:
			enable_delete_button(false)


# When a node adds
func child_entered():
	_check_count()


# When a node removes
func child_exited():
	_check_count()


## Enables/disables the delete button for deleting the sub section.
func enable_delete_button(enable: bool) -> void:
	_delete_button.disabled = not enable


## Sets whether or not to make the delete button visible.
func set_delete_visible(visible: bool) -> void:
	_delete_button.visible = visible


## Sets whether or not the subsection can close.
func set_closable(can_close: bool) -> void:
	_is_closable = can_close

	if _is_closable:
		_button_header.icon = SUBSECTION_OPEN_ICON if _list.visible else SUBSECTION_CLOSE_ICON
	else:
		_button_header.icon = null


## Sets whether or not the button on top for the sub section is visible.
func set_header_visible(visible: bool) -> void:
	_header_visible = visible
	_button_header.visible = _header_visible


# Button Delete
func _on_delete_button_up():
	queue_free()
	await self.tree_exited
	# _main_panel.sub_section_removed.emit(self)
