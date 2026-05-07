extends Object

const _PS := preload("uid://dn6eh4s0h8jhi")

static var _log := DLoggerClass.new("Scene Manager")


static func check_invalid_ids() -> void:
	_log.debug("Checking for invalid Scenes.Id references...")

	# Reload the script to ensure Scenes.Id enum is up to date
	var script: GDScript = ResourceLoader.load(
		_PS.scene_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE
	)
	if script:
		Scenes.set_script(script)

	var count: int = _scan_project_for_invalid_ids("res://")
	if count == 0:
		_log.debug("No invalid Scenes.Id references found.")
	else:
		_log.debug("Found {0} invalid references.", [count])


static func _scan_project_for_invalid_ids(path: String) -> int:
	var invalid_count: int = 0

	# exclude "res://addons" folder
	if path == "res://addons":
		return 0

	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return 0

	# If .gdignore exists in the directory, skip scanning this folder
	if dir.file_exists(".gdignore"):
		return 0

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	# Get the current valid enum key
	var valid_keys: Dictionary = {}
	for key: String in Scenes.Id.keys():
		valid_keys[key] = true

	while file_name != "":
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				invalid_count += _scan_project_for_invalid_ids(full_path)
		elif file_name.ends_with(".gd"):
			invalid_count += _check_file_content_for_invalid_ids(full_path, valid_keys)
		file_name = dir.get_next()

	return invalid_count


static func _check_file_content_for_invalid_ids(file_path: String, valid_keys: Dictionary) -> int:
	# Skip "scenes.gd" itself
	if file_path == _PS.scene_path:
		return 0

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return 0

	var content: String = file.get_as_text()
	var lines: PackedStringArray = content.split("\n")
	var file_invalid_count: int = 0

	# Extract "Scenes.Id.xxxx" using regular expression
	var regex: RegEx = RegEx.new()
	# Exclude method calls (brackets) or enum built-in method names
	regex.compile("Scenes\\.Id\\.(?!(?:find_key|keys|values|has|size)\\b)([A-Za-z0-9_]+)(?!\\()")

	for i: int in range(lines.size()):
		var matches: Array[RegExMatch] = regex.search_all(lines[i])
		for m: RegExMatch in matches:
			var id_name: String = m.get_string(1)
			if not valid_keys.has(id_name):
				_log.error(
					"Scene Manager: Invalid Scenes.Id.{0} found in {1}:{2}",
					[id_name, file_path, i + 1]
				)
				file_invalid_count += 1

	return file_invalid_count
