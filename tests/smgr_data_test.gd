extends GdUnitTestSuite

const SMgrDataScript = preload("res://addons/scene_manager/data_store/scene_data_structure.gd")
const SMgrDataSceneScript = preload("res://addons/scene_manager/data_store/scene_data_scene.gd")
const SMgrCategoryDataScript = preload("res://addons/scene_manager/data_store/category_data.gd")

# Real UIDs from the project (matching scenes.gd)
const UID_SCENE_0 := 3167048368848614594
const UID_SCENE_1 := 7784575442615425582
const UID_SCENE_2 := 5390443888696816947
const PATH_SCENE_0 := "res://demo/scenes/scene_0.tscn"
const PATH_SCENE_1 := "res://demo/scenes/scene_1.tscn"
const PATH_SCENE_2 := "res://demo/scenes/scene_2.tscn"

const CAT_A_NAME := "Alpha Category"
const CAT_B_NAME := "Beta Category"

var _data: SMgrDataScript
var _cat_a_id: int
var _cat_b_id: int


func before_test() -> void:
	_data = SMgrDataScript.new()
	_cat_a_id = CAT_A_NAME.hash()
	_cat_b_id = CAT_B_NAME.hash()

	# Create categories
	var cat_a := SMgrCategoryDataScript.new(CAT_A_NAME)
	var cat_b := SMgrCategoryDataScript.new(CAT_B_NAME)

	# Create scenes
	var scene_a := SMgrDataSceneScript.new()
	scene_a.name = "Alpha"
	scene_a.path = PATH_SCENE_0
	scene_a.uid = UID_SCENE_0
	scene_a.categories = [_cat_a_id]

	var scene_b := SMgrDataSceneScript.new()
	scene_b.name = "Beta"
	scene_b.path = PATH_SCENE_1
	scene_b.uid = UID_SCENE_1
	scene_b.categories = []

	var scene_c := SMgrDataSceneScript.new()
	scene_c.name = "Gamma"
	scene_c.path = PATH_SCENE_2
	scene_c.uid = UID_SCENE_2
	scene_c.categories = [_cat_a_id, _cat_b_id]

	# Populate data (in-place dict modification avoids setter side-effects)
	_data._categories[_cat_a_id] = cat_a
	_data._categories[_cat_b_id] = cat_b
	_data._scenes[UID_SCENE_0] = scene_a
	_data._scenes[UID_SCENE_1] = scene_b
	_data._scenes[UID_SCENE_2] = scene_c


# ------------- [Scene Queries] -------------


func test_get_scene_from_uid_known() -> void:
	var result := _data.get_scene_from_uid(UID_SCENE_0)
	assert_object(result).is_not_null()
	assert_str(result.name).is_equal("Alpha")
	assert_str(result.path).is_equal(PATH_SCENE_0)


func test_get_scene_from_uid_unknown() -> void:
	var result := _data.get_scene_from_uid(999999)
	assert_object(result).is_null()


func test_get_scene_path_from_enum() -> void:
	var path := _data.get_scene_path_from_enum(Scenes.Id.SCENE_0)
	assert_str(path).is_equal(PATH_SCENE_0)


func test_get_scene_path_from_enum_none() -> void:
	var path := _data.get_scene_path_from_enum(Scenes.Id.NONE)
	assert_str(path).is_empty()


func test_get_scene_enum_by_path_valid() -> void:
	var id := _data.get_scene_enum_by_path(PATH_SCENE_0)
	assert_int(id).is_equal(Scenes.Id.SCENE_0)


func test_get_scene_enum_by_path_invalid() -> void:
	var id := _data.get_scene_enum_by_path("res://nonexistent/fake_scene.tscn")
	assert_int(id).is_equal(Scenes.Id.NONE)


func test_get_scene_by_name() -> void:
	# Found
	var found := _data.get_scene_by_name("Alpha")
	assert_object(found).is_not_null()
	assert_str(found.name).is_equal("Alpha")

	# Not found
	var not_found := _data.get_scene_by_name("Nonexistent")
	assert_object(not_found).is_null()


# ------------- [Category Queries] -------------


func test_get_include_list() -> void:
	var result := _data.get_include_list()
	assert_object(result).is_not_null()
	assert_int(result.size()).is_equal(0)


func test_get_categories_list() -> void:
	var result := _data.get_categories_list()
	assert_int(result.size()).is_equal(2)


func test_get_category_from_id() -> void:
	# Found
	var cat := _data.get_category_from_id(_cat_a_id)
	assert_object(cat).is_not_null()
	assert_str(cat.name).is_equal(CAT_A_NAME)

	# Not found
	var missing := _data.get_category_from_id(0)
	assert_object(missing).is_null()


func test_get_scenes_all() -> void:
	var result := _data.get_scenes_all()
	assert_int(result.size()).is_equal(3)


func test_get_scenes_uncategorized() -> void:
	var result := _data.get_scenes_uncategorized()
	assert_int(result.size()).is_equal(1)
	assert_str(result[0].name).is_equal("Beta")


func test_get_scenes_categorized() -> void:
	var result := _data.get_scenes_categorized()
	assert_int(result.size()).is_equal(2)


func test_get_scenes_by_category_id() -> void:
	var result := _data.get_scenes_by_category_id(_cat_a_id)
	assert_int(result.size()).is_equal(2)


func test_get_scenes_with_category() -> void:
	var result := _data.get_scenes_with_category(CAT_A_NAME)
	assert_int(result.size()).is_equal(2)


func test_get_scene_ids_with_category_name() -> void:
	var result := _data.get_scene_ids_with_category_name(CAT_B_NAME)
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(UID_SCENE_2)


func test_get_scene_ids_by_category() -> void:
	var result := _data.get_scene_ids_by_category(_cat_b_id)
	assert_int(result.size()).is_equal(1)
	assert_int(result[0]).is_equal(UID_SCENE_2)


func test_get_category_ids_by_scene() -> void:
	# Scene with categories
	var result := _data.get_category_ids_by_scene(Scenes.Id.SCENE_2)
	assert_int(result.size()).is_equal(2)

	# Scene without categories
	var empty := _data.get_category_ids_by_scene(Scenes.Id.SCENE_1)
	assert_int(empty.size()).is_equal(0)

	# Unknown scene
	var unknown := _data.get_category_ids_by_scene(Scenes.Id.NONE)
	assert_int(unknown.size()).is_equal(0)


func test_get_categories_all_ids() -> void:
	var result := _data.get_categories_all_ids()
	assert_int(result.size()).is_equal(2)


# ------------- [Data Modification] -------------


func test_set_scene_data() -> void:
	var scene := SMgrDataSceneScript.new()
	scene.name = "NewScene"
	scene.path = "res://test/new_scene.tscn"
	scene.uid = 55555

	_data.set_scene_data(55555, scene)

	var result := _data.get_scene_from_uid(55555)
	assert_object(result).is_not_null()
	assert_str(result.name).is_equal("NewScene")


func test_remove_scene_data() -> void:
	_data.remove_scene_data(UID_SCENE_0)
	var result := _data.get_scene_from_uid(UID_SCENE_0)
	assert_object(result).is_null()

	# Verify remaining scenes are intact
	var remaining := _data.get_scenes_all()
	assert_int(remaining.size()).is_equal(2)


func test_rename_category() -> void:
	var new_name := "Renamed Category"
	var new_id := new_name.hash()

	_data.rename_category(_cat_a_id, new_name)

	# Old key gone, new key present
	assert_object(_data.get_category_from_id(_cat_a_id)).is_null()
	var renamed := _data.get_category_from_id(new_id)
	assert_object(renamed).is_not_null()
	assert_str(renamed.name).is_equal(new_name)

	# Scenes that had old ID now have new ID
	var scene_a := _data.get_scene_from_uid(UID_SCENE_0)
	assert_bool(new_id in scene_a.categories).is_true()
	assert_bool(_cat_a_id in scene_a.categories).is_false()


func test_sort_data_structures() -> void:
	# Clear and insert in reverse alphabetical order
	_data._scenes.clear()
	_data._categories.clear()

	var scene_z := SMgrDataSceneScript.new()
	scene_z.name = "Zebra"
	scene_z.path = ""
	scene_z.uid = 900

	var scene_a := SMgrDataSceneScript.new()
	scene_a.name = "Apple"
	scene_a.path = ""
	scene_a.uid = 800

	var cat_b := SMgrCategoryDataScript.new("Mango")
	var cat_a := SMgrCategoryDataScript.new("Banana")

	_data._scenes[900] = scene_z
	_data._scenes[800] = scene_a
	_data._categories[cat_b.name.hash()] = cat_b
	_data._categories[cat_a.name.hash()] = cat_a

	_data.sort_data_structures()

	# Scenes sorted by name: Apple < Zebra
	var scene_keys := _data._scenes.keys()
	assert_str(_data._scenes[scene_keys[0]].name).is_equal("Apple")
	assert_str(_data._scenes[scene_keys[1]].name).is_equal("Zebra")

	# Categories sorted by name: Banana < Mango
	var cat_keys := _data._categories.keys()
	assert_str(_data._categories[cat_keys[0]].name).is_equal("Banana")
	assert_str(_data._categories[cat_keys[1]].name).is_equal("Mango")
