@tool
class_name AutoCompleteAssistant
extends Node

# [auto_complete_menu.tscn]
var complete_menu = preload("uid://cebls7f645328")

## The line_edit nodes this node should spawn menus for
@export var line_edits: Array[LineEdit]
## One option to load terms
@export var terms: Array[String]
## Defines in which node the menu should be located. [br]
## This node has to contain the line_edit(s) you want it to appear for. [br]
## Not necessarily as a parent but the edits must intersect with its global_rect
## since the menu will not cut out of this nodes boundaries
@export var menu_location_node: Control
## Special case if the auto complete will be used in the editor inspector. In this case,
## the menu_location_node won't be known in advance since it depends on the editor window
## the autocomplete will show up. Instead, it will grab the parent that the line edit is
## attached to.
@export var is_editor_inspector: bool = false
## String path to json file holding the terms
@export var terms_file_path: String
## If terms json is a dict, per default if this is undefined the programm will try to access "terms"
## to get the terms. If you want to put different sets of terms for different edits in one file,
## you can define the key that is used to access with this.
@export var terms_dict_key: String = "terms"
## Whether or not the autocomplete will search based on an exact string match or only on characters
## and disregard case.
@export var case_sensitive_match: bool = true
@export_group("Menu Transform Settings")
@export var margin: float = 0
@export var size_min: Vector2 = Vector2(100, 0)
@export var size_mult: Vector2 = Vector2(1, 4)

@export_group("Disabled Menu Directions")
@export var disable_north: bool
@export var disable_east: bool
@export var disable_south: bool
@export var disable_west: bool

var menus: Array[AutoCompleteMenu]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for edit in line_edits:
		create_complete_menu(edit)


func create_complete_menu(edit: LineEdit) -> void:
	# 0 is main direction as int (from enum) 1 is sub-direction
	#   so if north or south greater (for east-west) is max_size vector
	var location_info = get_location_boundaries(edit)
	if location_info.size() == 0:
		return

	var direction = location_info[0]
	var placement_point = get_menu_placement_vec(edit, direction)
	var new_menu: AutoCompleteMenu = complete_menu.instantiate()
	add_child(new_menu)
	new_menu.set_transform_values(margin, size_min, size_mult)
	new_menu.set_up_menu(
		placement_point, direction, location_info[1], location_info[2], edit, case_sensitive_match
	)
	insert_terms(new_menu)

	edit.connect("focus_entered", new_menu.show_menu)
	edit.connect("focus_exited", new_menu.hide_menu)
	menu_location_node.connect("resized", new_menu.resize)
	new_menu.connect("resized", new_menu.resize)

	new_menu.hide_menu(true)


func insert_terms(menu: AutoCompleteMenu) -> void:
	var new_terms = terms

	if terms_file_path:
		var file = FileAccess.open(terms_file_path, FileAccess.READ)
		if not file:
			assert(false, "ERROR: terms file path is invalid!")
			return
		var content = file.get_as_text()
		file.close()
		var json_object = JSON.parse_string(content)
		if typeof(json_object) == TYPE_ARRAY:
			new_terms += json_object
		elif typeof(json_object) == TYPE_DICTIONARY:
			new_terms += json_object[terms_dict_key]

	menu.load_terms(new_terms)


## Calculates the free space available in all 4 directions of the LineEdit rect
## and the menu_location_node rect.[br]
## If successful it returns a dictionary with the values
func get_location_boundaries(edit: LineEdit) -> Array:
	var disable_direction_arr = [disable_north, disable_east, disable_south, disable_west]

	# If this autocomplete is part of the inspector view, keep going up the tree until we find the
	# inspector panel.
	if is_editor_inspector and edit != null:
		menu_location_node = edit.get_parent_control()
		while menu_location_node != null and menu_location_node.name != "Inspector":
			menu_location_node = menu_location_node.get_parent_control()

	if not menu_location_node or not edit:
		# If the menu location is still null and we're in the inspector, quietly quit as
		# it may not be ready yet and we don't want to show errors in the output.
		if not is_editor_inspector:
			assert(false, "ERROR: NODE CONFIGURATION ERROR; LOCATION_NODE OR EDIT_NODE ARE NULL!")
		return []

	var location_rect = menu_location_node.get_global_rect()
	var edit_rect = edit.get_global_rect()
	if not location_rect.intersects(edit_rect):
		# Same thing for the rectangle check as the inspector may be setting things up
		# or have stale values.
		if not is_editor_inspector:
			assert(false, "ERROR: NODE CONFIGURATION ERROR; EDIT NOT WITHIN LOCATION_NODE")
		return []

	var direction_rects = AutoCompleteHelpers.subtract_rects(location_rect, edit_rect)
	var values = direction_rects["Values"]
	var max_value = 0
	var max_index = 0
	for i in values.size():
		var current_rect = values[i]
		if max_value <= current_rect.get_area() and not disable_direction_arr[i]:
			max_value = current_rect.get_area()
			max_index = i

	var max_size = direction_rects["Values"][max_index].size
	if max_index == 0 or max_index == 2:
		max_size.x = (location_rect.size - (edit_rect.position - location_rect.position)).x
	else:
		max_size.y = (location_rect.size - (edit_rect.position - location_rect.position)).y
	var vertical_direction = (
		AutoCompleteEnums.Direction.NORTH
		if values[0].size.y > values[2].size.y
		else AutoCompleteEnums.Direction.SOUTH
	)

	return [
		AutoCompleteEnums.Direction[direction_rects.keys()[max_index]], vertical_direction, max_size
	]


func get_menu_placement_vec(edit: LineEdit, direction) -> Vector2:
	var edit_rect = edit.get_global_rect()
	var return_vec: Vector2
	match direction:
		AutoCompleteEnums.Direction.EAST:
			return_vec = Vector2(edit_rect.end.x, edit_rect.position.y)
		AutoCompleteEnums.Direction.SOUTH:
			return_vec = Vector2(edit_rect.position.x, edit_rect.end.y)
		_:
			return_vec = edit_rect.position

	# TODO: add margins or stuff
	return return_vec


## Loads new terms into all menus.[br]
## If [param override] is set to true, all prior loaded terms will be forgotten
func load_terms(new_terms: Array, override: bool = false) -> void:
	if override:
		terms = new_terms
	else:
		terms.append_array(new_terms)

	for menu in menus:
		menu.load_terms(new_terms, override)


## Adds new [param edit] and creates a menu for it
func add_edit(edit: LineEdit) -> void:
	if not edit in line_edits:
		line_edits.append(edit)
		create_complete_menu(edit)
	else:
		assert(false, "ERROR: trying to add new edit which already has a complete menu")


## Removes an [param edit] and its menu if it exists.
## Will not remove the edit node from the scene just its connection to this node.
func remove_edit(edit: LineEdit) -> void:
	if edit in line_edits:
		for menu in menus:
			if menu.edit == edit:
				menu.queue_free()
				line_edits.remove_at(line_edits.find(edit))
	else:
		assert(false, "ERROR: trying to remove an edit that has no complete menu")
