@tool
extends EditorPlugin

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Card Story"

func _get_plugin_icon() -> Texture2D:
	return load("res://addons/card-story/icons/card_icon_16.svg")

func _enter_tree():
	pass

func _exit_tree():
	pass
