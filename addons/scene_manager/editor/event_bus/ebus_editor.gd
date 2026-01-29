@tool
class_name SMgrEbusEditor
extends Resource

signal get_section_names(recv: Array[String])
signal get_sections(recv: Array, scene_address: String)
signal scene_renamed(old_name: String, new_name: String)
signal remove_scene_from_list(section_name: String, scene_name: String, scene_address: String)
signal item_added_to_list(node: Node, list_name: String)
signal item_removed_from_list(node: Node, list_name: String)
signal add_scene_to_list(
	list_name: String, scene_name: String, scene_address: String, categorized: bool
)
