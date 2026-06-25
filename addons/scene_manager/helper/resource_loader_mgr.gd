## Asynchronous resource loading manager
extends Node

# ------------- [Signal] -------------
## Emitted when a task's progress changes.
signal progress_changed(path: String, percent: int)
## Emitted when a task is successfully completed.
signal load_completed(path: String, resource: Resource)
## Emitted when a batch of tasks is completed.
signal batch_completed(resources: Dictionary)

# ------------- [Constants] -------------
static var _log := DLoggerClass.new("Scene Manager")


# ------------- [Defines] -------------
class _LoadTask:
	var path: String
	var progress: Array[float] = [0.0]
	var status := ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
	var last_percent: int = 0
	## Callbacks on completion: func(res: Resource)
	var on_complete_list: Array[Callable]

	func _init(p_path: String, p_callback: Callable) -> void:
		assert(not p_path.is_empty(), "_LoadTask: Path cannot be empty.")
		assert(p_callback.is_valid(), "_LoadTask: Callback must be a valid callable.")
		path = p_path
		on_complete_list = [p_callback]

	## Updates the loading status and progress.
	func update_status() -> ResourceLoader.ThreadLoadStatus:
		status = ResourceLoader.load_threaded_get_status(path, progress)
		return status

	func get_current_percent() -> int:
		return int(progress[0] * 100)


## Helper class to track a group of resources
class _BatchTask:
	var remaining_count: int
	var results: Dictionary = {}  # Key: path, Value: Resource
	var on_all_complete: Callable

	func _init(p_count: int, p_callback: Callable) -> void:
		assert(p_callback.is_valid(), "_BatchTask: Callback must be a valid callable.")
		remaining_count = p_count
		on_all_complete = p_callback

	func mark_complete(path: String, res: Resource) -> bool:
		if not results.has(path):
			results[path] = res
			remaining_count -= 1
		return remaining_count <= 0


# ------------- [Private Variable] -------------
## All active tasks (Key: path)
var _tasks: Dictionary[String, _LoadTask] = {}
## Tracking active batches (Key: path, Value: Array of _BatchTask)
var _path_to_batches: Dictionary[String, Array] = {}


# ------------- [Callbacks] -------------
func _ready() -> void:
	# Initially disable processing until a request is made
	set_process(false)


func _process(_delta: float) -> void:
	if _tasks.is_empty():
		set_process(false)
		return

	# Use a temporary list for removal to avoid dictionary mutation issues during iteration
	var completed_paths: Array[String] = []
	for path in _tasks:
		var task: _LoadTask = _tasks[path]
		if _update_task(task):
			completed_paths.append(path)

	for path in completed_paths:
		_tasks.erase(path)


# ------------- [Private Method] -------------
## Returns true if the task is finished (loaded or failed).
func _update_task(task: _LoadTask) -> bool:
	var status := task.update_status()

	# Notify progress changes
	var current_percent := task.get_current_percent()
	if current_percent != task.last_percent:
		task.last_percent = current_percent
		progress_changed.emit(task.path, current_percent)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(task.path)
			_finalize_task(task, res)
			return true

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_log.warn("ResourceLoaderMgr: Load failed or invalid resource: {0}", [task.path])
			_finalize_task(task, null)
			return true

		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false

	return false


func _finalize_task(task: _LoadTask, res: Resource) -> void:
	load_completed.emit(task.path, res)

	# Execute individual callbacks
	for cb in task.on_complete_list:
		if cb.is_valid():
			cb.call(res)

	# Check if this task belongs to any batches
	if _path_to_batches.has(task.path):
		var batches: Array[_BatchTask] = _path_to_batches[task.path]
		for batch in batches:
			var is_batch_done := batch.mark_complete(task.path, res)
			if is_batch_done:
				_finalize_batch(batch)
		_path_to_batches.erase(task.path)


func _finalize_batch(batch: _BatchTask) -> void:
	batch_completed.emit(batch.results)
	if batch.on_all_complete.is_valid():
		batch.on_all_complete.call(batch.results)


# ------------- [Public Method] -------------
## Request a resource to be loaded
func request(path: String, callback: Callable, use_sub_threads: bool = true) -> void:
	assert(not path.is_empty(), "ResourceLoaderMgr: Requested path is empty.")

	# If already loaded in ResourceLoader, handle immediately
	if ResourceLoader.has_cached(path):
		var res := load(path)
		if callback.is_valid():
			callback.call(res)
		return

	if _tasks.has(path):
		if callback.is_valid():
			_tasks[path].on_complete_list.append(callback)
		return

	var err := ResourceLoader.load_threaded_request(path, "", use_sub_threads)
	if err == OK:
		_tasks[path] = _LoadTask.new(path, callback)
		set_process(true)
	else:
		_log.warn("ResourceLoaderMgr: Request failed for path: {0} (Error: {1})", [path, err])


## Request multiple resources to be loaded
## callback: func(results: Dictionary) where Dictionary is { "path": Resource }
func request_batch(paths: Array[String], callback: Callable, use_sub_threads: bool = true) -> void:
	if paths.is_empty():
		if callback.is_valid():
			callback.call({})
		return

	var batch := _BatchTask.new(paths.size(), callback)

	for path in paths:
		# Map this path to the batch for tracking
		if not _path_to_batches.has(path):
			_path_to_batches[path] = []
		_path_to_batches[path].append(batch)

		# If task already exists, just wait for it. Otherwise, start new.
		if _tasks.has(path):
			continue

		# Use a dummy callback for the individual request as we use batch tracking
		request(path, func(_res) -> void: pass, use_sub_threads)


## Checks if a specific path is currently being loaded.
func is_loading(path: String) -> bool:
	return _tasks.has(path)


## Cancels all active loading tasks.
func cancel_all() -> void:
	_tasks.clear()
	_path_to_batches.clear()
	set_process(false)
