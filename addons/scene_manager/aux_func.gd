class_name SMgrUtil
extends Object

# ------------- [Static Variable] -------------
static var _log: DLoggerClass


static func _get_log() -> DLoggerClass:
	if not _log:
		_log = DLoggerClass.new("Scene Manager")
	return _log


# ------------- [Private Static Method] -------------
## Saves the resource to a temporary path.
## Returns the temp path on success, empty string on failure.
static func _uid_save_to_temp(resource: Resource, path: String) -> String:
	var base_path := path.get_basename()
	var extension := path.get_extension()
	var tmp_path := base_path + "_tmp." + extension

	var save_error := ResourceSaver.save(resource, tmp_path)
	if save_error != OK:
		_get_log().error("Save failed. Code: {0}. Path: {1}", [save_error, tmp_path])
		return ""

	return tmp_path


## Handles the backup-original, rename-temp, remove-backup logic.
## Also handles .uid file backup/recovery.
## Returns true on success, false on failure.
static func _uid_swap_files(path: String, tmp_path: String) -> bool:
	var dir := DirAccess.open("res://")
	if not dir:
		_get_log().error("DirAccess failed.")
		DirAccess.remove_absolute(tmp_path)
		return false

	# Use project-relative paths for DirAccess
	var rel_path := path.trim_prefix("res://")
	var rel_tmp_path := tmp_path.trim_prefix("res://")
	var rel_uid_path := rel_path + ".uid"
	var rel_tmp_uid_path := rel_tmp_path + ".uid"

	var backup_path := (
		path.get_basename() + "_backup_"
		+ str(Time.get_ticks_msec()) + "_" + str(randi())
		+ "." + path.get_extension()
	)
	var rel_backup_path := backup_path.trim_prefix("res://")
	var rel_backup_uid_path := rel_backup_path + ".uid"

	# Backup original → backup (preserves original for rollback)
	var has_original := dir.file_exists(rel_path)
	if has_original and dir.rename(rel_path, rel_backup_path) != OK:
		_get_log().error("Failed to backup original file: {0}", [path])
		dir.remove(rel_tmp_path)
		return false

	# Backup .uid if it exists
	var has_uid := dir.file_exists(rel_uid_path)
	if has_uid:
		if dir.rename(rel_uid_path, rel_backup_uid_path) != OK:
			if has_original:
				dir.rename(rel_backup_path, rel_path)
			dir.remove(rel_tmp_path)
			_get_log().error("Failed to backup .uid file: {0}", [rel_uid_path])
			return false

	# Rename temp → original
	if dir.rename(rel_tmp_path, rel_path) != OK:
		if has_original:
			dir.rename(rel_backup_path, rel_path)
		if has_uid:
			dir.rename(rel_backup_uid_path, rel_uid_path)
		_get_log().error("Failed to rename temp to original: {0}", [path])
		return false

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

	return true


# ------------- [Public Method] -------------
## Returns a DLoggerClass instance for Scene Manager logging.
## All callers share the same static logger instance.
static func get_log(
	log_level: DLoggerConstants.LogLevel = DLoggerConstants.LogLevel.DEBUG,
	enable_console: bool = true
) -> DLoggerClass:
	if not _log:
		_log = DLoggerClass.new("Scene Manager", log_level, enable_console)
	return _log


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


## Fetches category data from the editor event bus.
## Returns null if the category is not found.
static func fetch_category_from_ebus(
	ebus_editor: SMgrEbusEditor, category_id: int
) -> SMgrCategoryData:
	var recv: Array[SMgrCategoryData]
	ebus_editor.get_category_by_id.emit(recv, category_id)
	return recv[0] if not recv.is_empty() else null


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


## Comparator for sorting objects by name using natural-case-insensitive comparison.
## Usage: items.sort_custom(SMgrUtil.natural_case_sort)
static func natural_case_sort(a: Resource, b: Resource) -> bool:
	return a.name.naturalnocasecmp_to(b.name) < 0


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

	var tmp_path := _uid_save_to_temp(res, path)
	if tmp_path.is_empty():
		return

	_uid_swap_files(path, tmp_path)


## Returns true if the path is a valid resource path
## (existing directory or res:// .tscn file).
static func is_valid_resource_path(path: String) -> bool:
	return (
		DirAccess.dir_exists_absolute(path)
		or (FileAccess.file_exists(path) and path.begins_with("res://"))
	)


# ------------- [Enum/String Utilities] -------------
static var _sanitize_regex: RegEx
static var _scenes_script: Script


## Returns the Scenes script, loading it from disk on demand.
## The file must exist (may not be available during plugin bootstrapping).
static func _get_scenes() -> Script:
	if not _scenes_script:
		var path := "res://scene_manager_data/scenes.gd"
		if FileAccess.file_exists(path):
			_scenes_script = load(path)
	return _scenes_script


## Returns the string form of the Scenes.Id enum.
static func get_enum_string_from_enum(scene: int) -> String:
	var S := _get_scenes()
	if not S:
		return "NONE"
	var index: int = S.Id.values().find(scene)
	if index == -1:
		return "NONE"
	return S.Id.keys()[index]


## Returns the Scenes.Id enum from the provided string.
## Returns -1 (Scenes.Id.NONE) if the string doesn't match anything.
static func get_enum_from_scene_name(scene_name: String) -> int:
	var S := _get_scenes()
	if not S:
		return -1
	var sanitized := sanitize_as_enum_string(scene_name)
	if sanitized in S.Id.keys():
		return S.Id.get(sanitized) as int
	return -1


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
