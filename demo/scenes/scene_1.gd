extends "./scene_base.gd"

# implements IFadeInNotify, IFadeOutNotify, ISceneInitializer


# --- INTERFACE LIST (AUTO-GENERATED) ---
static func implements_list() -> Array[Script]:
	return [IFadeInNotify, IFadeOutNotify, ISceneInitializer]


# --- INTERFACE METHODS (STUBS) ---
func on_fade_in_end() -> void:
	DLogger.info("Scene 1: on_fade_in_end")


func on_fade_out_end() -> void:
	DLogger.info("Scene 1: on_fade_out_end")


func on_scene_init(params: Variant) -> void:
	DLogger.info("Scene 1: on_scene_init with params: {0}", [params])


func _on_load_scene_2_button_button_up() -> void:
	SceneManager.switch_to_scene(Scenes.Id.SCENE_2, true, opt)


func _on_reload_button_button_up() -> void:
	SceneManager.reload_current_scene(opt)


func _on_quit_button_button_up() -> void:
	SceneManager.exit_game(opt.play_out_time)

# --- INTERFACE IMPLEMENTER (AUTO-GENERATED) ---
# --- END INTERFACE IMPLEMENTER ---
