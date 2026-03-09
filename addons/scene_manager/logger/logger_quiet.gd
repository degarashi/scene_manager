@tool
class_name SMgrLogQuiet
extends SMgrLogBase


func debug(_msg: Variant) -> void:
	pass


func info(_msg: Variant) -> void:
	pass


func warn(msg: Variant) -> void:
	# Minimal notification to the editor system
	push_warning("%s [WARN] %s" % [PREFIX, str(msg)])


func error(msg: Variant) -> void:
	# Minimal notification to the editor system
	push_error("%s [ERROR] %s" % [PREFIX, str(msg)])
