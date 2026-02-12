extends Object

const PS := preload("uid://dn6eh4s0h8jhi")


## Converts elements of an array into a string array
## @param src Source array for conversion
## @return Array containing elements converted to strings
static func convert_to_array_string(src: Array) -> Array[String]:
	var ret: Array[String] = []
	for item in src:
		ret.append(str(item))
	return ret


static func change_resource_uid(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("File does not exist: " + path)
		return

	var res := ResourceLoader.load(path)
	if not res:
		push_error("Failed to load resource: " + path)
		return

	# Change UID
	res.resource_scene_unique_id = "id_" + str(ResourceUID.create_id())

	var base_path := path.get_basename()
	var extension := path.get_extension()
	var tmp_path := base_path + "_tmp." + extension

	# Save to temp
	var save_error := ResourceSaver.save(res, tmp_path)
	if save_error != OK:
		push_error("Save failed. Code: %d. Path: %s" % [save_error, tmp_path])
		return

	var dir := DirAccess.open("res://")
	if dir:
		# Use project-relative paths for DirAccess
		var rel_path := path.replace("res://", "")
		var rel_tmp_path := tmp_path.replace("res://", "")

		# .uid file paths
		var rel_uid_path := rel_path + ".uid"
		var rel_tmp_uid_path := rel_tmp_path + ".uid"

		# Remove original file and its .uid if it exists
		dir.remove(rel_path)
		if dir.file_exists(rel_uid_path):
			dir.remove(rel_uid_path)

		# Rename temp file to original name
		var rename_error := dir.rename(rel_tmp_path, rel_path)

		# Handle the potential .uid file created for the temp file
		if dir.file_exists(rel_tmp_uid_path):
			if rename_error == OK:
				# If rename was successful, we should also rename/move the new .uid
				dir.rename(rel_tmp_uid_path, rel_uid_path)
			else:
				# If main rename failed, clean up the temp .uid
				dir.remove(rel_tmp_uid_path)

		if rename_error != OK:
			push_error("Rename failed: " + str(rename_error))
	else:
		push_error("DirAccess failed.")


static func check_invalid_ids() -> void:
	print("Scene Manager: Checking for invalid Scenes.Id references...")

	# Reload the script to ensure Scenes.Id enum is up to date
	var script: GDScript = ResourceLoader.load(
		PS.scene_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE
	)
	if script:
		Scenes.set_script(script)

	var count: int = _scan_project_for_invalid_ids("res://")
	if count == 0:
		print("Scene Manager: No invalid Scenes.Id references found.")
	else:
		print("Scene Manager: Found %d invalid references." % count)


static func _scan_project_for_invalid_ids(path: String) -> int:
	var invalid_count: int = 0

	# exclude "res://addons" folder
	if path == "res://addons":
		return 0

	var dir: DirAccess = DirAccess.open(path)
	if not dir:
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
	if file_path == PS.scene_path:
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
				push_error(
					(
						"Scene Manager: Invalid Scenes.Id.%s found in %s:%d"
						% [id_name, file_path, i + 1]
					)
				)
				file_invalid_count += 1

	return file_invalid_count
