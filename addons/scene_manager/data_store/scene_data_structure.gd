@tool
class_name SMgrData
extends DebouncedResource

const _DEBOUNCE_TIME = 0.3

# ------------- [Exports] -------------
## List of directory paths to include
@export var _include_list: Array[String]:
	set(value):
		if _include_list != value:
			_include_list = value
			_on_any_data_changed()

## Dictionary of scene data objects keyed by scene UID (int)
@export var _scenes: Dictionary[int, SMgrDataScene] = {}:
	set(value):
		_scenes = value
		_validate_connections()
		_on_any_data_changed()

## Dictionary of category data objects keyed by category-name's Hash (int)
@export var _categories: Dictionary[int, SMgrCategoryData] = {}:
	set(value):
		_categories = value
		_validate_connections()
		_on_any_data_changed()


## Initialize debouncer (connect signals)
func _init() -> void:
	# Initialize the debouncer inherited from DebouncedResource
	_init_debouncer(_DEBOUNCE_TIME)


## Common processing when any data changes are detected
func _on_any_data_changed() -> void:
	# Conventional immediate signal (necessary for Inspector updates, etc.)
	# This triggers the inherited DebouncedResource's _on_resource_changed()
	emit_changed()


## Ensure all managed data objects have their changed signals connected
func _validate_connections() -> void:
	for scene_data in _scenes.values():
		if scene_data and not scene_data.changed.is_connected(_on_any_data_changed):
			scene_data.changed.connect(_on_any_data_changed)

	for category_data in _categories.values():
		if category_data and not category_data.changed.is_connected(_on_any_data_changed):
			category_data.changed.connect(_on_any_data_changed)


# ------------- [Data Modification Methods] -------------
## Registers or updates a scene and notifies change
func set_scene_data(uid: int, scene_data: SMgrDataScene) -> void:
	_scenes[uid] = scene_data
	if not scene_data.changed.is_connected(_on_any_data_changed):
		scene_data.changed.connect(_on_any_data_changed)
	_on_any_data_changed()


## Removes a scene and notifies change
func remove_scene_data(uid: int) -> void:
	if _scenes.erase(uid):
		_on_any_data_changed()


## Registers or updates a category and notifies change
func set_category_data(id: int, category_data: SMgrCategoryData) -> void:
	_categories[id] = category_data
	if not category_data.changed.is_connected(_on_any_data_changed):
		category_data.changed.connect(_on_any_data_changed)
	_on_any_data_changed()


## Removes a category and notifies change
func remove_category_data(id: int) -> void:
	if _categories.erase(id):
		_on_any_data_changed()


## Sorts internal dictionaries to maintain a clean serialization order.
## Suppression of emit_changed is handled by blocking signals.
func sort_data_structures() -> void:
	var blocking := is_blocking_signals()
	set_block_signals(true)

	# Sort Scenes by Name
	var scene_keys := _scenes.keys()
	scene_keys.sort_custom(
		func(a, b) -> bool: return _scenes[a].name.naturalnocasecmp_to(_scenes[b].name) < 0
	)
	var sorted_scenes: Dictionary[int, SMgrDataScene] = {}
	for key in scene_keys:
		sorted_scenes[key] = _scenes[key]
	_scenes = sorted_scenes

	# Sort Categories by Name
	var category_keys := _categories.keys()
	category_keys.sort_custom(
		func(a, b) -> bool: return _categories[a].name.naturalnocasecmp_to(_categories[b].name) < 0
	)
	var sorted_categories: Dictionary[int, SMgrCategoryData] = {}
	for key in category_keys:
		sorted_categories[key] = _categories[key]
	_categories = sorted_categories

	set_block_signals(blocking)


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
func get_categories_list() -> Array[SMgrCategoryData]:
	var ret: Array[SMgrCategoryData] = []
	for id in _categories:
		ret.append(_categories[id])
	return ret


## Retrieves category data by its ID
func get_category_from_id(category_id: int) -> SMgrCategoryData:
	return _categories.get(category_id, null)


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


## Retrieves scenes belonging to a specific category ID
## @param category_id The ID of the category (Scenes.CategoryId)
## @return Array of scene data objects
func get_scenes_by_category_id(category_id: Scenes.CategoryId) -> Array[SMgrDataScene]:
	return _get_scenes(func(sc: SMgrDataScene) -> bool: return int(category_id) in sc.categories)


## Retrieves scenes belonging to a specific category
## @param category_name Name of the category to search for
## @param case_insensitive Whether to ignore case (default: false)
## @return Array of scene data
func get_scenes_with_category(
	category_name: String, case_insensitive := false
) -> Array[SMgrDataScene]:
	var target_lower := category_name.to_lower()

	return _get_scenes(
		func(sc: SMgrDataScene) -> bool:
			for c_id in sc.categories:
				var category := get_category_from_id(c_id)
				if not category:
					continue

				if case_insensitive:
					if category.name.to_lower() == target_lower:
						return true
				else:
					if category.name == category_name:
						return true
			return false
	)


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
	# category-id is the key of _categories, so it can be determined directly
	var ret: Array[Scenes.Id] = []
	for id in _scenes:
		var sc: SMgrDataScene = _scenes[id]
		if int(category_id) in sc.categories:
			ret.append(id as Scenes.Id)
	return ret


## Retrieves a list of category Enums (CategoryId) belonging to a specific scene Enum (Id)
## @param scene_id Scenes.Id
## @return Array of Scenes.CategoryId
func get_category_ids_by_scene(scene_id: Scenes.Id) -> Array[Scenes.CategoryId]:
	var category_ids: Array[Scenes.CategoryId] = []
	var sc := _get_scene_from_enum(scene_id)

	if not sc:
		return []

	for c_id in sc.categories:
		# The id in sc.categories can be directly cast as category-id
		category_ids.append(c_id)

	return category_ids


## Result object for comparing categories between two scenes
class CategoryDiff:
	var added: Array[Scenes.CategoryId] = []
	var removed: Array[Scenes.CategoryId] = []
	var unchanged: Array[Scenes.CategoryId] = []

	func _init(
		current_cats: Array[Scenes.CategoryId], target_cats: Array[Scenes.CategoryId]
	) -> void:
		# Identify removed and unchanged categories
		for c in current_cats:
			if c in target_cats:
				unchanged.append(c)
			else:
				removed.append(c)

		# Identify added categories
		for c in target_cats:
			if not c in current_cats:
				added.append(c)

	func _to_string() -> String:
		return "Added: %s, Removed: %s, Unchanged: %s" % [added, removed, unchanged]


## Compares categories between two scenes and returns the difference as an object
## @param current_id The scene ID to compare from
## @param target_id The scene ID to compare to
## @return CategoryDiff object containing 'added', 'removed', and 'unchanged' arrays
func compare_scene_categories(current_id: Scenes.Id, target_id: Scenes.Id) -> CategoryDiff:
	var current_cats := get_category_ids_by_scene(current_id)
	var target_cats := get_category_ids_by_scene(target_id)
	return CategoryDiff.new(current_cats, target_cats)


## Retrieves a list of all category IDs (CategoryId)
## @return Array of Scenes.CategoryId
func get_categories_all_ids() -> Array[Scenes.CategoryId]:
	var ret: Array[Scenes.CategoryId] = []
	for c_id in _categories:
		ret.append(c_id)
	return ret


func connect_ebus(ebus: SMgrEbusEditor) -> void:
	_toggle_ebus_connections(ebus, true)


func disconnect_ebus(ebus: SMgrEbusEditor) -> void:
	_toggle_ebus_connections(ebus, false)


func _toggle_ebus_connections(ebus: SMgrEbusEditor, connect: bool) -> void:
	var connections := [
		[ebus.get_scenes, _ebus_get_scenes],
		[ebus.get_scene_info, _ebus_get_scene_info],
		[ebus.get_scenes_all, _ebus_get_scenes_all],
		[ebus.get_scenes_categorized, _ebus_get_scenes_categorized],
		[ebus.get_scenes_uncategorized, _ebus_get_scenes_uncategorized],
		[ebus.get_categories, _ebus_get_categories],
		[ebus.get_category_by_id, _ebus_get_category_by_id],
		[ebus.add_scene_to_category, _ebus_add_scene_to_category],
		[ebus.remove_scene_from_category, _ebus_remove_scene_from_category],
		[ebus.scene_name_duplication_check, _ebus_duplicate_name_check],
		[ebus.change_scene_name, _ebus_change_scene_name]
	]

	for conn in connections:
		var sig: Signal = conn[0]
		var callable: Callable = conn[1]
		if connect:
			if not sig.is_connected(callable):
				sig.connect(callable)
		else:
			if sig.is_connected(callable):
				sig.disconnect(callable)


func _ebus_get_scenes(recv: Array[SMgrDataScene], category_id: int) -> void:
	recv.append_array(get_scenes_by_category_id(category_id))


func _ebus_get_scene_info(recv: Array[SMgrDataScene], scene_id: int) -> void:
	var sc := get_scene_from_uid(scene_id)
	if sc:
		recv.append(sc)


func _ebus_get_scenes_all(recv: Array[SMgrDataScene]) -> void:
	recv.append_array(get_scenes_all())


func _ebus_get_scenes_categorized(recv: Array[SMgrDataScene]) -> void:
	recv.append_array(get_scenes_categorized())


func _ebus_get_scenes_uncategorized(recv: Array[SMgrDataScene]) -> void:
	recv.append_array(get_scenes_uncategorized())


func _ebus_get_categories(recv: Array[int]) -> void:
	for id in get_categories_all_ids():
		recv.append(int(id))


func _ebus_get_category_by_id(recv: Array[SMgrCategoryData], category_id: int) -> void:
	var cat := get_category_from_id(category_id)
	if cat:
		recv.append(cat)


func _ebus_add_scene_to_category(scene_id: int, category_id: int) -> void:
	var sc := get_scene_from_uid(scene_id)
	if sc and not category_id in sc.categories:
		sc.categories.append(category_id)
		sc.emit_changed()


func _ebus_remove_scene_from_category(scene_id: int, category_id: int) -> void:
	var sc := get_scene_from_uid(scene_id)
	if sc and category_id in sc.categories:
		sc.categories.erase(category_id)
		sc.emit_changed()


func _ebus_duplicate_name_check(recv: Array[bool], scene_name: String) -> void:
	recv.append(get_scene_by_name(scene_name) != null)


func _ebus_change_scene_name(scene_id: int, scene_name: String) -> void:
	var sc := get_scene_from_uid(scene_id)
	if sc:
		sc.name = scene_name
		sc.emit_changed()
