@tool
extends Label

@export var _ebus_editor: SMgrEbusEditor


func _ready() -> void:
	_ebus_editor.on_category_selected.connect(_on_category_selected)


func _on_category_selected(id: int) -> void:
	var recv: Array[SMgrCategoryData]
	_ebus_editor.get_category_by_id.emit(recv, id)
	if recv.is_empty():
		return
	var cat := recv[0]
	if cat:
		self.text = cat.name
	else:
		self.text = "----"
