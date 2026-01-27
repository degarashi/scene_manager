@tool
class_name SceneManagerUtils
extends Node
## Helper class for the scene manager


## Returns the string form of the Scenes.Id enum.
##
## Note that this only works for unique enum values. If there are duplicate values
## assigned to the enums, then this won't work. However, since we control how the
## Id is created, this won't be an issue.
static func get_enum_string_from_enum(scene: Scenes.Id) -> String:
	var index := Scenes.Id.values().find(scene)
	return Scenes.Id.keys()[index]


## Returns the Scenes.Id enum from the provided string.
##
## Returns Scenes.Id.NONE if the string doesn't match anything.
static func get_enum_from_scene_name(scene_name: String) -> Scenes.Id:
	var sanitized := sanitize_as_enum_string(scene_name)
	if sanitized in Scenes.Id.keys():
		return Scenes.Id.get(sanitized) as Scenes.Id

	return Scenes.Id.NONE


## Returns a string that is all caps with spaces replaced with underscores.
static func sanitize_as_enum_string(text: String) -> String:
	text = text.replace(" ", "_")
	return text.to_upper()


## Returns a string that has no symbols, is lower cases, and spaces are underscores.
static func sanitize_scene_name(scene_name: String) -> String:
	if scene_name.is_empty():
		return scene_name

	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_ -]")
	var result := regex.search(scene_name)
	if result:
		scene_name = scene_name.replace(result.get_string(), "")

	scene_name = scene_name.replace(" ", "_")
	return scene_name
