@tool
class_name SMgrSceneList
extends Control

signal section_removed(section_name: String)
signal req_check_duplication(key: String, node: Node)

signal on_scene_renamed(old_name: String, new_name: String)
signal remove_scene_from_list(section_name: String, scene_name: String, scene_address: String)
signal item_added_to_list(node: Node, list_name: String)
signal item_removed_from_list(node: Node, list_name: String)
signal add_scene_to_list(
	list_name: String, scene_name: String, scene_address: String, categorized: bool
)

const F = preload("uid://cpxe18s2130m8")
# Scene item and sub_section to instance and add in list
const SCENE_ITEM = preload("res://addons/scene_manager/editor/scene_item.tscn")
const SUB_SECTION = preload("res://addons/scene_manager/editor/sub_section.tscn")
const ALL_LIST_NAME := "All"


class SectionName:
	const UNCATEGORIZED = "Uncategorized"
	const CATEGORIZED = "Categorized"


# "All" subsection by default. In the "All" list, this is "Uncategorized" items
var _main_subsection: SMgrSubSection
# Mainly used for the default "All" list for "Categorized" items
var _secondary_subsection: SMgrSubSection

@onready var _container: VBoxContainer = %container
@onready var _delete_list_button: Button = %delete_list
@onready var _save_label: Label = %save_label


func _on_scene_renamed(old_name: String, new_name: String) -> void:
	on_scene_renamed.emit(old_name, new_name)


func _on_remove_scene_from_list(
	section_name: String, scene_name: String, scene_address: String
) -> void:
	remove_scene_from_list.emit(section_name, scene_name, scene_address)


func _on_item_added_to_list(node: Node, list_name: String) -> void:
	item_added_to_list.emit(node, list_name)


func _on_item_removed_from_list(node: Node, list_name: String) -> void:
	item_removed_from_list.emit(node, list_name)


func _on_add_scene_to_list(
	list_name: String, scene_name: String, scene_address: String, categorized: bool
) -> void:
	add_scene_to_list.emit(list_name, scene_name, scene_address, categorized)


# Start up of `All` list
func _ready() -> void:
	if name == ALL_LIST_NAME:
		_delete_list_button.icon = null
		_delete_list_button.disabled = true
		_delete_list_button.visible = false
		_delete_list_button.focus_mode = Control.FOCUS_NONE

		var sub: SMgrSubSection = SUB_SECTION.instantiate()
		sub.setup(SectionName.UNCATEGORIZED)
		_container.add_child(sub)
		sub.open()
		sub.enable_delete_button(false)
		sub.set_delete_visible(false)
		_main_subsection = sub

		var sub2: SMgrSubSection = SUB_SECTION.instantiate()
		sub2.setup(SectionName.CATEGORIZED)
		_container.add_child(sub2)
		sub2.enable_delete_button(false)
		sub2.set_delete_visible(false)
		_secondary_subsection = sub2
	else:
		var sub: SMgrSubSection = SUB_SECTION.instantiate()
		sub.setup(ALL_LIST_NAME)
		sub.visible = false
		_container.add_child(sub)
		sub.open()
		sub.set_header_visible(false)
		sub.enable_delete_button(false)
		sub.set_delete_visible(false)
		_main_subsection = sub

	_save_label.visible = false


## Adds an item to list
func add_item(key: String, value: String, categorized: bool = false) -> void:
	if not is_node_ready():
		await ready

	var item: SMgrSceneItem = SCENE_ITEM.instantiate()
	item.set_key(key)
	item.set_value(value)
	# --- connect signals ---
	item.key_changed.connect(_on_item_key_changed)
	item.key_reset.connect(set_reset_theme_for_all)
	item.scene_renamed.connect(_on_scene_renamed)
	item.remove_scene_from_list.connect(_on_remove_scene_from_list)
	item.item_added_to_list.connect(_on_item_added_to_list)
	item.item_removed_from_list.connect(_on_item_removed_from_list)
	item.add_scene_to_list.connect(_on_add_scene_to_list)
	# ---

	item._list = self

	# For the default All case, determine which sub category it goes into
	if name == ALL_LIST_NAME and categorized:
		_secondary_subsection.add_item(item)
	else:
		_main_subsection.add_item(item)


## Updates whether or not the item is categorized and moves it to the correct subcategory.[br]
## Used for the default "All" list.
func update_item_categorized(key: String, categorized: bool) -> void:
	# Make sure this is the correct list
	if name != ALL_LIST_NAME:
		push_warning(
			"Cannot set categorization in a list other than All (attempting to set in %s)" % name
		)
		return

	# Find the item in the sub sections.
	var item := _main_subsection.get_item(key)
	if item:
		# If the item is already not categorized, then nothing needs to be done
		if not categorized:
			return

		# Otherwise, the item should go into the "Categorized"
		_main_subsection.remove_item(item)
		_secondary_subsection.add_item(item)
		_sort_node_list(_secondary_subsection.get_list_container())
		return

	item = _secondary_subsection.get_item(key)
	if item:
		# If it's already categorized, nothing needs to be done
		if categorized:
			return

		# Otherwise, the item should go into the "Uncategorized"
		_secondary_subsection.remove_item(item)
		_main_subsection.add_item(item)
		_sort_node_list(_main_subsection.get_list_container())
		return


## Updates the item key with the new key.
func update_item_key(old_key: String, new_key: String) -> void:
	# Find the item in the different subsections and update them
	for section in _container.get_children():
		# We want to get the list, which will be the second child in the sub section
		var list := section.get_child(1)
		var nodes := list.get_children()

		# Find the node we're looking for to replace
		# The node is a scene_item.
		for node in nodes:
			if node.get_key() == old_key:
				node.set_key(new_key)
				_sort_node_list(list)
				break


## Finds and returns a sub_section in the list
func find_subsection(key: String) -> Node:
	for element in _container.get_children():
		if element.name == key:
			return element
	return null


## Removes an item from list
func remove_item(key: String, value: String) -> void:
	for scene_item in _container.get_children():
		for item in scene_item.get_items():
			if item.get_key() == key && item.get_value() == value:
				item.queue_free()
				return


## Removes items that their value begins with passed value
func remove_items_begins_with(value: String) -> void:
	for i in range(_container.get_child_count()):
		var children: Array = _container.get_child(i).get_items()
		for j in range(len(children)):
			if children[j].get_value().begins_with(value):
				children[j].queue_free()


## Clear all scene records from UI list
func clear_list() -> void:
	for scene_item in _container.get_children():
		scene_item.queue_free()


## Appends all scenes into UI list[br]
##
## This function is used for new items that are new in project directory and are
## not saved before, so they have no settings.[br]
##
## Input example:
## {"scene_key": "scene_address", "scene_key": "scene_address", ...}
func append_scenes(nodes: Dictionary) -> void:
	for key in nodes:
		add_item(key, nodes[key])


## Sort the scenes in all the subsections alphabetically based on the scene key name.
func sort_scenes() -> void:
	for section in _container.get_children():
		# We want to get the list, which will be the second child in the sub section
		var list = section.get_list_container()
		_sort_node_list(list)


# Internal helper method to sort a list of nodes under a given parent.
func _sort_node_list(parent: Node) -> void:
	var sorted_nodes := parent.get_children()
	sorted_nodes.sort_custom(
		func(a: Node, b: Node): return a.get_key().naturalnocasecmp_to(b.get_key()) < 0
	)

	for i in range(sorted_nodes.size()):
		if sorted_nodes[i].get_index() != i:
			parent.move_child(sorted_nodes[i], i)


## Return an array of record nodes from UI list
func get_list_nodes() -> Array:
	if _container == null:
		_container = %container

	var arr: Array[Node] = []
	for scene_item in _container.get_children():
		var nodes = scene_item.get_items()
		arr.append_array(nodes)
	return arr


## Returns a specific node from passed scene name
func get_node_by_scene_name(scene_name: String) -> Node:
	for scene_item in _container.get_children():
		for item in scene_item.get_items():
			if item.get_key() == scene_name:
				return item
	return null


## Returns a specific node from passed scene address
func get_node_by_scene_address(scene_address: String) -> Node:
	for scene_item in _container.get_children():
		for item in scene_item.get_items():
			if item.get_value() == scene_address:
				return item
	return null


## Update a specific scene record with passed data in UI
func update_scene_with_key(key: String, new_key: String, value: String) -> void:
	for i in range(_container.get_child_count()):
		for item in _container.get_children():
			if item.get_key() == key && item.get_value() == value:
				item.set_key(new_key)


## Reset theme for all children in UI
func set_reset_theme_for_all() -> void:
	for list_child in _container.get_children():
		for c in list_child.get_items():
			c.remove_custom_theme()


func update_validity(key: String) -> void:
	for list_child in _container.get_children():
		for c in list_child.get_items():
			c.is_valid = c.get_key() != key


## Sets whether or not to display there's unsaved changes.
func set_changes_unsaved(changes: bool) -> void:
	_save_label.visible = changes


## Returns all names of sublist
func get_all_sublists() -> Array:
	var arr: Array[String] = []
	for list_child in _container.get_children():
		arr.append(list_child.name)
	return arr


## Adds a subsection
func add_subsection(text: String) -> Control:
	var sub: SMgrSubSection = SUB_SECTION.instantiate()
	sub.setup(text.capitalize())
	_container.add_child(sub)
	return sub


# List deletion
func _on_delete_list_button_up() -> void:
	var section_name = name
	if name == "All":
		return
	queue_free()
	await tree_exited
	section_removed.emit(section_name)


# Callback from the key_changed signal in the scene_item
func _on_item_key_changed(key: String) -> void:
	req_check_duplication.emit(key, self)
