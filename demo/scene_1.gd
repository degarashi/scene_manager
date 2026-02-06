extends Control


func _on_load_scene_2_button_button_up() -> void:
	SceneManager.switch_to_scene(Scenes.Id.SCENE_2)


func _on_reload_button_button_up() -> void:
	SceneManager.reload_current_scene()


func _on_quit_button_button_up() -> void:
	SceneManager.exit_game()
