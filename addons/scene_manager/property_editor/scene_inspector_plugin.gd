@tool
extends EditorInspectorPlugin

const SceneEditorProperty = preload("uid://bxv22ti18tesc")


func _can_handle(_object: Object) -> bool:
	# We support all objects.
	return true


func _parse_property(
	_object: Object,
	type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if type == TYPE_OBJECT and hint_string == "SceneResource":
		add_property_editor(name, SceneEditorProperty.new())
		return true

	return false
