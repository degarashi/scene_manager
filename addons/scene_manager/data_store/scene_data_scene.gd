@tool
class_name SMgrDataScene
extends RefCounted

const AF = preload("uid://dlgh4u64a7qxk")


## Constants for internal data keys
class Key:
	const NAME = "name"
	const PATH = "path"
	const SECTIONS = "sections"
	const UID = "uid"


## Identifier name of the scene (used for Enums, etc.)
var name: String
## List of sections this scene belongs to
var sections: Array[String]
## Full path to the scene file
var path: String
## Godot-specific Resource UID
var uid: int = ResourceUID.INVALID_ID


## Creates and restores an instance from dictionary data
## @param src Source dictionary
## @return A new SMgrDataScene instance
static func load_from_dict(src: Dictionary) -> SMgrDataScene:
	var ret := SMgrDataScene.new()
	ret.name = src.get(Key.NAME, "")
	ret.sections = AF.convert_to_array_string(src.get(Key.SECTIONS, []))

	var saved_path: String = src.get(Key.PATH, "")
	var saved_uid: int = src.get(Key.UID, ResourceUID.INVALID_ID)

	ret._initialize_source(saved_path, saved_uid)
	return ret


## Converts the instance state into a dictionary format
## @return The converted dictionary
func save_to_dict() -> Dictionary:
	return {
		Key.NAME: name,
		Key.SECTIONS: sections,
		Key.PATH: path,
		Key.UID: uid,
	}


## Checks consistency between path and UID, then initializes properties
func _initialize_source(target_path: String, target_uid: int) -> void:
	# Prioritize resolution by UID (resilient to file movement)
	if target_uid != ResourceUID.INVALID_ID:
		var path_by_uid := ResourceUID.get_id_path(target_uid)
		if not path_by_uid.is_empty():
			path = path_by_uid
			uid = target_uid
			return

	# If UID is invalid, attempt to retrieve UID from the path
	if not target_path.is_empty() and FileAccess.file_exists(target_path):
		var id_from_path := ResourceLoader.get_resource_uid(target_path)
		if id_from_path != ResourceUID.INVALID_ID:
			path = target_path
			uid = id_from_path
			return

		# Special case where path exists but UID cannot be generated
		printerr("Scene Manager: Could not resolve UID for path: ", target_path)

	# If all attempts fail (e.g., file not found)
	if not target_path.is_empty() and not FileAccess.file_exists(target_path):
		printerr("Scene Manager: Entry is broken (File not found): ", target_path)

	path = target_path
	uid = target_uid
