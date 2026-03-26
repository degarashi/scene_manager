class_name AutoCompleteHelpers
extends Object

# ------------- [Constants] -------------
const AUTO_DIRECTION_STRINGS: Array[String] = ["NORTH", "EAST", "SOUTH", "WEST"]


# ------------- [Public Static Method] -------------
## Subtracts a [param sub_rect] from a [param base_rect]
##   and returns a dict of up to 4 new rects around the subtracted rect.
static func subtract_rects(base_rect: Rect2, sub_rect: Rect2) -> Dictionary:
	var return_dict := {}
	var direction_rects: Array[Rect2] = [Rect2(), Rect2(), Rect2(), Rect2()]

	# Calculate the rectangles around the directions following the AUTO_DIRECTION_STRINGS constant
	# NORTH
	var top_height := sub_rect.position.y - base_rect.position.y
	direction_rects[0].position = base_rect.position
	direction_rects[0].size = Vector2(base_rect.size.x, top_height).max(Vector2(0, 0))
	return_dict[AUTO_DIRECTION_STRINGS[0]] = direction_rects[0]

	# EAST
	var right_width := (
		base_rect.position.x - sub_rect.position.x + base_rect.size.x - sub_rect.size.x
	)
	direction_rects[1].position = Vector2(
		base_rect.position.x + base_rect.size.x - right_width, base_rect.position.y
	)
	direction_rects[1].size = Vector2(right_width, base_rect.size.y).max(Vector2(0, 0))
	return_dict[AUTO_DIRECTION_STRINGS[1]] = direction_rects[1]

	# SOUTH
	var bottom_pos_y := top_height + sub_rect.size.y
	direction_rects[2].position = Vector2(base_rect.position.x, base_rect.position.y + bottom_pos_y)
	direction_rects[2].size = Vector2(base_rect.size.x, base_rect.size.y - bottom_pos_y).max(
		Vector2(0, 0)
	)
	return_dict[AUTO_DIRECTION_STRINGS[2]] = direction_rects[2]

	# WEST
	var left_width := sub_rect.position.x - base_rect.position.x
	direction_rects[3].position = base_rect.position
	direction_rects[3].size = Vector2(left_width, base_rect.size.y).max(Vector2(0, 0))
	return_dict[AUTO_DIRECTION_STRINGS[3]] = direction_rects[3]

	return_dict["Values"] = direction_rects  # add final rect array to return_dict
	return return_dict


## Debuging collection by printing everything in it.
static func print_collection(
	collection: Variant,
	name: String = "Collection",
	add_separator: bool = false,
	sep_max: int = 100
) -> void:
	var type_collection := typeof(collection)
	if type_collection != TYPE_ARRAY and type_collection != TYPE_DICTIONARY:
		assert(false, "ERROR: ONLY ACCEPTS DICT/ARRAY VALUES")
		return

	var print_str: String = name + ":\n"
	var max_size := name.length() + 2
	var indent_size := max_size
	var keys = collection.keys() if type_collection == TYPE_DICTIONARY else null

	for i: int in collection.size():
		var indent: String = str(keys[i]) if keys else " "
		indent = indent.rpad(indent_size, " ")
		var value = collection[keys[i]] if keys else collection[i]
		var value_line = "  " + indent + str(value) + "\n"
		if value_line.length() > max_size:
			max_size = value_line.length()
		print_str += value_line

	max_size = min(max_size, sep_max)

	if add_separator:
		var sep := "".lpad(max_size, "-") + "\n"
		print_str = sep + print_str + sep

	print(print_str)
