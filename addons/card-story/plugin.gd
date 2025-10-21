@tool
extends EditorPlugin

# 主编辑器场景
var main_editor_panel: Control

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Card Story"

func _get_plugin_icon() -> Texture2D:
	return load("res://addons/card-story/icons/card_icon.svg")

func _enter_tree():
	main_editor_panel = preload("res://addons/card-story/card_story_editor.tscn").instantiate()
	EditorInterface.get_editor_main_screen().add_child(main_editor_panel)
	main_editor_panel.hide()


func _exit_tree():
	main_editor_panel.queue_free()

func _make_visible(visible: bool) -> void:
	main_editor_panel.visible = visible
