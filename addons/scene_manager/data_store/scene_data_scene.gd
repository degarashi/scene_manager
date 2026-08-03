@tool
class_name SMgrDataScene
extends DebouncedResource

static var _log := DLoggerClass.new("Scene Manager")

# ------------- [Exports] -------------
## Identifier name of the scene (used for Enums, etc.)
@export var name: String:
	set(value):
		if name != value:
			name = value
			emit_changed()

## List of categories this scene belongs to
@export var categories: Array[int]:
	set(value):
		if categories != value:
			categories = value
			emit_changed()

@export var path: String:
	set(value):
		if path != value:
			path = value
			emit_changed()

@export var uid: int = ResourceUID.INVALID_ID:
	set(value):
		if uid != value:
			uid = value
			emit_changed()


func _init() -> void:
	# Initialize the debouncer inherited from DebouncedResource
	_init_debouncer(DEFAULT_DEBOUNCE_TIME)


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
	# Prefer the entry's own path when the file still exists with the expected UID.
	# With duplicate UIDs, ResourceUID.get_id_path() may silently point at a
	# DIFFERENT file sharing the same UID, rebinding this scene to the wrong path.
	var uid_from_path := get_uid_from_path(target_path)
	if uid_from_path == target_uid:
		final_path = target_path
		final_uid = target_uid

	# File missing (moved) or UID mismatch: fall back to UID resolution
	else:
		var path_by_uid := get_path_from_uid(target_uid)
		if not path_by_uid.is_empty():
			final_path = path_by_uid
			final_uid = target_uid
		elif uid_from_path != ResourceUID.INVALID_ID:
			final_path = target_path
			final_uid = uid_from_path
		elif not target_path.is_empty():
			if not FileAccess.file_exists(target_path):
				_log.error("Scene Manager: Entry is broken (File not found): {0}", [target_path])
			else:
				_log.error("Scene Manager: Could not resolve UID for path: {0}", [target_path])

	# Instantiate only if valid information is determined
	if not final_path.is_empty():
		var ret := SMgrDataScene.new()
		ret.name = sc_name
		# Assign finalized values (triggers emit_changed via setters)
		ret.path = final_path
		ret.uid = final_uid
		return ret

	return null
