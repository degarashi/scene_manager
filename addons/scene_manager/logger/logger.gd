@tool
class_name SMgrLog
extends SMgrLogBase


func debug(msg: Variant) -> void:
	print_rich("[color=gray]%s [DEBUG][/color] %s" % [PREFIX, str(msg)])


func info(msg: Variant) -> void:
	print_rich("[b][color=cyan]%s [INFO][/color][/b] %s" % [PREFIX, str(msg)])


func warn(msg: Variant) -> void:
	var output := "%s [WARN] %s" % [PREFIX, str(msg)]
	print_rich("[b][color=yellow]%s[/color][/b]" % output)
	push_warning(output)


func error(msg: Variant) -> void:
	var output := "%s [ERROR] %s" % [PREFIX, str(msg)]
	print_rich("[b][color=red]%s[/color][/b]" % output)
	push_error(output)
