@tool
class_name SMgrDataScene
extends Resource

# ------------- [Exports] -------------
## Identifier name of the scene (used for Enums, etc.)
@export var name: String
## List of sections this scene belongs to
@export var sections: Array[String]
## Full path to the scene file
@export var path: String:
	set(value):
		path = value
		_update_uid_from_path()
## Godot-specific Resource UID
@export var uid: int = ResourceUID.INVALID_ID:
	set(value):
		uid = value
		_update_path_from_uid()

# ------------- [Private Method] -------------
## Retrieves and updates to the latest path based on the UID
func _update_path_from_uid() -> void:
	if uid != ResourceUID.INVALID_ID:
		var current_path = ResourceUID.get_id_path(uid)
		if not current_path.is_empty() and current_path != path:
			path = current_path


## Retrieves and updates to the latest UID based on the path
func _update_uid_from_path() -> void:
	if not path.is_empty() and FileAccess.file_exists(path):
		var current_id = ResourceLoader.get_resource_uid(path)
		if current_id != ResourceUID.INVALID_ID and current_id != uid:
			uid = current_id


# ------------- [Public Method] -------------
## Initializes data using the specified path and UID, ensuring consistency
func initialize(target_path: String, target_uid: int) -> void:
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

	# Case where the file is not found
	if not target_path.is_empty() and not FileAccess.file_exists(target_path):
		printerr("Scene Manager: Entry is broken (File not found): ", target_path)

	path = target_path
	uid = target_uid
