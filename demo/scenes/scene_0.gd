extends "./scene_base.gd"

# implements IFadeInNotify, IFadeOutNotify


# --- INTERFACE LIST (AUTO-GENERATED) ---
static func implements_list() -> Array[Script]:
	return [IFadeInNotify, IFadeOutNotify]


# --- INTERFACE METHODS (STUBS) ---
func on_fade_in_end() -> void:
	DLogger.info("Scene 0: on_fade_in_end")


func on_fade_out_end() -> void:
	DLogger.info("Scene 0: on_fade_out_end")


func _on_scene_1_button_button_up() -> void:
	# Reflect the inspector's values directly
	opt.params = {"test_data": "Hello from Scene 0", "timestamp": Time.get_unix_time_from_system()}
	SceneManager.switch_to_scene(Scenes.Id.SCENE_1, true, opt)


func _on_begin_loading_button_pressed() -> void:
	SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.LOADING_SCREEN,
		true,
		SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
		opt
	)


func _on_quit_button_pressed() -> void:
	SceneManager.exit_game(opt.play_out_time)


func _on_begin_fake_loading_button_pressed() -> void:
	SceneManager.load_scene_with_transition(
		Scenes.Id.SCENE_1,
		Scenes.Id.FAKE_LOADING_SCREEN,
		true,
		SMgrInstance.DuplicateNameMode.WARN_AND_SKIP,
		opt
	)


func _on_load_additional_button_button_up() -> void:
	var opts := SceneLoadOptions.new()
	opts.node_name = "HUD"
	SceneManager.add_scene(
		Scenes.Id.ADDITIONAL_0, SMgrInstance.DuplicateNameMode.WARN_AND_SKIP, opts
	)

# --- INTERFACE IMPLEMENTER (AUTO-GENERATED) ---
# --- END INTERFACE IMPLEMENTER ---
