@tool
class_name SMgrEbusEditor
extends Resource

signal get_section_names(recv: Array[String])
signal get_sections(recv: Array, scene_address: String)
signal scene_renamed(old_name: String, new_name: String)

signal remove_scene_from_section(section_name: String, scene_name: String, scene_address: String)
signal item_added_to_section(item: SMgrSceneItem, section_name: String)
signal item_removed_from_section(item: SMgrSceneItem, section_name: String)
signal add_scene_to_section(
	section_name: String, scene_name: String, scene_address: String, categorized: bool
)
