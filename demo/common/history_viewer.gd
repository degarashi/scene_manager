extends PanelContainer

@onready var _previous_scene_button: Button = %PreviousSceneButton
@onready var _history_list: VBoxContainer = %HistoryList


func _ready() -> void:
	_update_view()


func _update_view() -> void:
	_clear_view()

	var history := SceneManager.get_history_list()

	# Handle the case where history is empty
	if history.is_empty():
		# Disable as there's no history to go back to
		_previous_scene_button.disabled = true
		_display_empty_message()
		return

	# Enable button if history exists
	_previous_scene_button.disabled = false

	# Traverse array from the end in reverse order (newest at the top)
	# history[last] is the most recent (offset 1)
	for i in range(history.size() - 1, -1, -1):
		# Calculate offset: if i is history.size() - 1, offset is 1
		var offset := history.size() - i
		_create_history_button(history[i], offset)


func _clear_view() -> void:
	for child in _history_list.get_children():
		child.queue_free()


func _create_history_button(scene_id: Scenes.Id, offset: int) -> void:
	var btn := Button.new()

	# Get the Enum key name
	var scene_name := str(Scenes.Id.find_key(scene_id))
	btn.text = scene_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Bind the offset instead of scene_id to perform the pop operation
	btn.pressed.connect(_on_history_button_pressed.bind(offset))

	_history_list.add_child(btn)


func _on_history_button_pressed(offset: int) -> void:
	# Use back_to_previous_by_offset to pop history up to the target scene
	var options := SceneLoadOptions.new()
	SceneManager.back_to_previous_by_offset(offset, options)


func _display_empty_message() -> void:
	var label := Label.new()
	label.text = "No History Available"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate.a = 0.5

	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_list.add_child(label)


func _on_previous_scene_button_button_up() -> void:
	SceneManager.load_previous_scene()
