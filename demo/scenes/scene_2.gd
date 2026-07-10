extends "./scene_base.gd"

# implements IFadeInNotify, IFadeOutNotify


# --- INTERFACE LIST (AUTO-GENERATED) ---
static func implements_list() -> Array[Script]:
	return [IFadeInNotify, IFadeOutNotify]


# --- INTERFACE METHODS (STUBS) ---
func on_fade_in_end() -> void:
	DLogger.info("Scene 2: on_fade_in_end")


func on_fade_out_start() -> void:
	DLogger.info("Scene 2: on_fade_out_start")


func on_fade_out_end() -> void:
	DLogger.info("Scene 2: on_fade_out_end")


func _on_load_scene_0_button_pressed() -> void:
	SceneManager.switch_to_scene(Scenes.Id.SCENE_0, true, opt)

# --- INTERFACE IMPLEMENTER (AUTO-GENERATED) ---
# --- END INTERFACE IMPLEMENTER ---
