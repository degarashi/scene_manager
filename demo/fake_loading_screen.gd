extends "./loading_screen.gd"

# ------------- [Constants] -------------
## List of dummy messages to display during loading
const LOADING_MESSAGES: Array[String] = [
	"Initializing System",
	"Loading Assets",
	"Constructing Map Data",
	"Generating Textures",
	"Compiling Scripts",
	"Buffering Audio",
	"Applying Render Settings",
	"Placing UI Components"
]

# ------------- [Exports] -------------
## Parameters for testing adjustment
@export var loading_speed: float = 1.0  # 1.0 = Standard, smaller is slower
@export var wait_after_full: float = 1.0  # Wait time after reaching 100% before transition
@export var random_stutter: bool = true  # Whether to occasionally pause progress

# ------------- [Private Variable] -------------
var _current_progress: float = 0.0

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var loading_info: Label = %LoadingInfo
@onready var move_to_next_scene_button: Button = %MoveToNextSceneButton


# ------------- [Callbacks] -------------
func _ready() -> void:
	# Force fit to full screen on run (Prevents CenterContainer offset issues)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Initialization
	progress_bar.value = 0
	loading_info.text = "Preparing..."

	# Hide the "Proceed" button and connect the signal
	move_to_next_scene_button.visible = false
	move_to_next_scene_button.pressed.connect(_on_move_to_next_scene_button_pressed)

	_update_next_scene_label()
	_run_fake_progress()


# ------------- [Private Method] -------------
func _run_fake_progress() -> void:
	while _current_progress < 100.0:
		# Calculate progress increment (Adding randomness for realism)
		var increment: float = randf_range(0.1, 0.8) * loading_speed

		# If random_stutter is ON, occasionally pause progress (Simulating network/IO wait)
		if random_stutter and randf() < 0.05:
			var stutter_time: float = randf_range(0.2, 0.5)
			await get_tree().create_timer(stutter_time).timeout

		_current_progress += increment

		# UI Update
		var display_val: int = clampi(int(_current_progress), 0, 100)
		progress_bar.value = display_val

		# Determine array index based on progress (0.0~1.0)
		# Clamp index to prevent out-of-bounds at 100%
		var msg_count: int = LOADING_MESSAGES.size()
		var msg_index: int = clampi(int((display_val / 100.0) * msg_count), 0, msg_count - 1)

		var message: String = LOADING_MESSAGES[msg_index]
		loading_info.text = "%s... (%d%%)" % [message, display_val]

		# Wait one frame (For smooth animation)
		await get_tree().process_frame

	# Presentation after reaching 100%
	loading_info.text = "Loading Complete! (100%)"
	await get_tree().create_timer(wait_after_full).timeout

	# Show the "Proceed" button and grab focus
	move_to_next_scene_button.visible = true
	move_to_next_scene_button.grab_focus()


## Logic for when the button is pressed
func _on_move_to_next_scene_button_pressed() -> void:
	# Prevent multiple clicks
	move_to_next_scene_button.disabled = true

	# Execute transition to the reserved scene
	var resv_scene := SceneManager.get_reserved_scene()
	if resv_scene != Scenes.Id.NONE:
		SceneManager.switch_to_scene(resv_scene, SceneManager.get_reserved_load_option())
	else:
		push_error("FakeLoadingScreen Error: No scene reserved in SceneManager.")
