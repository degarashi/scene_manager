extends GdUnitTestSuite

## Tests for async loading functionality in the Scene Manager addon.
## Focuses on ResourceLoaderMgr (the core async loading engine).
## Note: resource_loader_mgr.gd has no class_name, so all access goes
## through Variant-typed references. Per-line @warning_ignore is needed.
## Batch and signal tests require the UID cache to be rebuilt first.

const RLMScript = preload("res://addons/scene_manager/helper/resource_loader_mgr.gd")
const ScenesScript = preload("res://scene_manager_data/scenes.gd")

var _scenes_cls: Node

func before() -> void:
	_scenes_cls = ScenesScript.new()
	add_child(_scenes_cls)
	await get_tree().create_timer(0.5).timeout

func after() -> void:
	await get_tree().create_timer(0.5).timeout

# --- Lifecycle ---

func test_01_initializes_with_empty_tasks() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	assert_dict(l.get("_tasks")).is_empty()
	l.call("cancel_all")
	l.queue_free()

func test_02_process_disabled_initially() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	assert_bool(l.is_processing()).is_false()
	l.call("cancel_all")
	l.queue_free()

func test_03_process_enabled_after_request() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	var p: String = ScenesScript.get_scene_path(Scenes.Id.SCENE_0)
	l.call("request", p, func(_r: Resource) -> void: pass)
	assert_bool(l.is_processing()).is_true()
	l.call("cancel_all")
	l.queue_free()

# --- is_loading ---

func test_04_is_loading_false_for_unknown() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	@warning_ignore("unsafe_cast")
	assert_bool(l.call("is_loading", "res://nonexistent.tscn") as bool).is_false()
	l.call("cancel_all")
	l.queue_free()

func test_05_is_loading_reflects_request() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	var p: String = ScenesScript.get_scene_path(Scenes.Id.SCENE_0)
	l.call("request", p, func(_r: Resource) -> void: pass)
	@warning_ignore("unsafe_cast")
	var active := l.call("is_loading", p) as bool
	var cached := ResourceLoader.has_cached(p)
	assert_bool(active or cached).is_true()
	l.call("cancel_all")
	l.queue_free()

# --- request ---

func test_06_request_empty_path_no_crash() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	var called := false
	l.call("request", "", func(_r: Resource) -> void: called = true)
	assert_bool(called).is_false()
	l.call("cancel_all")
	l.queue_free()

# --- cancel_all ---

func test_07_cancel_clears_tasks() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	var p: String = ScenesScript.get_scene_path(Scenes.Id.SCENE_0)
	l.call("request", p, func(_r: Resource) -> void: pass)
	l.call("cancel_all")
	assert_dict(l.get("_tasks")).is_empty()
	l.queue_free()

func test_08_cancel_stops_processing() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	var p: String = ScenesScript.get_scene_path(Scenes.Id.SCENE_0)
	l.call("request", p, func(_r: Resource) -> void: pass)
	l.call("cancel_all")
	assert_bool(l.is_processing()).is_false()
	l.queue_free()

# --- Async load with threaded resource ---

func test_09_request_valid_path_creates_task() -> void:
	@warning_ignore("unsafe_call_argument")
	var l = RLMScript.new()
	@warning_ignore("unsafe_call_argument")
	add_child(l)
	var p: String = ScenesScript.get_scene_path(Scenes.Id.SCENE_0)
	@warning_ignore("unsafe_method_access")
	l.request(p, func(_res: Resource) -> void: pass)
	# Request accepted: either a task was created or resource was cached
	@warning_ignore("unsafe_cast")
	var active := l.call("is_loading", p) as bool
	var cached := ResourceLoader.has_cached(p)
	assert_bool(active or cached).is_true()
	l.call("cancel_all")
	l.queue_free()
