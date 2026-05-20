@tool
class_name SMgrEbusEditor
extends SMgrEventBusBase

# --- Manipulate ---
signal change_scene_name(scene_id: int, scene_name: String)
signal add_scene_to_category(scene_id: int, category_id: int)
signal remove_scene_from_category(scene_id: int, category_id: int)
signal rename_category(category_id: int, new_name: String)

# --- Notify ---
signal on_dirty_flag_changed(dirty: bool)
signal on_category_selected(category_id: int)
signal on_scene_selected(scene_id: int)
signal on_data_changed

# --- Getter ---
# for duplication check
signal scene_name_duplication_check(recv: Array[bool], scene_name: String)
signal category_name_duplication_check(recv: Array[bool], category_name: String)
signal get_dirty_flag(recv: Array[bool])

# You can freely obtain and refer to the scene, but change the data through the interface
signal get_scene_info(recv: Array[SMgrDataScene], scene_id: int)
signal get_scenes(recv: Array[SMgrDataScene], category_id: int)
signal get_scenes_all(recv: Array[SMgrDataScene])
signal get_scenes_uncategorized(recv: Array[SMgrDataScene])
signal get_scenes_categorized(recv: Array[SMgrDataScene])

signal get_categories(recv: Array[int])
signal get_category_by_id(recv: Array[SMgrCategoryData], category_id: int)


func disconnect_all_signals() -> void:
	var signal_list := get_signal_list()
	for sig in signal_list:
		var connections := get_signal_connection_list(sig.name)
		for conn in connections:
			disconnect(sig.name, conn.callable)
