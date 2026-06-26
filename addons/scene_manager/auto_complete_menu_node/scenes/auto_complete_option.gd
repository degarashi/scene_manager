@tool
class_name AutoCompleteOption
extends ColorRect

signal option_chosen(option_text: String)

@onready var complete_text: RichTextLabel = %CompleteText
@onready var complete_button: Button = %CompleteButton

var fuzzy_score: float = 0.0
var raw_text: String = ""
var raw_text_lower: String = ""


func set_text(p_text: String, highlight_indices: Array[int] = []) -> void:
	raw_text = p_text
	raw_text_lower = p_text.to_lower()
	if highlight_indices.is_empty():
		complete_text.text = p_text
		return

	var bbcode := ""
	var last_idx := 0
	for idx in highlight_indices:
		bbcode += p_text.substr(last_idx, idx - last_idx)
		# Use a distinct color for highlights, or just bold
		bbcode += "[b][color=cyan]" + p_text[idx] + "[/color][/b]"
		last_idx = idx + 1
	bbcode += p_text.substr(last_idx)
	complete_text.text = bbcode


func _on_complete_button_pressed() -> void:
	option_chosen.emit(raw_text)
