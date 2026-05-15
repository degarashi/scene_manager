class_name SMgrTransitionService
extends Node
## Service to handle scene transitions and custom transitioners.

const _PS := preload("uid://dn6eh4s0h8jhi")

var _scene_db: SMgrData
var _log: DLoggerClass
var _transitioner_source: PackedScene
var _transition_player: ScreenTransitioner


func _init(p_scene_db: SMgrData, p_log: DLoggerClass, p_source: PackedScene) -> void:
	_scene_db = p_scene_db
	_log = p_log
	_transitioner_source = p_source


func _ready() -> void:
	_init_effector()


func _init_effector() -> void:
	_transition_player = _transitioner_source.instantiate()
	add_child(_transition_player)
	_transition_player.set_layer(_PS.transition_layer)


func get_main_player() -> ScreenTransitioner:
	return _transition_player


func setup_transition_player(options: SceneLoadOptions) -> ScreenTransitioner:
	var custom_player := _get_custom_transitioner(options)
	var player := custom_player if custom_player else _transition_player
	player.set_clickable(options.clickable)

	var layer := options.transition_layer
	if layer == -1:
		layer = _PS.transition_layer
	player.set_layer(layer)

	return player


func _get_custom_transitioner(options: SceneLoadOptions) -> ScreenTransitioner:
	if options.transition_id == Scenes.Id.NONE:
		return null

	var path := _scene_db.get_scene_path_from_enum(options.transition_id)
	if path.is_empty():
		_log.error("Custom transition scene not found for ID: {0}", [options.transition_id])
		return null

	var scene := load(path) as PackedScene
	if not scene:
		_log.error("Failed to load custom transition scene at: {0}", [path])
		return null

	var instance := scene.instantiate()
	if not instance is ScreenTransitioner:
		_log.error("Custom transition scene does not inherit from ScreenTransitioner.")
		instance.free()
		return null

	add_child(instance)
	return instance as ScreenTransitioner
