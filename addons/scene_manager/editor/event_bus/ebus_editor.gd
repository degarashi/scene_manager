@tool
class_name SMgrEbusEditor
extends SMgrResource

signal change_scene_name(uid: int, scene_name: String)
signal add_scene_to_section(uid: int, section_name: String)
signal remove_scene_from_section(uid: int, section_name: String)

# --- Notify ---
signal on_dirty_flag_changed(dirty: bool)

# --- Getter ---
signal has_scene_by_name(recv: Array[bool], scene_name: String)
signal get_dirty_flag(recv: Array[bool])

# You can freely obtain and refer to the scene, but change the data through the interface
signal get_scene_info(recv: Array[SMgrDataScene], uid: int)
signal get_scenes(recv: Array[SMgrDataScene], section_name: String)
signal get_scenes_all(recv: Array[SMgrDataScene])
signal get_scenes_uncategorized(recv: Array[SMgrDataScene])
signal get_scenes_categorized(recv: Array[SMgrDataScene])

signal get_section_names(recv: Array[String])


func disconnect_all_signals() -> void:
	var signal_list := get_signal_list()
	for sig in signal_list:
		var connections := get_signal_connection_list(sig.name)
		for conn in connections:
			disconnect(sig.name, conn.callable)
