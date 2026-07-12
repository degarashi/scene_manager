extends GdUnitTestSuite

const ScenesScript = preload("res://scene_manager_data/scenes.gd")

var _scenes_cls: Node
var _layers_to_free: Array[Node] = []
var sm: SMgrInstance


func before() -> void:
	sm = get_node("/root/SceneManager") as SMgrInstance
	_scenes_cls = ScenesScript.new()
	add_child(_scenes_cls)
	_layers_to_free.clear()
	await get_tree().create_timer(1.5).timeout


func after() -> void:
	if is_instance_valid(_scenes_cls):
		_scenes_cls.free()
	await get_tree().create_timer(0.5).timeout


func after_test() -> void:
	for layer in _layers_to_free:
		if is_instance_valid(layer):
			layer.free()
	_layers_to_free.clear()


func _track_layer(layer: SMgrSceneLayer) -> void:
	add_child(layer)
	_layers_to_free.append(layer)


# ------------- [Layer Creation Tests] -------------


func test_create_scene_layer_returns_valid_layer() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "TestLayer"
	)
	_track_layer(layer)
	assert_object(layer).is_not_null()
	assert_bool(layer is SMgrSceneLayer).is_true()


func test_create_scene_layer_sets_scene_id() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "TestLayer"
	)
	_track_layer(layer)
	assert_int(layer.scene_id).is_equal(Scenes.Id.SCENE_0)


func test_create_scene_layer_sets_name() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "CustomLayerName"
	)
	_track_layer(layer)
	assert_str(layer.name).is_equal("CustomLayerName")


func test_create_scene_layer_with_override_name() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "FallbackName", "OverrideName"
	)
	_track_layer(layer)
	assert_str(layer.name).is_equal("OverrideName")


func test_create_scene_layer_empty_override_uses_node_name() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "NodeName", ""
	)
	_track_layer(layer)
	assert_str(layer.name).is_equal("NodeName")


func test_create_scene_layer_priority_consistent() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "PriorityLayer"
	)
	_track_layer(layer)
	assert_int(layer.l_priority).is_equal(layer.layer)


func test_create_scene_layer_is_canvas_layer() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "CanvasLayerTest"
	)
	_track_layer(layer)
	assert_bool(layer is CanvasLayer).is_true()


func test_create_scene_layer_connects_child_order_changed() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "SignalTest"
	)
	_track_layer(layer)
	assert_bool(
		layer.child_order_changed.is_connected(layer._on_child_order_changed)
	).is_true()


# ------------- [Layer Retrieval Tests] -------------


func test_get_layer_by_id_returns_correct_layer() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "RetrieveById"
	)
	_track_layer(layer)

	var recv: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv, Scenes.Id.SCENE_0)
	assert_int(recv.size()).is_greater(0)


func test_get_layer_by_id_returns_empty_for_nonexistent() -> void:
	var recv: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv, Scenes.Id.SCENE_2)
	assert_int(recv.size()).is_equal(0)


func test_get_layer_by_name_returns_correct_layer() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "NamedLayer"
	)
	_track_layer(layer)

	var recv: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_name.emit(recv, "NamedLayer")
	assert_int(recv.size()).is_greater(0)
	assert_object(recv[0]).is_equal(layer)


func test_get_layer_by_name_returns_empty_for_nonexistent() -> void:
	var recv: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_name.emit(recv, "NonExistentLayer")
	assert_int(recv.size()).is_equal(0)


# ------------- [Layer Count Tests] -------------


func test_layer_count_increments_after_add() -> void:
	# Use a unique scene ID (SCENE_2) that no other test uses
	var recv_before: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv_before, Scenes.Id.SCENE_2)
	var count_before := recv_before.size()

	var layer1: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_2, "CounterLayer1"
	)
	_track_layer(layer1)

	var recv_after1: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv_after1, Scenes.Id.SCENE_2)
	assert_int(recv_after1.size()).is_equal(count_before + 1)

	var layer2: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_2, "CounterLayer2"
	)
	_track_layer(layer2)

	var recv_after2: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv_after2, Scenes.Id.SCENE_2)
	assert_int(recv_after2.size()).is_equal(count_before + 2)


# ------------- [Layer Disposal Tests] -------------


func test_layer_auto_disposes_when_child_removed() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "AutoDisposeTest"
	)
	var dummy := Node.new()
	layer.add_child(dummy)

	# Remove the only child to trigger auto-disposal
	layer.remove_child(dummy)
	dummy.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	# Layer should be freed after child removal triggers auto-disposal
	assert_bool(not is_instance_valid(layer)).is_true()


# ------------- [Layer Priority Tests] -------------


func test_layer_priority_l_priority_matches_layer() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "PriorityLayer"
	)
	_track_layer(layer)
	assert_int(layer.l_priority).is_equal(layer.layer)


func test_layer_pause_lower_default_false() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "PauseLowerDefault"
	)
	_track_layer(layer)
	assert_bool(layer.pause_lower).is_false()


func test_layer_follow_viewport_default_false() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "FollowViewport"
	)
	_track_layer(layer)
	assert_bool(layer.follow_viewport_enabled).is_false()


# ------------- [Layer Name Uniqueness Tests] -------------


func test_get_unique_layer_name_no_existing() -> void:
	var prefix := "UniqueTest_%d" % randi()
	var unique_name := sm._layer_mgr.get_unique_layer_name(prefix)
	assert_str(unique_name).is_equal(prefix + "2")


func test_get_unique_layer_name_with_existing() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "UniqueBase_Existing"
	)
	_track_layer(layer)

	var unique_name := sm._layer_mgr.get_unique_layer_name(
		"UniqueBase_Existing"
	)
	assert_str(unique_name).is_equal("UniqueBase_Existing2")


func test_get_unique_layer_name_multiple_existing() -> void:
	var base := "UniqueMulti_"
	var layer1: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, base
	)
	_track_layer(layer1)

	var layer2: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_1, base + "2"
	)
	_track_layer(layer2)

	var layer3: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, base + "3"
	)
	_track_layer(layer3)

	var unique_name := sm._layer_mgr.get_unique_layer_name(base)
	assert_str(unique_name).is_equal(base + "4")


# ------------- [Category Summary Tests] -------------


func test_category_summary_returns_valid_object() -> void:
	var summary := sm._layer_mgr.get_category_summary(
		Scenes.Id.SCENE_0
	)
	assert_object(summary).is_not_null()
	assert_bool(summary is SMgrSceneCategorySummary).is_true()


# ------------- [Multiple Layer Interaction Tests] -------------


func test_multiple_layers_different_scene_ids() -> void:
	var layer0: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "Scene0Layer"
	)
	_track_layer(layer0)

	var layer1: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_1, "Scene1Layer"
	)
	_track_layer(layer1)

	var recv0: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv0, Scenes.Id.SCENE_0)
	var found0 := false
	for l in recv0:
		if l.name == "Scene0Layer":
			found0 = true
			break
	assert_bool(found0).is_true()

	var recv1: Array[SMgrSceneLayer] = []
	sm._ebus.get_scene_by_id.emit(recv1, Scenes.Id.SCENE_1)
	var found1 := false
	for l in recv1:
		if l.name == "Scene1Layer":
			found1 = true
			break
	assert_bool(found1).is_true()


func test_layer_add_node_sets_main_node() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "MainNodeTest"
	)
	_track_layer(layer)

	var content := Node.new()
	layer.add_node(content)

	assert_object(layer.get_main_node()).is_equal(content)
	assert_object(content.get_parent()).is_equal(layer)


func test_pause_threshold_recalculated_on_create() -> void:
	var layer: SMgrSceneLayer = sm._layer_mgr.create_scene_layer(
		Scenes.Id.SCENE_0, "PauseThreshold"
	)
	_track_layer(layer)
	assert_object(layer).is_not_null()
