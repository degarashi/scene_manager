class_name SMgrUtil
extends Object

# ------------- [Static Variable] -------------
static var _log: DLoggerClass


static func _get_log() -> DLoggerClass:
	if not _log:
		_log = DLoggerClass.new("Scene Manager")
	return _log


# ------------- [Public Method] -------------
## Connects the signal to the callable only if the connection does not already exist
static func connect_if_not_connected(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)


## Disconnects the signal from the callable only if the connection exists
static func disconnect_if_connected(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


static func to_tmp_name(node_name: String) -> String:
	return node_name + "_tmp_" + str(Time.get_ticks_msec()) + "_" + str(randi())


static func from_tmp_name(tmp_name: String) -> String:
	var idx := tmp_name.rfind("_tmp_")
	if idx == -1:
		return tmp_name
	return tmp_name.left(idx)


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
static func convert_to_array_string(src: Array[Variant]) -> Array[String]:
	var ret: Array[String] = []
	ret.assign(src.map(func(item): return str(item)))
	return ret


## Update and save the resource UID with a newly generated one
## @param path Target resource file path
static func change_resource_uid(path: String) -> void:
	if not FileAccess.file_exists(path):
		_get_log().error("File does not exist: {0}", [path])
		return

	var res := ResourceLoader.load(path)
	if not res:
		_get_log().error("Failed to load resource: {0}", [path])
		return

	# Change UID
	res.resource_scene_unique_id = "id_" + str(ResourceUID.create_id())

	var base_path := path.get_basename()
	var extension := path.get_extension()
	var tmp_path := base_path + "_tmp." + extension

	# Save to temp
	var save_error := ResourceSaver.save(res, tmp_path)
	if save_error != OK:
		_get_log().error("Save failed. Code: {0}. Path: {1}", [save_error, tmp_path])
		return

	var dir := DirAccess.open("res://")
	if not dir:
		_get_log().error("DirAccess failed.")
		DirAccess.remove_absolute(tmp_path)
		return

	# Use project-relative paths for DirAccess
	var rel_path := path.trim_prefix("res://")
	var rel_tmp_path := tmp_path.trim_prefix("res://")
	var rel_uid_path := rel_path + ".uid"
	var rel_tmp_uid_path := rel_tmp_path + ".uid"

	var backup_path := (
		base_path + "_backup_" + str(Time.get_ticks_msec()) + "_" + str(randi()) + "." + extension
	)
	var rel_backup_path := backup_path.trim_prefix("res://")
	var rel_backup_uid_path := rel_backup_path + ".uid"

	# Backup original → backup (preserves original for rollback)
	var has_original := dir.file_exists(rel_path)
	if has_original and dir.rename(rel_path, rel_backup_path) != OK:
		_get_log().error("Failed to backup original file: {0}", [path])
		dir.remove(rel_tmp_path)
		return

	# Backup .uid if it exists
	var has_uid := dir.file_exists(rel_uid_path)
	if has_uid:
		if dir.rename(rel_uid_path, rel_backup_uid_path) != OK:
			if has_original:
				dir.rename(rel_backup_path, rel_path)
			dir.remove(rel_tmp_path)
			_get_log().error("Failed to backup .uid file: {0}", [rel_uid_path])
			return

	# Rename temp → original
	if dir.rename(rel_tmp_path, rel_path) != OK:
		if has_original:
			dir.rename(rel_backup_path, rel_path)
		if has_uid:
			dir.rename(rel_backup_uid_path, rel_uid_path)
		_get_log().error("Failed to rename temp to original: {0}", [path])
		return

	# Move temp .uid → original .uid (Godot may have created one for the temp)
	if dir.file_exists(rel_tmp_uid_path):
		if dir.rename(rel_tmp_uid_path, rel_uid_path) != OK:
			dir.remove(rel_tmp_uid_path)
			_get_log().warn("Failed to move .uid for the new file: {0}", [rel_uid_path])

	# Remove backup files
	if has_original:
		dir.remove(rel_backup_path)
	if has_uid:
		dir.remove(rel_backup_uid_path)


# ------------- [Enum/String Utilities] -------------
static var _sanitize_regex: RegEx


## Returns the string form of the Scenes.Id enum.
static func get_enum_string_from_enum(scene: Scenes.Id) -> String:
	var index: int = Scenes.Id.values().find(scene)
	if index == -1:
		return "NONE"
	return Scenes.Id.keys()[index]


## Returns the Scenes.Id enum from the provided string.
## Returns Scenes.Id.NONE if the string doesn't match anything.
static func get_enum_from_scene_name(scene_name: String) -> Scenes.Id:
	var sanitized := sanitize_as_enum_string(scene_name)
	if sanitized in Scenes.Id.keys():
		return Scenes.Id.get(sanitized) as Scenes.Id
	return Scenes.Id.NONE


## Returns a string that is all caps with spaces replaced with underscores.
static func sanitize_as_enum_string(text: String) -> String:
	text = text.replace(" ", "_")
	return text.to_upper()


## Returns a string that has no symbols, is lower cases, and spaces are underscores.
static func sanitize_scene_name(scene_name: String) -> String:
	if scene_name.is_empty():
		return scene_name
	if not _sanitize_regex:
		_sanitize_regex = RegEx.new()
		_sanitize_regex.compile("[^a-zA-Z0-9_ -]")
	scene_name = _sanitize_regex.sub(scene_name, "", true)
	scene_name = scene_name.replace(" ", "_")
	return scene_name
