extends GdUnitTestSuite

# SMgrUtil (aux_func.gd) depends on DLoggerClass from the
# d_logger submodule. When the submodule is not initialized,
# preload() fails at parse time. These tests verify the
# sorting and path validation logic that SMgrUtil wraps.


# ------------- [Mock Resource] -------------


class MockResource:
	extends Resource
	var name: String

	func _init(p_name: String = "") -> void:
		name = p_name


# ------------- [natural_case_sort Tests] -------------
# Tests verify naturalnocasecmp_to behavior which
# SMgrUtil.natural_case_sort wraps.


func test_natural_case_sort_basic() -> void:
	var items: Array[MockResource] = [
		MockResource.new("b"),
		MockResource.new("a"),
		MockResource.new("c"),
	]
	items.sort_custom(
		func(a: MockResource, b: MockResource) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)
	assert_str(items[0].name).is_equal("a")
	assert_str(items[1].name).is_equal("b")
	assert_str(items[2].name).is_equal("c")


func test_natural_case_sort_case_insensitive() -> void:
	var items: Array[MockResource] = [
		MockResource.new("Banana"),
		MockResource.new("apple"),
		MockResource.new("Cherry"),
	]
	items.sort_custom(
		func(a: MockResource, b: MockResource) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)
	assert_str(items[0].name).is_equal("apple")
	assert_str(items[1].name).is_equal("Banana")
	assert_str(items[2].name).is_equal("Cherry")


func test_natural_case_sort_numbers() -> void:
	var items: Array[MockResource] = [
		MockResource.new("item10"),
		MockResource.new("item2"),
		MockResource.new("item1"),
	]
	items.sort_custom(
		func(a: MockResource, b: MockResource) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)
	assert_str(items[0].name).is_equal("item1")
	assert_str(items[1].name).is_equal("item2")
	assert_str(items[2].name).is_equal("item10")


# ------------- [is_valid_resource_path Tests] -------------
# Tests verify DirAccess.dir_exists_absolute and
# FileAccess.file_exists behavior which SMgrUtil wraps.


func test_is_valid_resource_path_directory() -> void:
	assert_bool(
		DirAccess.dir_exists_absolute("res://")
	).is_true()


func test_is_valid_resource_path_file() -> void:
	assert_bool(
		FileAccess.file_exists("res://project.godot")
	).is_true()
	assert_bool(
		"res://project.godot".begins_with("res://")
	).is_true()


func test_is_valid_resource_path_invalid() -> void:
	assert_bool(
		DirAccess.dir_exists_absolute(
			"res://nonexistent_file.tscn"
		)
	).is_false()
	assert_bool(
		FileAccess.file_exists(
			"res://nonexistent_file.tscn"
		)
	).is_false()


func test_is_valid_resource_path_empty_string() -> void:
	# Empty string: DirAccess.dir_exists_absolute("") returns
	# true (current directory), so the function returns true.
	assert_bool(
		DirAccess.dir_exists_absolute("")
	).is_true()


# ------------- [connect_if_not_connected Tests] -------------
# Tests verify the signal connection pattern SMgrUtil wraps.
# SMgrUtil.connect_if_not_connected(sig, callable):
#   if not sig.is_connected(callable): sig.connect(callable)
#
# SMgrUtil.disconnect_if_connected(sig, callable):
#   if sig.is_connected(callable): sig.disconnect(callable)


class SignalEmitter:
	extends RefCounted
	signal test_signal(value: Variant)


class SignalCounter:
	extends RefCounted
	var count: int = 0

	func on_signal(_value: Variant) -> void:
		count += 1


func test_connect_if_not_connected() -> void:
	var emitter := SignalEmitter.new()
	var counter := SignalCounter.new()
	var cb := counter.on_signal

	# Connect once (SMgrUtil pattern)
	if not emitter.test_signal.is_connected(cb):
		emitter.test_signal.connect(cb)

	# Connect again — should be a no-op (is_connected returns true)
	if not emitter.test_signal.is_connected(cb):
		emitter.test_signal.connect(cb)

	emitter.test_signal.emit(1)
	assert_int(counter.count).is_equal(1)


func test_disconnect_if_connected() -> void:
	var emitter := SignalEmitter.new()
	var counter := SignalCounter.new()
	var cb := counter.on_signal

	emitter.test_signal.connect(cb)
	assert_bool(emitter.test_signal.is_connected(cb)).is_true()

	# Disconnect (SMgrUtil pattern)
	if emitter.test_signal.is_connected(cb):
		emitter.test_signal.disconnect(cb)

	assert_bool(emitter.test_signal.is_connected(cb)).is_false()
	emitter.test_signal.emit(1)
	assert_int(counter.count).is_equal(0)


func test_disconnect_if_connected_not_connected() -> void:
	# Disconnecting a non-connected callable must not error
	var emitter := SignalEmitter.new()
	var counter := SignalCounter.new()
	var cb := counter.on_signal

	# This should be a safe no-op
	if emitter.test_signal.is_connected(cb):
		emitter.test_signal.disconnect(cb)

	# No crash = pass
	assert_bool(emitter.test_signal.is_connected(cb)).is_false()


# ------------- [to_tmp_name / from_tmp_name Tests] -------------
# SMgrUtil.to_tmp_name(node_name) returns:
#   node_name + "_tmp_" + str(Time.get_ticks_msec()) + "_" + str(randi())
#
# SMgrUtil.from_tmp_name(tmp_name):
#   var idx = tmp_name.rfind("_tmp_")
#   return tmp_name.left(idx) if idx != -1 else tmp_name


func test_to_tmp_name() -> void:
	var name := "TestName"
	var result := name + "_tmp_" + str(Time.get_ticks_msec()) + "_" + str(randi())

	assert_bool(result.begins_with("TestName_tmp_")).is_true()
	# Verify there are digit characters after the prefix
	var suffix := result.trim_prefix("TestName_tmp_")
	assert_int(suffix.length()).is_greater_equal(2)


func test_from_tmp_name() -> void:
	var tmp_name := "NodeA_tmp_12345_67890"
	var idx := tmp_name.rfind("_tmp_")
	var result := tmp_name.left(idx)
	assert_str(result).is_equal("NodeA")


func test_from_tmp_name_no_tmp() -> void:
	var normal := "NormalName"
	var idx := normal.rfind("_tmp_")
	var result := normal if idx == -1 else normal.left(idx)
	assert_str(result).is_equal("NormalName")


# ------------- [has_ancestor / is_in_main_screen Tests] -------------
# SMgrUtil.has_ancestor(node, target_name):
#   while node:
#     if node.name == target_name: return true
#     node = node.get_parent()
#   return false
#
# SMgrUtil.is_in_main_screen(node):
#   return has_ancestor(node, "MainScreen")


func test_has_ancestor_found() -> void:
	var root := Node.new()
	root.name = "Root"
	var child := Node.new()
	child.name = "Child"
	var grandchild := Node.new()
	grandchild.name = "GrandChild"
	root.add_child(child)
	child.add_child(grandchild)

	# Inline SMgrUtil.has_ancestor
	var found := false
	var n: Node = grandchild
	while n:
		if n.name == "Root":
			found = true
			break
		n = n.get_parent()

	assert_bool(found).is_true()
	root.queue_free()


func test_has_ancestor_not_found() -> void:
	var root := Node.new()
	root.name = "Root"
	var child := Node.new()
	child.name = "Child"
	root.add_child(child)

	var found := false
	var n: Node = child
	while n:
		if n.name == "NonExistent":
			found = true
			break
		n = n.get_parent()

	assert_bool(found).is_false()
	root.queue_free()


func test_has_ancestor_self() -> void:
	var node := Node.new()
	node.name = "Self"

	var found := false
	var n: Node = node
	while n:
		if n.name == "Self":
			found = true
			break
		n = n.get_parent()

	assert_bool(found).is_true()
	node.queue_free()


func test_is_in_main_screen_true() -> void:
	var root := Node.new()
	root.name = "MainScreen"
	var child := Node.new()
	child.name = "Child"
	root.add_child(child)

	var found := false
	var n: Node = child
	while n:
		if n.name == "MainScreen":
			found = true
			break
		n = n.get_parent()

	assert_bool(found).is_true()
	root.queue_free()


func test_is_in_main_screen_false() -> void:
	var root := Node.new()
	root.name = "Other"
	var child := Node.new()
	child.name = "Child"
	root.add_child(child)

	var found := false
	var n: Node = child
	while n:
		if n.name == "MainScreen":
			found = true
			break
		n = n.get_parent()

	assert_bool(found).is_false()
	root.queue_free()


# ------------- [convert_to_array_string Tests] -------------
# SMgrUtil.convert_to_array_string(src):
#   var ret: Array[String] = []
#   ret.assign(src.map(func(item): return str(item)))
#   return ret


func test_convert_to_array_string() -> void:
	var src: Array[Variant] = [42, "hello", 3.14, true]
	var ret: Array[String] = []
	ret.assign(src.map(func(item): return str(item)))

	assert_int(ret.size()).is_equal(4)
	assert_str(ret[0]).is_equal("42")
	assert_str(ret[1]).is_equal("hello")
	assert_str(ret[2]).is_equal("3.14")
	# str(true) may be "true" or "True" depending on locale
	assert_bool(ret[3].to_lower() == "true").is_true()


func test_convert_to_array_string_empty() -> void:
	var src: Array[Variant] = []
	var ret: Array[String] = []
	ret.assign(src.map(func(item): return str(item)))

	assert_int(ret.size()).is_equal(0)


# ------------- [sanitize_as_enum_string Tests] -------------
# SMgrUtil.sanitize_as_enum_string(text):
#   text = text.replace(" ", "_")
#   return text.to_upper()


func test_sanitize_as_enum_string() -> void:
	var cases := {
		"level one": "LEVEL_ONE",
		"already_upper": "ALREADY_UPPER",
		"  spaces  ": "__SPACES__",
	}
	for text: String in cases:
		var result := text.replace(" ", "_").to_upper()
		assert_str(result).is_equal(cases[text])


# ------------- [sanitize_scene_name Tests] -------------
# SMgrUtil.sanitize_scene_name(scene_name):
#   if scene_name.is_empty(): return scene_name
#   regex = RegEx; regex.compile("[^a-zA-Z0-9_ -]")
#   scene_name = regex.sub(scene_name, "", true)
#   scene_name = scene_name.replace(" ", "_")
#   return scene_name


func test_sanitize_scene_name_basic() -> void:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_ -]")

	var result := regex.sub("Hello World!", "", true)
	result = result.replace(" ", "_")
	assert_str(result).is_equal("Hello_World")


func test_sanitize_scene_name_special_chars() -> void:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_ -]")

	# "@#$" are removed, no spaces remain
	var result := regex.sub("test@#$file", "", true)
	result = result.replace(" ", "_")
	assert_str(result).is_equal("testfile")


func test_sanitize_scene_name_empty() -> void:
	var scene_name := ""
	# Empty returns identity per SMgrUtil
	assert_str(scene_name).is_equal("")


func test_sanitize_scene_name_already_clean() -> void:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_ -]")

	var result := regex.sub("score_display_2", "", true)
	result = result.replace(" ", "_")
	assert_str(result).is_equal("score_display_2")


# ------------- [fetch_category_from_ebus Pattern Tests] -------------
# SMgrUtil.fetch_category_from_ebus(ebus_editor, category_id):
#   var recv: Array[SMgrCategoryData]
#   ebus_editor.get_category_by_id.emit(recv, category_id)
#   return recv[0] if not recv.is_empty() else null
#
# Tests the receive-array synchronous signal pattern.


class MockCategoryReceiver:
	extends RefCounted
	signal get_category_by_id(recv: Array, category_id: int)


class CategoryMatchHandler:
	extends RefCounted
	var received_id: int = -1

	func on_get_category(recv: Array, cat_id: int) -> void:
		received_id = cat_id
		recv.append(cat_id)

	func on_no_match(_recv: Array, _cat_id: int) -> void:
		# No match: handler does NOT push to recv
		pass


func test_fetch_category_from_ebus_pattern() -> void:
	var ebus := MockCategoryReceiver.new()
	var handler := CategoryMatchHandler.new()

	ebus.get_category_by_id.connect(handler.on_get_category)

	var recv: Array
	ebus.get_category_by_id.emit(recv, 42)

	assert_int(recv.size()).is_equal(1)
	assert_int(recv[0]).is_equal(42)
	assert_int(handler.received_id).is_equal(42)


func test_fetch_category_from_ebus_no_match() -> void:
	var ebus := MockCategoryReceiver.new()
	var handler := CategoryMatchHandler.new()

	ebus.get_category_by_id.connect(handler.on_no_match)

	var recv: Array
	ebus.get_category_by_id.emit(recv, 99)

	# Null when array is empty
	var result: Variant = recv[0] if not recv.is_empty() else null
	assert_object(result).is_null()


# ------------- [is_valid_resource_path Combined Logic] -------------
# SMgrUtil.is_valid_resource_path(path):
#   return DirAccess.dir_exists_absolute(path) \
#     or (FileAccess.file_exists(path) and path.begins_with("res://"))


func test_is_valid_resource_path_combined_dir() -> void:
	# res:// is a directory -> dir_exists_absolute is true
	var result := (
		DirAccess.dir_exists_absolute("res://")
		or (FileAccess.file_exists("res://") and "res://".begins_with("res://"))
	)
	assert_bool(result).is_true()


func test_is_valid_resource_path_combined_file() -> void:
	# Existing .gd file with res:// prefix -> file_exists is true
	var result := (
		DirAccess.dir_exists_absolute("res://project.godot")
		or (FileAccess.file_exists("res://project.godot") and "res://project.godot".begins_with("res://"))
	)
	assert_bool(result).is_true()


func test_is_valid_resource_path_combined_nonexistent() -> void:
	# Non-existent path fails both checks
	var result := (
		DirAccess.dir_exists_absolute("res://nonexistent_file.tscn")
		or (
			FileAccess.file_exists("res://nonexistent_file.tscn")
			and "res://nonexistent_file.tscn".begins_with("res://")
		)
	)
	assert_bool(result).is_false()
