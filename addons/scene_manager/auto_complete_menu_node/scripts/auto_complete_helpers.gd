class_name AutoCompleteHelpers
extends Object

# ------------- [Constants] -------------
const AUTO_DIRECTION_STRINGS: Array[String] = ["NORTH", "EAST", "SOUTH", "WEST"]
static var _log := DLoggerClass.new("Scene Manager")


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
static func debug_collection(
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
	var keys: Array = collection.keys() if type_collection == TYPE_DICTIONARY else null

	for i: int in collection.size():
		var indent: String = str(keys[i]) if keys else " "
		indent = indent.rpad(indent_size, " ")
		var value: Variant = collection[keys[i]] if keys else collection[i]
		var value_line: String = "  " + indent + str(value) + "\n"
		if value_line.length() > max_size:
			max_size = value_line.length()
		print_str += value_line

	max_size = min(max_size, sep_max)

	if add_separator:
		var sep := "".lpad(max_size, "-") + "\n"
		print_str = sep + print_str + sep

	_log.debug(print_str)


## Performs fuzzy matching between a query and a target string.
## Returns null if no match, or a dictionary with:
## - "score": float (higher is better)
## - "indices": Array[int] (indices of matched characters for highlighting)
static func fuzzy_match(query: String, target: String, case_sensitive: bool = false) -> Variant:
	if query.is_empty():
		return {"matched": true, "score": 1.0, "indices": []}

	var q := query if case_sensitive else query.to_lower()
	var t := target if case_sensitive else target.to_lower()

	var score := 0.0
	var indices: Array[int] = []
	var t_idx := 0
	var q_idx := 0

	var last_match_idx := -1
	var continuous_count := 0

	while q_idx < q.length() and t_idx < t.length():
		if q[q_idx] == t[t_idx]:
			indices.append(t_idx)

			# --- Scoring Logic ---
			var char_score := 10.0

			# Bonus for starting match
			if t_idx == 0:
				char_score += 15.0

			# Bonus for continuous matching
			if last_match_idx != -1 and t_idx == last_match_idx + 1:
				continuous_count += 1
				char_score += 5.0 * continuous_count
			else:
				continuous_count = 0

			# Bonus for word boundaries (snake_case, PascalCase)
			if t_idx > 0:
				var prev_char := target[t_idx - 1]
				var curr_char := target[t_idx]
				# snake_case boundary
				if prev_char == "_":
					char_score += 12.0
				# PascalCase/camelCase boundary
				elif prev_char.to_lower() == prev_char and curr_char.to_upper() == curr_char:
					char_score += 12.0

			# Penalty for gaps
			if last_match_idx != -1:
				var gap := t_idx - last_match_idx - 1
				char_score -= gap * 1.5

			score += char_score
			last_match_idx = t_idx
			q_idx += 1

		t_idx += 1

	if q_idx != q.length():
		return null

	score /= q.length()
	return {"matched": true, "score": score, "indices": indices}
