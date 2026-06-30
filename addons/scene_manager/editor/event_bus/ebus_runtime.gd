class_name SMgrEbusRuntime
extends SMgrEventBusBase

signal pause_threshold_changed(priority: int)
signal get_scene_by_id(recv: Array[SMgrSceneLayer], scene_id: Scenes.Id)
signal get_scene_by_name(recv: Array[SMgrSceneLayer], scene_name: String)
signal process_scene_layer(proc: Callable)

## Signal used to detect multiple SceneManager instances.
signal instance_check
