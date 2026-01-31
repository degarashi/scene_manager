extends Object


static func convert_to_array_string(src: Array) -> Array[String]:
	var ret: Array[String] = []
	for item in src:
		ret.append(str(item))
	return ret
