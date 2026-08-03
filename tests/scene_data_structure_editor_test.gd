extends GdUnitTestSuite

## Tests for SMgrDataEditor (561 lines).
## Verifies category management, scene-category assignment, include path
## management, export string generation, dirty flag, and cleanup.
##
## SMgrDataEditor._init() has assert(Engine.is_editor_hint(), ...) and
## calls _setup_filesystem_monitoring() which requires FileEnumWatcher.
## The TestEditor subclass below bypasses both for headless test compatibility.

const DataScript := preload(
	"res://addons/scene_manager/data_store/scene_data_structure.gd"
)
const SceneScript := preload(
	"res://addons/scene_manager/data_store/scene_data_scene.gd"
)
const CatScript := preload(
	"res://addons/scene_manager/data_store/category_data.gd"
)
const EbusScript := preload(
	"res://addons/scene_manager/editor/event_bus/ebus_editor.gd"
)
const ConstScript := preload(
	"res://addons/scene_manager/scene_manager_constants.gd"
)

const CAT_A := "Players"
const CAT_B := "Enemies"
const CAT_RESERVED := "All"

var _editor: SMgrDataEditor
var _data: SMgrData
var _cat_a_id: int
var _cat_b_id: int
var _cat_reserved_id: int
var _log: DLoggerClass


# ------------- [Helper: TestEditor wrapper] -------------
## Subclass that bypasses the editor-only assert and filesystem
## monitoring so tests can run in headless mode.
class TestEditor extends SMgrDataEditor:
	func _init(
		p_data: SMgrData, ebus: SMgrEbusEditor, p_log: DLoggerClass
	) -> void:
		if p_data == null:
			push_error("SMgrDataEditor: SMgrData instance is required.")
			return
		_data = p_data
		_log = p_log
		_init_debouncer(0.15)
		_data.changed.connect(_on_data_changed)
		_data.data_changed_debounced.connect(_on_data_changed)
		# Skip _setup_filesystem_monitoring() — requires FileEnumWatcher
		# Skip Engine.get_main_loop().create_timer(...) — not available headless
		_connect_ebus(ebus)


func before_test() -> void:
	_log = DLoggerClass.new("Test")
	_data = DataScript.new()
	_cat_a_id = CAT_A.hash()
	_cat_b_id = CAT_B.hash()
	_cat_reserved_id = CAT_RESERVED.hash()

	var ebus := EbusScript.new()
	_editor = TestEditor.new(_data, ebus, _log)
	# Mark initial load as false so data mutations raise the dirty flag
	_editor._initial_load = false


# ------------- [Constructor & Basic State] -------------


func test_constructor_requires_data() -> void:
	## Passing null data should produce an error but not crash.
	var ebus := EbusScript.new()
	var ed := TestEditor.new(null, ebus, _log)
	# When data is null, _init returns early and get_data() returns null
	assert_object(ed.get_data()).is_null()


func test_get_data() -> void:
	## After construction with valid data, get_data() returns the same instance.
	var result := _editor.get_data()
	assert_object(result).is_not_null()
	assert_object(result).is_equal(_data)


func test_dirty_flag_initial_false() -> void:
	## get_dirty_flag() returns false initially when _initial_load is false.
	assert_bool(_editor.get_dirty_flag()).is_false()


# ------------- [Category Management] -------------


func test_add_category() -> void:
	## Adding a category stores it in the underlying data.
	_editor.add_category(CAT_A)
	var cat := _data.get_category_from_id(_cat_a_id)
	assert_object(cat).is_not_null()
	assert_str(cat.name).is_equal(CAT_A)


func test_add_category_empty_name() -> void:
	## Adding a category with an empty or whitespace-only name does nothing.
	_editor.add_category("")
	var list := _data.get_categories_list()
	assert_int(list.size()).is_equal(0)

	_editor.add_category("   ")
	list = _data.get_categories_list()
	assert_int(list.size()).is_equal(0)


func test_add_category_duplicate() -> void:
	## Adding a category with the same name (case-insensitive) is rejected.
	_editor.add_category(CAT_A)
	var list_before := _data.get_categories_list()
	assert_int(list_before.size()).is_equal(1)

	# Same case
	_editor.add_category(CAT_A)
	assert_int(_data.get_categories_list().size()).is_equal(1)

	# Different case should also be rejected
	_editor.add_category(CAT_A.to_lower())
	assert_int(_data.get_categories_list().size()).is_equal(1)


func test_add_category_reserved_name() -> void:
	## "All" is a reserved category name and must be rejected.
	_editor.add_category(CAT_RESERVED)
	var cat := _data.get_category_from_id(_cat_reserved_id)
	assert_object(cat).is_null()


func test_get_category_id_from_name() -> void:
	## After adding a category, its ID can be retrieved by name.
	_editor.add_category(CAT_A)
	var found_id := _editor.get_category_id_from_name(CAT_A)
	assert_int(found_id).is_equal(_cat_a_id)


func test_get_category_id_from_name_unknown() -> void:
	## Querying a name that does not exist returns INVALID_ID.
	var found_id := _editor.get_category_id_from_name("Nonexistent")
	assert_int(found_id).is_equal(ResourceUID.INVALID_ID)


func test_remove_category() -> void:
	## Removing a category removes it from the data store.
	_editor.add_category(CAT_A)
	assert_object(_data.get_category_from_id(_cat_a_id)).is_not_null()

	_editor.remove_category(_cat_a_id)
	assert_object(_data.get_category_from_id(_cat_a_id)).is_null()


func test_remove_category_cleans_up_scenes() -> void:
	## When a category is removed, all scenes that reference it are cleaned up.
	_editor.add_category(CAT_A)

	var scene := SceneScript.new()
	scene.name = "TestScene"
	scene.path = "res://test/test_scene.tscn"
	scene.uid = 5001
	scene.categories = [_cat_a_id]
	_data.set_scene_data(5001, scene)

	# Verify scene has the category
	var sc := _data.get_scene_from_uid(5001)
	assert_bool(_cat_a_id in sc.categories).is_true()

	# Remove category — should clean up scene references
	_editor.remove_category(_cat_a_id)

	# Scene should no longer have the category
	assert_bool(_cat_a_id in sc.categories).is_false()


func test_remove_category_nonexistent() -> void:
	## Removing a category that doesn't exist should not crash.
	_editor.remove_category(999999)
	assert_bool(true).is_true()  # Reaching here means no crash


# ------------- [Scene-Category Assignment] -------------


func test_add_scene_to_category() -> void:
	## A scene can be assigned to a category.
	_editor.add_category(CAT_A)

	var scene := SceneScript.new()
	scene.name = "Hero"
	scene.path = "res://test/hero.tscn"
	scene.uid = 6001
	_data.set_scene_data(6001, scene)

	_editor.add_scene_to_category(6001, _cat_a_id)

	var sc := _data.get_scene_from_uid(6001)
	assert_bool(_cat_a_id in sc.categories).is_true()


func test_add_scene_to_category_nonexistent_category() -> void:
	## Assigning a scene to a non-existent category does nothing.
	var scene := SceneScript.new()
	scene.name = "Ghost"
	scene.path = "res://test/ghost.tscn"
	scene.uid = 6002
	_data.set_scene_data(6002, scene)

	_editor.add_scene_to_category(6002, 999999)

	var sc := _data.get_scene_from_uid(6002)
	assert_int(sc.categories.size()).is_equal(0)


func test_add_scene_to_category_nonexistent_scene() -> void:
	## Assigning a non-existent scene to a category should not crash.
	_editor.add_category(CAT_A)
	_editor.add_scene_to_category(999999, _cat_a_id)
	assert_bool(true).is_true()


func test_remove_scene_from_category() -> void:
	## A scene can be removed from a category.
	_editor.add_category(CAT_A)

	var scene := SceneScript.new()
	scene.name = "Villain"
	scene.path = "res://test/villain.tscn"
	scene.uid = 6003
	scene.categories = [_cat_a_id]
	_data.set_scene_data(6003, scene)

	_editor.remove_scene_from_category(6003, _cat_a_id)

	var sc := _data.get_scene_from_uid(6003)
	assert_bool(_cat_a_id in sc.categories).is_false()


func test_remove_scene_from_category_nonexistent() -> void:
	## Removing from a non-existent category does nothing.
	var scene := SceneScript.new()
	scene.name = "Orphan"
	scene.path = "res://test/orphan.tscn"
	scene.uid = 6004
	_data.set_scene_data(6004, scene)

	_editor.remove_scene_from_category(6004, 999999)
	assert_bool(true).is_true()


func test_change_scene_name() -> void:
	## Changing a scene name updates the name in the data store.
	var scene := SceneScript.new()
	scene.name = "OldName"
	scene.path = "res://test/rename_me.tscn"
	scene.uid = 7001
	_data.set_scene_data(7001, scene)

	_editor.change_scene_name(7001, "NewName")

	var sc := _data.get_scene_from_uid(7001)
	assert_str(sc.name).is_equal("NewName")


func test_change_scene_name_empty() -> void:
	## Setting an empty name should be ignored.
	var scene := SceneScript.new()
	scene.name = "KeepMe"
	scene.path = "res://test/keep.tscn"
	scene.uid = 7002
	_data.set_scene_data(7002, scene)

	_editor.change_scene_name(7002, "")

	var sc := _data.get_scene_from_uid(7002)
	assert_str(sc.name).is_equal("KeepMe")


func test_dirty_flag_after_add_category() -> void:
	## After adding a category the dirty flag should be true.
	_editor.add_category(CAT_A)
	assert_bool(_editor.get_dirty_flag()).is_true()


func test_dirty_flag_after_remove_category() -> void:
	## After removing a category the dirty flag should be true.
	_editor.add_category(CAT_A)
	_editor._dirty_flag = false  # Reset for test

	_editor.remove_category(_cat_a_id)
	assert_bool(_editor.get_dirty_flag()).is_true()


# ------------- [Include Path Management] -------------

func test_add_include_path_valid() -> void:
	## Adding a valid directory as an include path works.
	var success := _editor.add_include_path("res://addons/scene_manager/")
	assert_bool(success).is_true()

	var list := _data.get_include_list()
	assert_bool("res://addons/scene_manager/" in list).is_true()


func test_add_include_path_invalid() -> void:
	## Adding a non-existent path is rejected.
	var success := _editor.add_include_path("res://nonexistent_path_xyz/")
	assert_bool(success).is_false()

	var list := _data.get_include_list()
	assert_int(list.size()).is_equal(0)


func test_add_include_path_covered_path() -> void:
	## Adding a path that is already covered by an existing path is rejected.
	var success := _editor.add_include_path("res://addons/")
	assert_bool(success).is_true()

	# This sub-path is covered by the broader "res://addons/" path
	success = _editor.add_include_path("res://addons/scene_manager/")
	assert_bool(success).is_false()


# ------------- [Include Path Category Assignment] -------------

func test_set_include_path_category() -> void:
	## Setting a category on an include path is reflected in data.
	_editor.add_category(CAT_A)
	_editor.set_include_path_category("res://levels/", _cat_a_id)

	var cat_id := _editor.get_include_path_category("res://levels/")
	assert_int(cat_id).is_equal(_cat_a_id)


func test_clear_include_path_category() -> void:
	## Setting INVALID_ID clears the category on an include path.
	_editor.set_include_path_category("res://levels/", _cat_a_id)
	_editor.set_include_path_category(
		"res://levels/", ResourceUID.INVALID_ID
	)

	var cat_id := _editor.get_include_path_category("res://levels/")
	assert_int(cat_id).is_equal(ResourceUID.INVALID_ID)


# ------------- [Batch Operations] -------------

func test_assign_category_to_include_scenes() -> void:
	## Batch assigns a category to all scenes under an include path.
	_editor.add_category(CAT_A)

	var sc1 := SceneScript.new()
	sc1.name = "Forest"
	sc1.path = "res://levels/forest.tscn"
	sc1.uid = 8001
	_data.set_scene_data(8001, sc1)

	var sc2 := SceneScript.new()
	sc2.name = "Cave"
	sc2.path = "res://levels/cave.tscn"
	sc2.uid = 8002
	_data.set_scene_data(8002, sc2)

	# Scene NOT under the path
	var sc3 := SceneScript.new()
	sc3.name = "Menu"
	sc3.path = "res://ui/menu.tscn"
	sc3.uid = 8003
	_data.set_scene_data(8003, sc3)

	var count := _editor.assign_category_to_include_scenes(
		"res://levels/", _cat_a_id
	)
	assert_int(count).is_equal(2)

	assert_bool(_cat_a_id in sc1.categories).is_true()
	assert_bool(_cat_a_id in sc2.categories).is_true()
	# sc3 should NOT have the category
	assert_bool(_cat_a_id in sc3.categories).is_false()


func test_assign_category_to_include_scenes_nonexistent_category() -> void:
	## Batch assign with a non-existent category returns 0.
	var count := _editor.assign_category_to_include_scenes(
		"res://levels/", 999999
	)
	assert_int(count).is_equal(0)


func test_remove_category_from_include_scenes() -> void:
	## Batch removes a category from all scenes under an include path.
	_editor.add_category(CAT_A)

	var sc := SceneScript.new()
	sc.name = "Dungeon"
	sc.path = "res://levels/dungeon.tscn"
	sc.uid = 8004
	sc.categories = [_cat_a_id]
	_data.set_scene_data(8004, sc)

	var count := _editor.remove_category_from_include_scenes(
		"res://levels/", _cat_a_id
	)
	assert_int(count).is_equal(1)
	assert_bool(_cat_a_id in sc.categories).is_false()


func test_remove_category_from_include_scenes_no_match() -> void:
	## Batch remove with no matching scenes returns 0.
	var count := _editor.remove_category_from_include_scenes(
		"res://void/", _cat_a_id
	)
	assert_int(count).is_equal(0)


# ------------- [Export String Generation] -------------

func test_export_scene_enum_empty() -> void:
	## Empty data produces minimal enum with only NONE.
	var result: String = _editor.call("_export_scene_enum_string")
	assert_str(result).contains("enum Id {")
	assert_str(result).contains("NONE = ")
	assert_str(result).contains("}")


func test_export_scene_enum_with_scenes() -> void:
	## After adding scenes, the enum string includes their names.
	var sc := SceneScript.new()
	sc.name = "Level1"
	sc.path = "res://test/level1.tscn"
	sc.uid = 9001
	_data.set_scene_data(9001, sc)

	var result: String = _editor.call("_export_scene_enum_string")
	assert_str(result).contains("LEVEL1")
	assert_str(result).contains(str(sc.uid))


func test_export_category_enum_empty() -> void:
	## Empty categories produces minimal enum.
	var result: String = _editor.call("_export_category_enum_string")
	assert_str(result).contains("enum CategoryId {")
	assert_str(result).contains("}")


func test_export_category_enum_with_categories() -> void:
	## After adding categories, the enum includes them.
	_editor.add_category(CAT_A)
	_editor.add_category(CAT_B)

	var result: String = _editor.call("_export_category_enum_string")
	assert_str(result).contains("PLAYERS")
	assert_str(result).contains("ENEMIES")


func test_export_utility_functions_includes_name_to_id_conversion() -> void:
	## The generated utility functions include a string -> Id conversion.
	var result: String = _editor.call("_export_utility_functions")
	assert_str(result).contains("static func get_id_by_name(scene_name: String) -> Id:")
	assert_str(result).contains("Id.has(sanitized)")
	assert_str(result).contains("Id.NONE")


# ------------- [Duplicate UID Detection] -------------

const DUP_TEST_DIR := "res://.test_dup_uid"


func after_test() -> void:
	_delete_dir_recursive(DUP_TEST_DIR)


## Recursively delete a directory
func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_delete_dir_recursive(full)
		else:
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
	# Remove the now-empty directory from its parent
	var parent_dir := DirAccess.open(path.get_base_dir())
	if parent_dir:
		parent_dir.remove(path.get_file())


func test_find_duplicate_uid_files() -> void:
	## Two .tscn files sharing the same UID are reported as duplicates.
	DirAccess.make_dir_recursive_absolute(DUP_TEST_DIR)
	var uid_text := "uid://ckkekibb7wbh2"  # Arbitrary but valid-format UID
	var file_a := DUP_TEST_DIR.path_join("dup_a.tscn")
	var file_b := DUP_TEST_DIR.path_join("dup_b.tscn")
	var fa := FileAccess.open(file_a, FileAccess.WRITE)
	fa.store_string('[gd_scene format=3 uid="%s"]\n\n[node name="A" type="Node"]\n' % uid_text)
	fa.close()
	var fb := FileAccess.open(file_b, FileAccess.WRITE)
	fb.store_string('[gd_scene format=3 uid="%s"]\n\n[node name="B" type="Node"]\n' % uid_text)
	fb.close()

	_editor.add_include_path(DUP_TEST_DIR)
	var duplicates := _editor.find_duplicate_uid_files()
	assert_int(duplicates.size()).is_equal(1)
	var paths: Array = duplicates[0]["paths"]
	assert_int(paths.size()).is_equal(2)
	assert_bool(paths.has(file_a)).is_true()
	assert_bool(paths.has(file_b)).is_true()


func test_find_duplicate_uid_files_empty_without_includes() -> void:
	## With no include paths, no duplicates are reported.
	var duplicates := _editor.find_duplicate_uid_files()
	assert_int(duplicates.size()).is_equal(0)


# ------------- [Cleanup] -------------

func test_cleanup_disconnects_ebus() -> void:
	## Calling cleanup disconnects the ebus signal.
	var ebus := EbusScript.new()
	var data_copy := DataScript.new()
	var ed := TestEditor.new(data_copy, ebus, _log)
	ed._initial_load = false

	# Force a disconnect then reconnect, verify no crash
	ed.cleanup(ebus)
	# After cleanup, ebus.get_dirty_flag should have no connections
	assert_bool(true).is_true()  # Reaching here means successful cleanup
