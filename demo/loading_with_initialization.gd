extends Control

# Nodes
@onready var progress: ProgressBar = find_child("Progress")
@onready var loading: AnimatedSprite2D = find_child("Loading")
@onready var next: Button = find_child("Next")
@onready var label: Label = find_child("Label")

var gap = 30


func _ready():
	SceneManager.load_percent_changed.connect(percent_changed)
	SceneManager.load_finished.connect(loading_finished)
	SceneManager.load_scene_interactive(SceneManager.get_recorded_scene())


func percent_changed(number: int) -> void:
	# the last `gap%` is for the loaded scene itself to load its own data or initialize or world generate or ...
	progress.value = max(number - gap, 0)
	if progress.value >= 90:
		label.text = "World Generation . . ."


func loading_finished() -> void:
	# All loading processes are finished now
	if progress.value == 100:
		loading.visible = false
		next.visible = true
		label.text = ""
	# Loading finishes and world initialization or world generation or whatever you wanna call it will start
	elif progress.value == 70:
		SceneManager.add_loaded_scene_to_scene_tree()
		gap = 0
		label.text = "Scene Initialization . . ."


func _on_next_button_up():
	SceneManager.change_scene_to_loaded_scene()
