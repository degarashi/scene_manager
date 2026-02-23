extends Object


## Check if the specified node has a parent node named "MainScreen"
## @param node Target node for judgment
## @return true if under MainScreen, false otherwise
static func is_in_main_screen(node: Node) -> bool:
	return has_ancestor(node, "MainScreen")


## Check if the node has an ancestor with the specified name
## @param node Starting node for the search
## @param target_name Name of the ancestor node to find
## @return true if an ancestor with target_name exists, false otherwise
static func has_ancestor(node: Node, target_name: String) -> bool:
	while node:
		if node.name == target_name:
			return true
		node = node.get_parent()
	return false


## Conversion of all array elements into a new string array
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
