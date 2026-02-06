extends Control

## UI References
@onready var _move_to_next_scene_button: Button = %MoveToNextSceneButton
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _next_scene_label: Label = %NextSceneLabel


func _ready() -> void:
	# Signal connections
	SceneManager.load_percent_changed.connect(_set_load_percent)
	SceneManager.load_finished.connect(_on_load_finished)

	_update_next_scene_label()

	# Start asynchronous loading
	# Requests a load using the scene ID reserved by load_scene_with_transition
	var resv_scene := SceneManager.get_reserved_scene()
	if resv_scene != Scenes.Id.NONE:
		SceneManager.preload_scene_async(resv_scene)
	else:
		push_error("No reserved scene found.")


## Updates the label with the name of the next scene
func _update_next_scene_label() -> void:
	var scene_id := SceneManager.get_reserved_scene()
	# Display the name of the next scene in the label
	# (Uses SceneManagerUtils or Scenes class enum conversion)
	if scene_id != Scenes.Id.NONE:
		var scene_name := SceneManagerUtils.get_enum_string_from_enum(scene_id)
		_next_scene_label.text = scene_name
	else:
		_next_scene_label.text = "(None)"


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
