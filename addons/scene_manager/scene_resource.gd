@tool
class_name SceneResource
extends Resource
## Custom resource for the editor property to allow it to have a custom inspector.

@export var string_value: String

## Accessor to get the enum from the string value in this resource.
var scene_value: Scenes.SceneName:
	get:
		return SceneManagerUtils.get_enum_from_scene_name(string_value)


## Sets the text for the resource, which will automatically find the corresponding
## [Scenes.SceneName] enum.
func set_text(text: String) -> void:
	if string_value != text:
		string_value = text
		emit_changed()


## ToString override to print a more helpful string information for the resource.
func _to_string() -> String:
	return "String: {0}, Scene: {1}".format([string_value, scene_value])
