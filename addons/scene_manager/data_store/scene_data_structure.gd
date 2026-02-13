@tool
class_name SMgrData
extends Resource

# ------------- [Exports] -------------
## List of directory paths to include
@export var _include_list: Array[String]
## Dictionary of scene data objects keyed by scene UID (int)
@export var _scenes: Dictionary[int, SMgrDataScene]
## List of section (category) names
@export var _sections: Array[String]

# ------------- [Private Method] -------------
func _get_scene_from_enum(scene: Scenes.Id) -> SMgrDataScene:
	if scene == Scenes.Id.NONE:
		return null
	var key_str: String = Scenes.Id.keys()[scene + 1]
	for uid in _scenes:
		var sc := _scenes[uid]
		if SceneManagerUtils.sanitize_as_enum_string(sc.name) == key_str:
			return sc
	assert(
		false,
		(
			"Scene Manager: Could not find SMgrDataScene for Enum ID '%s'. " % key_str
			+ "Data might be out of sync."
		)
	)
	return null


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
	for uid in _scenes:
		if _scenes[uid].path == path:
			var enum_name := SceneManagerUtils.sanitize_as_enum_string(_scenes[uid].name)
			return Scenes.Id.get(enum_name, Scenes.Id.NONE)
	return Scenes.Id.NONE


## Retrieves the full include list
## @return Array of paths
func get_include_list() -> Array[String]:
	return _include_list


## Retrieves the full list of sections
## @return Array of section names
func get_sections_list() -> Array[String]:
	return _sections


## Retrieves all registered scenes
## @return Array of scene data
func get_scenes_all() -> Array[SMgrDataScene]:
	return _get_scenes(func(_sc: SMgrDataScene) -> bool: return true)


## Retrieves scenes that are not categorized
## @return Array of scene data
func get_scenes_uncategorized() -> Array[SMgrDataScene]:
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return sc.sections.is_empty())


## Retrieves scenes that are categorized
## @return Array of scene data
func get_scenes_categorized() -> Array[SMgrDataScene]:
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return not sc.sections.is_empty())


## Retrieves scenes belonging to a specific section
## @param section_name Name of the section to search for
## @return Array of scene data
func get_scenes_with_section(section_name: String) -> Array[SMgrDataScene]:
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return section_name in sc.sections)


## Retrieves scene data by specifying a name
## @param scene_name Scene name
## @return Corresponding SMgrDataScene
func get_scene_by_name(scene_name: String) -> SMgrDataScene:
	for uid in _scenes:
		var sc: SMgrDataScene = _scenes[uid]
		if sc.name == scene_name:
			return sc
	return null
