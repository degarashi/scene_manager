@tool
class_name SMgrSceneList
extends Control

signal section_removed(section_name: String)
signal req_check_duplication(scene_name: String, sc_list: Node)

# Scene item and sub_section to instance and add in list
const SCENE_ITEM = preload("res://addons/scene_manager/editor/scene_item.tscn")
const SUB_SECTION = preload("res://addons/scene_manager/editor/sub_section.tscn")
const C = preload("uid://c3vvdktou45u")


class SectionName:
	const UNCATEGORIZED = "Uncategorized"
	const CATEGORIZED = "Categorized"


# ALL_SECTION_NAME subsection by default.
# In the ALL_SECTION_NAME list, this is "Uncategorized" items
var _main_subsection: SMgrSubSection
# Mainly used for the default ALL_SECTION_NAME list for "Categorized" items
var _secondary_subsection: SMgrSubSection

# Container containing sub section
@onready var _subsection_cont: VBoxContainer = %container
@onready var _delete_list_button: Button = %delete_list
@onready var _save_label: Label = %save_label


func setup(name_a: String) -> void:
	name = name_a


func _ready() -> void:
	if name == C.ALL_SECTION_NAME:
		_delete_list_button.icon = null
		_delete_list_button.disabled = true
		_delete_list_button.visible = false
		_delete_list_button.focus_mode = Control.FOCUS_NONE

		var sub: SMgrSubSection = SUB_SECTION.instantiate()
		sub.setup(SectionName.UNCATEGORIZED)
		_subsection_cont.add_child(sub)
		sub.open()
		_main_subsection = sub

		var sub2: SMgrSubSection = SUB_SECTION.instantiate()
		sub2.setup(SectionName.CATEGORIZED)
		_subsection_cont.add_child(sub2)
		sub2.open()
		_secondary_subsection = sub2
	else:
		var sub: SMgrSubSection = SUB_SECTION.instantiate()
		sub.setup(C.ALL_SECTION_NAME)
		sub.visible = false
		_subsection_cont.add_child(sub)
		sub.open()
		sub.set_header_visible(false)
		_main_subsection = sub

	_save_label.visible = false


# Callback from the on_changed(SceneItem) signal in the scene_item
func _on_item_changed(sc_name: String) -> void:
	req_check_duplication.emit(sc_name, self)


func add_item(scene_name: String, scene_path: String, categorized: bool = false) -> void:
	if not is_node_ready():
		await ready

	var item: SMgrSceneItem = SCENE_ITEM.instantiate()
	item.set_scene_name(scene_name)
	item.set_scene_path(scene_path)
	# --- connect signals ---
	item.on_changed.connect(_on_item_changed)
	item.on_reset.connect(_reset_theme_all)
	# ---

	# For the default All case, determine which sub category it goes into
	if name == C.ALL_SECTION_NAME and categorized:
		_secondary_subsection.add_item(item)
	else:
		_main_subsection.add_item(item)


## Updates whether or not the item is categorized and moves it to the correct subcategory.[br]
## Used for the default ALL_SECTION_NAME list.
func update_item_categorized(key: String, categorized: bool) -> void:
	# Make sure this is the correct list
	if name != C.ALL_SECTION_NAME:
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
	for section in _get_subsections():
		# We want to get the list, which will be the second child in the sub section
		var list := section.get_child(1)
		var nodes := list.get_children()

		# Find the node we're looking for to replace
		# The node is a scene_item.
		for node: SMgrSceneItem in nodes:
			if node.get_scene_name() == old_key:
				node.set_scene_name(new_key)
				_sort_node_list(list)
				break


## Removes an item from list
func remove_item(key: String, value: String) -> void:
	for sec in _get_subsections():
		for item in sec.get_items():
			if item.get_scene_name() == key && item.get_scene_path() == value:
				item.queue_free()
				return


## Clear all scene records from UI list
func clear_list() -> void:
	for sec in _get_subsections():
		sec.queue_free()


## Sort the scenes in all the subsections alphabetically based on the scene key name.
func sort_scenes() -> void:
	for sec in _get_subsections():
		# We want to get the list, which will be the second child in the sub section
		var list := sec.get_list_container()
		_sort_node_list(list)


# Internal helper method to sort a list of nodes under a given parent.
func _sort_node_list(parent: Node) -> void:
	var sorted_nodes := parent.get_children()
	sorted_nodes.sort_custom(
		func(a: SMgrSceneItem, b: SMgrSceneItem):
			return a.get_scene_name().naturalnocasecmp_to(b.get_scene_name()) < 0
	)

	for i in range(sorted_nodes.size()):
		if sorted_nodes[i].get_index() != i:
			parent.move_child(sorted_nodes[i], i)


func _reset_theme_all() -> void:
	for sec in _get_subsections():
		for c in sec.get_items():
			c.remove_custom_theme()


func check_duplication(sc_name: String) -> void:
	for sec in _get_subsections():
		for c: SMgrSceneItem in sec.get_items():
			c.is_valid = c.get_scene_name() != sc_name


func _get_subsections() -> Array[SMgrSubSection]:
	var ret: Array[SMgrSubSection] = []
	for c in _subsection_cont.get_children():
		ret.append(c)
	return ret


## Sets whether or not to display there's unsaved changes.
func set_changes_unsaved(changes: bool) -> void:
	_save_label.visible = changes


# List deletion
func _on_delete_list_button_up() -> void:
	var section_name := name
	if name == C.ALL_SECTION_NAME:
		return
	queue_free()
	await tree_exited
	section_removed.emit(section_name)
