@tool
extends EditorProperty

const DUPLICATE_LINE_EDIT: StyleBox = preload("uid://21mjw515mptn")
const OPEN_ICON: Texture2D = preload("uid://bpg21v8550rmv")

# The main control for editing the property.
var property_control: SceneLineEdit = (
	preload("uid://bll0mw3ddccs1").instantiate()
)
# The main container.
var container: HBoxContainer = HBoxContainer.new()
# Open button.
var open_button: Button = Button.new()
# An internal value of the property.
var current_value: SceneResource = SceneResource.new()
# A guard against internal changes when the property is updated.
var updating: bool = false


func _init() -> void:
	# Add the container as a direct child of EditorProperty node.
	add_child(container)

	# Add the control to the container.
	container.add_child(property_control)
	property_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Add the open button to the container.
	container.add_child(open_button)
	open_button.icon = OPEN_ICON
	open_button.flat = true
	open_button.tooltip_text = "Open Scene"
	open_button.button_up.connect(_on_open_button_up)

	# Make sure the control is able to retain the focus.
	add_focusable(property_control)
	# Setup the initial state and connect to the signal to track changes.
	_refresh_control_text()
	property_control.generate_autocomplete()
	property_control.text_changed.connect(_on_text_changed)


func _on_open_button_up() -> void:
	if current_value == null or current_value.scene_value == Scenes.Id.NONE:
		return

	var path := Scenes.get_scene_path(current_value.scene_value)
	if path.is_empty():
		return

	EditorInterface.open_scene_from_path(path)
	EditorInterface.select_file(path)


func _on_text_changed(new_text: String) -> void:
	# Ignore the signal if the property is currently being updated.
	if updating:
		return

	if current_value == null:
		current_value = SceneResource.new()

	current_value.set_text(new_text)

	_update_theme()
	emit_changed(get_edited_property(), current_value)


func _update_property() -> void:
	# Read the current value from the property.
	var new_value: SceneResource = get_edited_object()[get_edited_property()]
	if new_value == current_value:
		return

	# Update the control with the new value.
	updating = true

	if current_value == null:
		current_value = SceneResource.new()

	current_value = new_value

	_update_theme()
	_refresh_control_text()

	updating = false


func _refresh_control_text() -> void:
	if current_value == null:
		property_control.text = ""
	else:
		property_control.text = current_value.string_value


func _update_theme() -> void:
	var is_invalid := current_value == null or current_value.scene_value == Scenes.Id.NONE
	if is_invalid:
		property_control.add_theme_stylebox_override("normal", DUPLICATE_LINE_EDIT)
	else:
		property_control.remove_theme_stylebox_override("normal")

	if open_button:
		open_button.disabled = is_invalid
