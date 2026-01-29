extends RefCounted
var _source: SMgrMainPanel


func _init(source: SMgrMainPanel) -> void:
	_source = source


func get_section_names() -> Array[String]:
	return _source.get_section_names()


func get_sections(address: String) -> Array:
	return _source.get_sections(address)
