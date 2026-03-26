@tool
class_name AutoCompleteMenu
extends Control

# ------------- [Public Variable] -------------
var visible_nodes: Array[Control]  ## All the term-nodes that are currently visible
var all_nodes: Array[Control]  ## All the term nodes, one for each term
var edit: LineEdit  ## The edit this menu applies to
var case_sensitive: bool  ## Whether or not the comparison will be case sensitive

## Defines the size of the menu, in relation to the edit[br]
## If this was (1,1) the menu would have the same size as the edit
var size_mult := Vector2(1, 4)
var size_min := Vector2(100, 0)
var edit_margin: int = 0
var node_margin_y: float = 3.0
var node_size: float:
	get:
		var size_y: float = 0
		for node in visible_nodes:
			size_y += node.size.y
		size_y += (visible_nodes.size()) * node_margin_y
		return size_y
var anchor_point: Vector2  ## Position is calculated relative to edit by resize
var main_direction: AutoCompleteEnums.Direction  ## Main menu direction
var max_size: Vector2
var grow_upwards: bool = false

## The text that is currently checked. Not entire edit text if whitespaces are there
var current_text: String = ""
var all_active_terms: Array = []  ## All loaded terms in one array

# ------------- [Private Variable] -------------
#region control_vars
var is_in_focus: bool
var is_in_selection: bool
#endregion

# [auto_complete_option.tscn]
var option_scene := preload("uid://rphyeuffx7cl")
@onready var option_holder: Control = $ScrollContainer/OptionHolder
@onready var scroll_container: ScrollContainer = $ScrollContainer


# ------------- [Callbacks] -------------
## Makes it so the optionmenu can be navigated with the arrow keys,
##   by interrupting default lineEdit key behavior
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var select_nav_button := "ui_up" if grow_upwards else "ui_down"
		var back_nav_button := "ui_down" if grow_upwards else "ui_up"
		var edit_focus_neighbor: NodePath = (
			edit.focus_neighbor_top if grow_upwards else edit.focus_neighbor_bottom
		)

		if event.is_action_pressed(select_nav_button) and not is_in_selection and visible_nodes:
			get_viewport().set_input_as_handled()
			is_in_selection = true
			get_node(edit_focus_neighbor).grab_focus()

		if event.is_action_pressed(back_nav_button) and is_in_selection:
			is_in_selection = false

	if event is InputEventMouseButton:
		if event.is_released():
			if not (
				get_global_rect().has_point(get_global_mouse_position())
				or edit.get_global_rect().has_point(get_global_mouse_position())
			):
				edit.release_focus()


# ------------- [Private Method] -------------
func calc_anchor_point() -> void:
	match main_direction:
		AutoCompleteEnums.Direction.NORTH:
			anchor_point = edit.global_position - Vector2(0, get_rect().size.y + edit_margin)
		AutoCompleteEnums.Direction.EAST:
			anchor_point = Vector2(
				edit.get_global_rect().end.x + edit_margin, edit.global_position.y
			)
			anchor_point.y -= (get_rect().size.y - edit.size.y) if grow_upwards else 0.0
		AutoCompleteEnums.Direction.SOUTH:
			anchor_point = Vector2(
				edit.global_position.x, edit.get_global_rect().end.y + edit_margin
			)
		AutoCompleteEnums.Direction.WEST:
			anchor_point = Vector2(
				edit.global_position.x - get_rect().size.x - edit_margin, edit.global_position.y
			)
			anchor_point.y -= (get_rect().size.y - edit.size.y) if grow_upwards else 0.0


## Positions the nodes, based on the order they are given
func reposition_nodes(ordered_nodes: Array[Control]) -> void:
	visible_nodes = ordered_nodes
	var holder_size := node_size
	# used instead of if-else everytime addition/subtraction is used
	var grow_indicator := -1 if grow_upwards else 1
	option_holder.set_custom_minimum_size(Vector2(0, holder_size))
	var current_position := Vector2(0, holder_size) if grow_upwards else Vector2(0, 0)
	for node: Control in ordered_nodes:
		node.set_deferred("position", current_position)
		node.set_deferred("position.y", node.position.y - node.size.y if grow_upwards else 0.0)
		node.set_deferred("size.x", option_holder.size.x)
		current_position.y += grow_indicator * (node.size.y + node_margin_y)


## Applies the [param text] chosen in the menu to the edits text[br]
## Is called by the option_chosen signal in the option_button
func on_option_chosen(text: String) -> void:
	edit.text = text
	edit.grab_focus()
	edit.caret_column = text.length()

	# Special case: If the edit is a SceneLineEdit, then we also need to alert it to the change
	if edit is SceneLineEdit:
		edit.text_changed.emit(edit.text)

	hide_menu(true)


func get_option_text(option: Control) -> String:
	# If case sensitivity is off, then normalize this to lower case
	if case_sensitive:
		return option.get_node("CompleteText").text
	return option.get_node("CompleteText").text.to_lower()


func compare_options(a: Control, b: Control) -> bool:
	var a_text := get_option_text(a)
	var b_text := get_option_text(b)

	var score := 0
	score = b_text.length() - a_text.length()

	if case_sensitive:
		score += b_text.find(current_text) - a_text.find(current_text)
	else:
		score += (
			b_text.to_lower().find(current_text.to_lower())
			- a_text.to_lower().find(current_text.to_lower())
		)

	return score > 0


# ------------- [Public Method] -------------
func set_up_menu(
	placement_point: Vector2,
	direction_main: AutoCompleteEnums.Direction,
	direction_sub: AutoCompleteEnums.Direction,
	maximum_size: Vector2,
	line_edit: LineEdit,
	case_sensitive_match: bool
) -> void:
	edit = line_edit
	main_direction = direction_main
	anchor_point = placement_point
	grow_upwards = direction_sub == AutoCompleteEnums.Direction.NORTH
	case_sensitive = case_sensitive_match

	max_size = maximum_size
	resize(edit.size * size_mult)

	edit.text_changed.connect(refresh_nodes)
	refresh_nodes("")


## Loads the [param terms] as new option nodes [br]
## If [param override_terms] is true all the prior existing terms are removed
func load_terms(terms: Array, override_terms: bool = false) -> void:
	if override_terms:
		remove_terms(all_active_terms)

	for term: String in terms:
		if term in all_active_terms:
			continue
		var option: Control = option_scene.instantiate()
		option_holder.add_child(option)
		option.get_node("CompleteText").text = term
		option.get_node("Button").option_chosen.connect(on_option_chosen)
		all_nodes.append(option)

	all_active_terms.append_array(terms)
	refresh_nodes(current_text)


func remove_terms(terms: Array) -> void:
	var remove_nodes: Array[Control] = []
	for node: Control in all_nodes:
		if get_option_text(node) in terms:
			remove_nodes.append(node)

	visible_nodes = visible_nodes.filter(func(x: Control): return not x in remove_nodes)
	all_nodes = all_nodes.filter(func(x: Control): return not x in remove_nodes)
	all_active_terms = all_active_terms.filter(func(x: String): return not x in terms)
	for node: Control in remove_nodes:
		node.get_node("Button").option_chosen.disconnect(on_option_chosen)
		node.queue_free()

	refresh_nodes(current_text)


## Recalculates size and position
func resize(new_size: Vector2 = Vector2.INF) -> void:
	if new_size == Vector2.INF:
		new_size = Vector2(edit.size.x * size_mult.x, min(edit.size.y * size_mult.y, node_size))
		new_size = size_min.max(new_size)

	if max_size:
		set_deferred("size", max_size.min(new_size))
	else:
		set_deferred("size", new_size)

	calc_anchor_point()
	set_deferred("position", anchor_point)


## Sorts the nodes anew based on the new text and calls the reposition method
func refresh_nodes(text: String) -> void:
	# Normalize the text if case sensitivity is off
	if not case_sensitive:
		text = text.to_lower()

	var terms := text.split(" ")
	var t_length := 0
	var whitespace_i := 0
	# split up the currently selection completion term by whitespaces
	for term in terms:
		t_length += term.length()
		if t_length + whitespace_i >= edit.caret_column:
			text = term
			break
		whitespace_i += 1
	current_text = text

	if text.is_empty():
		visible_nodes = all_nodes
	else:
		visible_nodes = all_nodes.filter(func(x: Control): return text in get_option_text(x))
		for node: Control in all_nodes.filter(
			func(x: Control): return not text in get_option_text(x)
		):
			node.visible = false

	visible_nodes.assign(
		visible_nodes.map(
			func(x: Control) -> Control:
				x.visible = true
				return x,
		)
	)
	visible_nodes.sort_custom(compare_options)

	reposition_nodes(visible_nodes)
	if grow_upwards:
		scroll_container.set_deferred(
			"scroll_vertical", scroll_container.get_v_scroll_bar().max_value
		)

	resize()
	if visible_nodes:
		if grow_upwards:
			edit.focus_neighbor_top = visible_nodes[0].get_node("Button").get_path()
			visible_nodes[0].get_node("Button").focus_neighbor_bottom = edit.get_path()
		else:
			edit.focus_neighbor_bottom = visible_nodes[0].get_node("Button").get_path()
			visible_nodes[0].get_node("Button").focus_neighbor_top = edit.get_path()

	show_menu(false)


func show_menu(refresh: bool = true) -> void:
	self.visible = true
	if refresh:
		refresh_nodes(current_text)

	is_in_focus = true
	is_in_selection = false


func hide_menu(override: bool = false) -> void:
	if is_in_selection and not override:
		return
	if get_global_rect().has_point(get_global_mouse_position()) and not override:
		return

	self.visible = false
	is_in_focus = false


func set_transform_values(margin: float, min_size: Vector2, mult_size: Vector2) -> void:
	if margin:
		edit_margin = int(margin)
	if min_size:
		size_min = min_size
	if mult_size:
		size_mult = mult_size
