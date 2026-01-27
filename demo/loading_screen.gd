extends Control

## UI References
@onready var _move_to_next_scene_button: Button = %MoveToNextSceneButton
@onready var _progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	# Signal connections
	SceneManager.load_percent_changed.connect(_set_load_percent)
	SceneManager.load_finished.connect(_on_load_finished)

	# Start asynchronous loading
	# Requests a load using the scene ID reserved by load_scene_with_transition
	if SceneManager._reserved_scene_id != Scenes.Id.NONE:
		SceneManager.preload_scene_async(SceneManager._reserved_scene_id)
	else:
		push_error("No reserved scene found.")


## Logic for when the progress percentage is updated
func _set_load_percent(value: int) -> void:
	_progress_bar.value = value


## Logic for when the loading process is finished
func _on_load_finished() -> void:
	# Instantiate the loaded scene (placed behind the scenes for now)
	SceneManager.instantiate_async_result()

	# Add a slight delay so the loading screen doesn't disappear too abruptly (optional)
	await get_tree().create_timer(0.3).timeout

	# Set progress bar to 100% and show the button to proceed
	_progress_bar.value = 100
	_move_to_next_scene_button.visible = true
	_move_to_next_scene_button.grab_focus()


## Logic for when the "Move To Next Scene" button is pressed
func _on_move_to_next_scene_button_button_up() -> void:
	# Disable button to prevent multiple clicks
	_move_to_next_scene_button.disabled = true

	# Switch the scene (fades out and removes the loading screen)
	SceneManager.activate_prepared_scene()
