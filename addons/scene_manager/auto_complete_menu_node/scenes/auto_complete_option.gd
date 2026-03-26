@tool
class_name AutoCompleteOption
extends ColorRect

signal option_chosen(option_text: String)

@onready var complete_text: Label = %CompleteText
@onready var complete_button: Button = %CompleteButton


func _on_complete_button_pressed() -> void:
	option_chosen.emit(complete_text.text)
