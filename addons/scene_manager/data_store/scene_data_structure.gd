@tool
class_name SMgrData
extends Resource

# ------------- [Exports] -------------
## List of directory paths to include
@export var _include_list: Array[String]
## Dictionary of scene data objects keyed by scene UID (int)
@export var _scenes: Dictionary[int, SMgrDataScene]
## List of category names
@export var _categories: Array[String]


# ------------- [Private Method] -------------
func _get_scene_from_enum(scene: Scenes.Id) -> SMgrDataScene:
	if scene == Scenes.Id.NONE:
		return null

	# If the enum's underlying value is a UID, it can be retrieved directly from the dictionary.
	# Since 'scene' is an int (64-bit), it matches the keys in _scenes.
	return _scenes.get(scene, null)


## Internal method to extract scenes into an array based on a comparison function
## @param cmp Callable for evaluation
## @return Filtered array of scenes
func _get_scenes(cmp: Callable) -> Array[SMgrDataScene]:
	var ret: Array[SMgrDataScene] = []
	for uid in _scenes:
		var sc := _scenes[uid]
		if cmp.call(sc):
			ret.append(sc)
	return ret


# ------------- [Public Method] -------------
## Retrieves scene data by UID
## @param uid Scene UID (int)
## @return Corresponding SMgrDataScene
func get_scene_from_uid(uid: int) -> SMgrDataScene:
	return _scenes.get(uid, null)


## Retrieves a scene path from an enum key
## @param scene Scene enum
## @return Scene path string
func get_scene_path_from_enum(scene: Scenes.Id) -> String:
	var sc := _get_scene_from_enum(scene)
	return sc.path if sc else ""


## Retrieves an enum key from a scene path
## @param path Full path of the scene
## @return Corresponding Id
func get_scene_enum_by_path(path: String) -> Scenes.Id:
	# Retrieve the UID (int) directly from the path
	var uid := ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return Scenes.Id.NONE

	# Check if the UID exists in the managed scenes dictionary
	if _scenes.has(uid):
		return uid as Scenes.Id

	return Scenes.Id.NONE


## Retrieves the full include list
## @return Array of paths
func get_include_list() -> Array[String]:
	return _include_list


## Retrieves the full list of categories
## @return Array of category names
func get_categories_list() -> Array[String]:
	return _categories


## Retrieves all registered scenes
## @return Array of scene data
func get_scenes_all() -> Array[SMgrDataScene]:
	return _get_scenes(func(_sc: SMgrDataScene) -> bool: return true)


## Retrieves scenes that are not categorized
## @return Array of scene data
func get_scenes_uncategorized() -> Array[SMgrDataScene]:
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return sc.categories.is_empty())


## Retrieves scenes that are categorized
## @return Array of scene data
func get_scenes_categorized() -> Array[SMgrDataScene]:
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return not sc.categories.is_empty())


## Retrieves scenes belonging to a specific category
## @param category_name Name of the category to search for
## @param case_insensitive Whether to ignore case (default: false)
## @return Array of scene data
func get_scenes_with_category(
	category_name: String, case_insensitive := false
) -> Array[SMgrDataScene]:
	if case_insensitive:
		var lower_name := category_name.to_lower()
		return _get_scenes(
			func(sc: SMgrDataScene) -> bool:
				# Check if there is a lowercase match in the category list of each scene
				for c in sc.categories:
					if c.to_lower() == lower_name:
						return true
				return false
		)
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return category_name in sc.categories)


## Retrieves scene data by specifying a name
## @param scene_name Scene name
## @return Corresponding SMgrDataScene
func get_scene_by_name(scene_name: String) -> SMgrDataScene:
	for uid in _scenes:
		var sc: SMgrDataScene = _scenes[uid]
		if sc.name == scene_name:
			return sc
	return null


## Retrieves a list of scene Enums (Id) belonging to a category name
## @param category_name Category name
## @param case_insensitive Whether to ignore case
## @return Array of Scenes.Id
func get_scene_ids_with_category_name(
	category_name: String, case_insensitive := false
) -> Array[Scenes.Id]:
	var ret: Array[Scenes.Id] = []
	var scenes_data := get_scenes_with_category(category_name, case_insensitive)
	for sc in scenes_data:
		# Cast UID to Scenes.Id and store it
		ret.append(sc.uid as Scenes.Id)
	return ret


## Retrieves a list of scene Enums (Id) belonging to a category Enum (CategoryId)
## @param category_id Categories.CategoryId
## @return Array of Scenes.Id
func get_scene_ids_by_category(category_id: Scenes.CategoryId) -> Array[Scenes.Id]:
	var category_name := Scenes.CategoryId.find_key(category_id)
	if category_name.is_empty():
		return []
	# Always perform case-insensitive search when using Enum
	return get_scene_ids_with_category_name(category_name, true)


## Retrieves a list of category Enums (CategoryId) belonging to a specific scene Enum (Id)
## @param scene_id Scenes.Id
## @return Array of Scenes.CategoryId
func get_category_ids_by_scene(scene_id: Scenes.Id) -> Array[Scenes.CategoryId]:
	var category_ids: Array[Scenes.CategoryId] = []
	var sc := _get_scene_from_enum(scene_id)

	if not sc:
		return []

	for c_name in sc.categories:
		# Convert category string name back to its corresponding Enum value
		var c_id: int = Scenes.CategoryId.get(c_name.to_upper(), -1)
		if c_id != -1:
			category_ids.append(c_id as Scenes.CategoryId)

	return category_ids
