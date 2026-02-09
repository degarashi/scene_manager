extends "./scene_base.gd"


func _on_scene_1_button_button_up() -> void:
	# Reflect the inspector's values directly
	SceneManager.switch_to_scene(Scenes.Id.SCENE_1, false, opt)


func _on_begin_loading_button_pressed() -> void:
	SceneManager.load_scene_with_transition(Scenes.Id.SCENE_1, Scenes.Id.LOADING_SCREEN, opt)


func _on_quit_button_pressed() -> void:
	SceneManager.exit_game(opt.fade_out_time)


func _on_begin_fake_loading_button_pressed() -> void:
	SceneManager.load_scene_with_transition(Scenes.Id.SCENE_1, Scenes.Id.FAKE_LOADING_SCREEN, opt)


func _on_load_additional_button_button_up() -> void:
	var opts := SceneLoadOptions.new()
	opts.node_name = "HUD"
	SceneManager.add_scene(Scenes.Id.ADDITIONAL_0, opts)
