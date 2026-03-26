@tool
extends Button

# ------------- [Signal] -------------
signal option_chosen(option_text: String)


# ------------- [Callbacks] -------------
func _pressed() -> void:
	option_chosen.emit(get_parent().get_node("CompleteText").text)
