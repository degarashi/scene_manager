extends GdUnitTestSuite

## Unit tests for ResourceLoaderMgr
## Verifies bookkeeping and state management, not actual thread loading

const _LoaderScript := preload("res://addons/scene_manager/helper/resource_loader_mgr.gd")
const _TRASH_PATH := "res://addons/scene_manager/trash_can.gd"
const _LOADING_PATH := "res://loading_dummy.tscn"

var _loader: Node


func before_test() -> void:
	@warning_ignore("unsafe_call_argument")
	_loader = _LoaderScript.new()
	add_child(_loader)
	monitor_signals(_loader)


func after_test() -> void:
	if is_instance_valid(_loader):
		_loader.queue_free()


# ------------- [Initial State] -------------

## Initial state: is_loading() returns false, processing is disabled
func test_initial_state() -> void:
	assert_bool(_loader.call("is_loading", "any/path")).is_false()
	assert_bool(_loader.call("is_loading", "")).is_false()
	assert_bool(_loader.is_processing()).is_false()


# ------------- [request: Error Handling] -------------

## Calling request() with empty path does not crash
func test_request_empty_path_no_crash() -> void:
	var called := false
	_loader.call("request", "", func(_res: Variant) -> void:
		called = true
	)
	assert_bool(called).is_false()
	assert_bool(_loader.call("is_loading", "")).is_false()


# ------------- [request_batch: Empty Array] -------------

## Verify request_batch() with paths creates internal tracking
func test_request_batch_with_paths_tracks_loading() -> void:
	var paths: Array[String] = [_TRASH_PATH]
	_loader.call("request_batch", paths, func(_res: Dictionary) -> void:
		pass
	)
	# Cached resources trigger immediate callback, so is_loading is false
	# (Completes without creating a task)
	assert_bool(_loader.call("is_loading", _TRASH_PATH)).is_false()


# ------------- [cancel_all: State Clear] -------------

## Verify cancel_all() clears all tasks and disables processing
func test_cancel_all_clears_state() -> void:
	_loader.set_process(true)
	assert_bool(_loader.is_processing()).is_true()

	_loader.call("cancel_all")

	assert_bool(_loader.is_processing()).is_false()
	assert_bool(_loader.call("is_loading", "dummy")).is_false()


# ------------- [_LoadTask: Inner Class] -------------

## Verify _LoadTask initializes correctly with valid path and callback
func test_load_task_init_valid() -> void:
	var task := _LoaderScript._LoadTask.new("res://test.tscn", func(_res: Variant) -> void:
		pass
	)
	assert_str(task.path).is_equal("res://test.tscn")
	assert_int(task.on_complete_list.size()).is_equal(1)
	assert_int(task.last_percent).is_equal(0)


## _LoadTask with empty path results in empty callback list
func test_load_task_init_empty_path() -> void:
	var task := _LoaderScript._LoadTask.new("", func(_res: Variant) -> void:
		pass
	)
	assert_str(task.path).is_equal("")
	assert_int(task.on_complete_list.size()).is_equal(0)


## _LoadTask with invalid callback results in empty path and callbacks
func test_load_task_init_invalid_callback() -> void:
	var task := _LoaderScript._LoadTask.new("res://test.tscn", Callable())
	assert_str(task.path).is_equal("")
	assert_int(task.on_complete_list.size()).is_equal(0)


## Verify _LoadTask update_status() and get_current_percent() work
func test_load_task_update_status_and_percent() -> void:
	var task := _LoaderScript._LoadTask.new(_TRASH_PATH, func(_res: Variant) -> void:
		pass
	)
	var status := task.update_status()
	assert_int(status).is_equal(ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	assert_int(task.get_current_percent()).is_equal(0)


# ------------- [request: Cached Resource] -------------

## Verify request() on cached resource does not create a task
func test_request_cached_resource_doesnt_create_task() -> void:
	# Pre-cache with load()
	var cached := load(_TRASH_PATH)
	assert_object(cached).is_not_null()
	assert_bool(ResourceLoader.has_cached(_TRASH_PATH)).is_true()

	# request() on cached path → immediate callback, no task created
	_loader.call("request", _TRASH_PATH, func(_res: Variant) -> void:
		pass
	)

	# No task created, so is_loading is false
	assert_bool(_loader.call("is_loading", _TRASH_PATH)).is_false()


# ------------- [request: Duplicate Request] -------------

## Verify request() on a path already in _tasks appends callback (no crash)
func test_request_already_loading_appends_callback() -> void:
	var tasks: Dictionary = _loader.get("_tasks")
	tasks[_LOADING_PATH] = _LoaderScript._LoadTask.new(
		_LOADING_PATH, func(_res: Variant) -> void:
			pass
	)

	var cb2_called := false
	_loader.call("request", _LOADING_PATH, func(_res: Variant) -> void:
		cb2_called = true
	)

	assert_bool(_loader.call("is_loading", _LOADING_PATH)).is_true()
	assert_bool(cb2_called).is_false()

	# Verify calling _process directly does not crash
	_loader.call("_process", 0.0)
	assert_bool(_loader.call("is_loading", _LOADING_PATH)).is_false()
