@tool
class_name SMgrDataScene
extends Resource

# ------------- [Exports] -------------
## Identifier name of the scene (used for Enums, etc.)
@export var name: String
## List of categories this scene belongs to
@export var categories: Array[String]

@export var path: String
@export var uid: int = ResourceUID.INVALID_ID


# ------------- [Static Helper Methods] -------------
## Gets the current path from the UID
static func get_path_from_uid(target_uid: int) -> String:
	if target_uid == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.get_id_path(target_uid)


## Gets the current UID from the path
static func get_uid_from_path(target_path: String) -> int:
	if target_path.is_empty() or not FileAccess.file_exists(target_path):
		return ResourceUID.INVALID_ID
	return ResourceLoader.get_resource_uid(target_path)


# ------------- [Public Method] -------------
## Initializes data using the specified path and UID, ensuring consistency
static func initialize(sc_name: String, target_path: String, target_uid: int) -> SMgrDataScene:
	var final_path: String = ""
	var final_uid: int = ResourceUID.INVALID_ID

	# Resolve information (Validation Priority)
	# Prioritize resolution by UID (resilient to file movement)
	var path_by_uid := get_path_from_uid(target_uid)
	if not path_by_uid.is_empty():
		final_path = path_by_uid
		final_uid = target_uid

	# Search by path only if not resolved by UID
	else:
		var id_from_path := get_uid_from_path(target_path)
		if id_from_path != ResourceUID.INVALID_ID:
			final_path = target_path
			final_uid = id_from_path
		elif not target_path.is_empty():
			if not FileAccess.file_exists(target_path):
				printerr("Scene Manager: Entry is broken (File not found): ", target_path)
			else:
				printerr("Scene Manager: Could not resolve UID for path: ", target_path)

	# Instantiate only if valid information is determined
	if not final_path.is_empty():
		var ret := SMgrDataScene.new()
		ret.name = sc_name
		# Assign finalized values directly to avoid redundant setter execution
		ret.path = final_path
		ret.uid = final_uid
		return ret

	return null
