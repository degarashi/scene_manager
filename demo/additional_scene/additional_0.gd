extends Control


func _on_remove_button_button_up() -> void:
	SceneManager.unload_scene_by_name("HUD")
