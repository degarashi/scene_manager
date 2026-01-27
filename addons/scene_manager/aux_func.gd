extends Object


## Converts elements of an array into a string array
## @param src Source array for conversion
## @return Array containing elements converted to strings
static func convert_to_array_string(src: Array) -> Array[String]:
	var ret: Array[String] = []
	for item in src:
		ret.append(str(item))
	return ret
