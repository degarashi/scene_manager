extends Control

## Configuration resource for batch management in the inspector
@export var opt: SceneLoadOptions


func _on_scene_1_button_button_up() -> void:
	# Reflect the inspector's values directly
	SceneManager.switch_to_scene(Scenes.Id.SCENE_1, opt)


func _on_begin_loading_button_pressed() -> void:
	var loading_opt := opt.copy()
	SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1, Scenes.Id.LOADING_SCREEN, loading_opt
	)


func _on_quit_button_pressed() -> void:
	SceneManager.exit_game()


func _on_begin_fake_loading_button_pressed() -> void:
	var loading_opt := opt.copy()
	SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1, Scenes.Id.FAKE_LOADING_SCREEN, loading_opt
	)
