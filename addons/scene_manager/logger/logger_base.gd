@tool
class_name SMgrLogBase
extends Object

const PREFIX = "[SceneManager]"


func debug(_msg: Variant) -> void:
	pass


func info(_msg: Variant) -> void:
	pass


func warn(_msg: Variant) -> void:
	pass


func error(_msg: Variant) -> void:
	pass


## Factory method that returns the appropriate instance based on the setting.
static func create(enable_log: bool) -> SMgrLogBase:
	if enable_log:
		return SMgrLog.new()
	return SMgrLogQuiet.new()
