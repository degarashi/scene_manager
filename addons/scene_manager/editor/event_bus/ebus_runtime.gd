class_name SMgrEbusRuntime
extends SMgrEventBusBase

signal pause_threshold_changed(priority: int)
signal get_scene_by_name(recv: Array[SMgrSceneLayer], scene_name: String)
