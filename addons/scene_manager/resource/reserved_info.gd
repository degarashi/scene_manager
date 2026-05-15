class_name SMgrReservedInfo
extends RefCounted
## Internal class to hold reservation info for asynchronous loading.

var scene_id: Scenes.Id = Scenes.Id.NONE
var options: SceneLoadOptions
var is_additive: bool = false
var add_to_back: bool = false


func clear() -> void:
	scene_id = Scenes.Id.NONE
	options = null
	is_additive = false
	add_to_back = false
