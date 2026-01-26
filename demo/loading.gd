extends Control

# Nodes
@onready var progress: ProgressBar = find_child("Progress")
@onready var loading: AnimatedSprite2D = find_child("Loading")
@onready var next: Button = find_child("Next")


func _ready():
	SceneManager.load_percent_changed.connect(percent_changed)
	SceneManager.load_finished.connect(loading_finished)
	SceneManager.load_scene_interactive(SceneManager.get_reserved_scene())


func percent_changed(number: int) -> void:
	progress.value = number


func loading_finished() -> void:
	loading.visible = false
	next.visible = true
	SceneManager.add_loaded_scene_to_scene_tree()


func _on_next_button_up():
	SceneManager.change_scene_to_loaded_scene()
