@tool
# CardStory编辑器插件入口
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/cardstory_tools/dock/cardstory_dock.tscn")
const MAIN_EDITOR_SCENE = preload("res://addons/cardstory_tools/editor/main_editor.tscn")

var dock_instance
var editor_window
var toolbar_button

func _enter_tree():
	# 添加Dock面板
	dock_instance = DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock_instance)
	
	# 添加工具栏按钮
	toolbar_button = Button.new()
	toolbar_button.text = "CardStory"
	toolbar_button.icon = preload("res://addons/cardstory_tools/icons/cardstory_icon.svg")
	toolbar_button.pressed.connect(open_main_editor)
	
	# 将按钮添加到主工具栏
	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)
	
	# 添加菜单项
	add_tool_menu_item("CardStory编辑器", open_main_editor)
	
	# 注册自定义资源类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/resource/fragment.gd"):
		add_custom_type("Fragment", "Resource", 
			preload("res://addons/cardstory_tools/core/resource/fragment.gd"),
			preload("res://addons/cardstory_tools/icons/fragment.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/resource/card.gd"):
		add_custom_type("Card", "Fragment", 
			preload("res://addons/cardstory_tools/core/resource/card.gd"),
			preload("res://addons/cardstory_tools/icons/card.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/resource/core/aspect.gd"):
		add_custom_type("Aspect", "Fragment", 
			preload("res://addons/cardstory_tools/core/resource/aspect.gd"),
			preload("res://addons/cardstory_tools/icons/aspect.svg"))

	if ResourceLoader.exists("res://addons/cardstory_tools/resource/core/act.gd"):
		add_custom_type("Act", "Resource", 
			preload("res://addons/cardstory_tools/core/resource/act.gd"),
			preload("res://addons/cardstory_tools/icons/act.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/resource/core/rule.gd"):
		add_custom_type("Rule", "Resource", 
			preload("res://addons/cardstory_tools/core/resource/rule.gd"),
			preload("res://addons/cardstory_tools/icons/rule.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/resource/core/test.gd"):
		add_custom_type("Test", "Resource", 
			preload("res://addons/cardstory_tools/core/resource/test.gd"),
			preload("res://addons/cardstory_tools/icons/test.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/resource/core/slot.gd"):
		add_custom_type("Slot", "Resource", 
			preload("res://addons/cardstory_tools/core/resource/slot.gd"),
			preload("res://addons/cardstory_tools/icons/slot.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/resource/token.gd"):
		add_custom_type("Token", "Fragment", 
			preload("res://addons/cardstory_tools/core/resource/token.gd"),
			preload("res://addons/cardstory_tools/icons/token.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/resource/core/deck.gd"):
		add_custom_type("Deck", "Resource", 
			preload("res://addons/cardstory_tools/core/resource/deck.gd"),
			preload("res://addons/cardstory_tools/icons/deck.svg"))
	
	# 注册Viz相关类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/viz/drag.gd"):
		add_custom_type("Drag", "Control", 
			preload("res://addons/cardstory_tools/core/viz/drag.gd"),
			preload("res://addons/cardstory_tools/icons/cardstory_icon.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/viz/viz.gd"):
		add_custom_type("Viz", "Drag", 
			preload("res://addons/cardstory_tools/core/viz/viz.gd"),
			preload("res://addons/cardstory_tools/icons/cardstory_icon.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/viz/card_viz.gd"):
		add_custom_type("CardViz", "Viz", 
			preload("res://addons/cardstory_tools/core/viz/card_viz.gd"),
			preload("res://addons/cardstory_tools/icons/card.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/viz/token_viz.gd"):
		add_custom_type("TokenViz", "Control",
			preload("res://addons/cardstory_tools/core/viz/token_viz.gd"),
			preload("res://addons/cardstory_tools/icons/token.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/viz/fragment_viz.gd"):
		add_custom_type("FragmentViz", "Control", 
			preload("res://addons/cardstory_tools/core/viz/fragment_viz.gd"),
			preload("res://addons/cardstory_tools/icons/fragment.svg"))
	
	# 注册管理器类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/game_manager.gd"):
		add_custom_type("GameManager", "Node", 
			preload("res://addons/cardstory_tools/core/game_manager.gd"),
			preload("res://addons/cardstory_tools/icons/cardstory_icon.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/save_manager.gd"):
		add_custom_type("SaveManager", "Node", 
			preload("res://addons/cardstory_tools/core/save_manager.gd"),
			preload("res://addons/cardstory_tools/icons/cardstory_icon.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/ui_manager.gd"):
		add_custom_type("UIManager", "Node", 
			preload("res://addons/cardstory_tools/core/ui_manager.gd"),
			preload("res://addons/cardstory_tools/icons/cardstory_icon.svg"))
	
	# 注册牌库相关类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/deck/deck_manager.gd"):
		add_custom_type("DeckManager", "Node", 
			preload("res://addons/cardstory_tools/core/deck/deck_manager.gd"),
			preload("res://addons/cardstory_tools/icons/deck.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/deck/deck_inst.gd"):
		add_custom_type("DeckInst", "RefCounted", 
			preload("res://addons/cardstory_tools/core/deck/deck_inst.gd"),
			preload("res://addons/cardstory_tools/icons/deck.svg"))
	
	# 注册卡牌组件类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/card/card_stack.gd"):
		add_custom_type("CardStack", "Control", 
			preload("res://addons/cardstory_tools/core/card/card_stack.gd"),
			preload("res://addons/cardstory_tools/icons/card.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/card/card_lane.gd"):
		add_custom_type("CardLane", "Control", 
			preload("res://addons/cardstory_tools/core/card/card_lane.gd"),
			preload("res://addons/cardstory_tools/icons/card.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/card/card_decay.gd"):
		add_custom_type("CardDecay", "Node2D", 
			preload("res://addons/cardstory_tools/core/card/card_decay.gd"),
			preload("res://addons/cardstory_tools/icons/card.svg"))
	
	# 注册逻辑类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/logic/act_window.gd"):
		add_custom_type("ActWindow", "Control", 
			preload("res://addons/cardstory_tools/core/logic/act_window.gd"),
			preload("res://addons/cardstory_tools/icons/act.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/slot/slot_viz.gd"):
		add_custom_type("SlotViz", "Control", 
			preload("res://addons/cardstory_tools/core/slot/slot_viz.gd"),
			preload("res://addons/cardstory_tools/icons/slot.svg"))
	
	# 注册桌面类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/table/table.gd"):
		add_custom_type("Table", "Control", 
			preload("res://addons/cardstory_tools/core/table/table.gd"),
			preload("res://addons/cardstory_tools/icons/cardstory_icon.svg"))
	
	# 注册UI类型
	if ResourceLoader.exists("res://addons/cardstory_tools/core/ui/card_info.gd"):
		add_custom_type("CardInfo", "Control", 
			preload("res://addons/cardstory_tools/core/ui/card_info.gd"),
			preload("res://addons/cardstory_tools/icons/card.svg"))
	
	if ResourceLoader.exists("res://addons/cardstory_tools/core/ui/aspect_info.gd"):
		add_custom_type("AspectInfo", "Control", 
			preload("res://addons/cardstory_tools/core/ui/aspect_info.gd"),
			preload("res://addons/cardstory_tools/icons/aspect.svg"))
	
	print("CardStory编辑工具已加载")

func _exit_tree():
	# 移除UI组件
	if dock_instance:
		remove_control_from_docks(dock_instance)
	if toolbar_button:
		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)
	
	remove_tool_menu_item("CardStory编辑器")
	
	# 移除自定义类型
	remove_custom_type("Fragment")
	remove_custom_type("Card")
	remove_custom_type("Aspect") 
	remove_custom_type("Act")
	remove_custom_type("Rule")
	remove_custom_type("Test")
	remove_custom_type("Slot")
	remove_custom_type("Token")
	remove_custom_type("Deck")
	
	# 移除Viz相关类型
	remove_custom_type("Drag")
	remove_custom_type("Viz")
	remove_custom_type("CardViz")
	remove_custom_type("FragmentViz")
	
	# 移除管理器类型
	remove_custom_type("GameManager")
	remove_custom_type("SaveManager")
	remove_custom_type("UIManager")
	
	# 移除牌库相关类型
	remove_custom_type("DeckManager")
	remove_custom_type("DeckInst")
	
	# 移除卡牌组件类型
	remove_custom_type("CardStack")
	remove_custom_type("CardLane")
	remove_custom_type("CardDecay")
	
	# 移除逻辑类型
	remove_custom_type("ActWindow")
	remove_custom_type("SlotViz")
	
	# 移除桌面类型
	remove_custom_type("Table")
	
	# 移除UI类型
	remove_custom_type("CardInfo")
	remove_custom_type("AspectInfo")
	
	if editor_window:
		editor_window.queue_free()
	
	print("CardStory编辑工具已卸载")

func open_main_editor():
	if not editor_window:
		editor_window = MAIN_EDITOR_SCENE.instantiate()
		EditorInterface.get_editor_main_screen().add_child(editor_window)
	
	editor_window.show()
	editor_window.grab_focus()
	print("打开CardStory主编辑器")

func _handles(object):
	# 处理CardStory相关资源
	if object is Resource:
		return object.get_script() and (
			object.get_script().get_path().begins_with("res://addons/cardstory_tools/core/")
		)
	return false

func _edit(object):
	# 编辑CardStory资源时自动打开专用编辑器
	if _handles(object):
		open_main_editor()
		if editor_window and editor_window.has_method("load_resource_for_editing"):
			editor_window.load_resource_for_editing(object.resource_path)
