extends Button

@export var scene: SceneResource
@export var mode: SceneManagerConstants.SceneLoadingMode
@export var fade_out_speed: float = 1.0
@export var fade_in_speed: float = 1.0
@export var clickable: bool = false
@export var add_to_back: bool = true


func _on_button_button_up():
	if scene == null:
		return

	SceneManager.load_scene(scene.scene_value)


func _on_button_additive_up():
	if scene == null:
		return

	var options := SceneLoadOptions.new(
		SceneManagerConstants.DEFAULT_TREE_NODE_NAME,
		SceneManagerConstants.SceneLoadingMode.ADDITIVE,
		true,
		0.0,
		0.0,
		true
	)
	SceneManager.load_scene(scene.scene_value, options)


func _on_button_additive_node_up():
	if scene == null:
		return

	var options := SceneLoadOptions.new(
		"SAMPLE_NODE", SceneManagerConstants.SceneLoadingMode.ADDITIVE, true, 0.0, 0.0, true
	)
	SceneManager.load_scene(scene.scene_value, options)


func _on_button_single_node_up():
	if scene == null:
		return

	var options := SceneLoadOptions.new(
		"SAMPLE_NODE", SceneManagerConstants.SceneLoadingMode.SINGLE_NODE, true, 0.0, 0.0, true
	)
	SceneManager.load_scene(scene.scene_value, options)


func _on_reset_button_up():
	SceneManager.clear_back_buffer()


func _on_loading_scene_button_up():
	if scene == null:
		return

	SceneManager.load_scene_with_transition(scene.scene_value, Scenes.SceneName.LOADING)


func _on_loading_scene_initialization_button_up():
	if scene == null:
		return

	SceneManager.load_scene_with_transition(
		scene.scene_value, Scenes.SceneName.LOADING_WITH_INITIALIZATION
	)


func _on_back_pressed() -> void:
	SceneManager.load_previous_scene()


func _on_reload_pressed() -> void:
	SceneManager.reload_current_scene()


func _on_exit_pressed() -> void:
	SceneManager.exit_game()
