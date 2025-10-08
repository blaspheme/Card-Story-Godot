@tool# CardStory编辑器插件入口# CardStory编辑器插件入口

extends EditorPlugin

@tool@tool

# CardStory编辑器插件入口

extends EditorPluginextends EditorPl	if ResourceLoader.exists("res://scripts/core/aspect.gd"):

const DOCK_SCENE = preload("res://addons/cardstory_tools/dock/cardstory_dock.tscn")

const MAIN_EDITOR_SCENE = preload("res://addons/cardstory_tools/editor/main_editor.tscn")		add_custom_type(



var dock_instanceconst DOCK_SCENE = preload("res://addons/cardstory_tools/dock/cardstory_dock.tscn")			"Aspect", 

var editor_window

var toolbar_buttonconst MAIN_EDITOR_SCENE = preload("res://addons/cardstory_tools/editor/main_editor.tscn")			"Resource", 



func _enter_tree():			preload("res://scripts/core/aspect.gd"),

	# 添加Dock面板

	dock_instance = DOCK_SCENE.instantiate()var dock_instance			preload("res://addons/cardstory_tools/icons/aspect.svg")

	add_control_to_dock(DOCK_LEFT_UL, dock_instance)

	var editor_window		)

	# 添加工具栏按钮

	toolbar_button = Button.new()var toolbar_button	

	toolbar_button.text = "CardStory"

	toolbar_button.icon = preload("res://addons/cardstory_tools/icons/cardstory_icon.svg")	if ResourceLoader.exists("res://scripts/core/act.gd"):

	toolbar_button.pressed.connect(open_main_editor)

	func _enter_tree():		add_custom_type(

	# 将按钮添加到主工具栏

	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)	# 添加Dock面板			"Act", 

	

	# 添加菜单项	dock_instance = DOCK_SCENE.instantiate()			"Resource", 

	add_tool_menu_item("CardStory编辑器", open_main_editor)

		add_control_to_dock(DOCK_LEFT_UL, dock_instance)			preload("res://scripts/core/act.gd"),

	# 注册自定义资源类型

	if ResourceLoader.exists("res://scripts/core/fragment.gd"):				preload("res://addons/cardstory_tools/icons/act.svg")

		add_custom_type("Fragment", "Resource", 

			preload("res://scripts/core/fragment.gd"),	# 添加工具栏按钮（在资产库按钮旁边）		)

			preload("res://addons/cardstory_tools/icons/fragment.svg"))

		toolbar_button = Button.new()	

	if ResourceLoader.exists("res://scripts/core/card.gd"):

		add_custom_type("Card", "Fragment", 	toolbar_button.text = "CardStory"	if ResourceLoader.exists("res://scripts/core/rule.gd"):

			preload("res://scripts/core/card.gd"),

			preload("res://addons/cardstory_tools/icons/card.svg"))	toolbar_button.icon = preload("res://addons/cardstory_tools/icons/cardstory_icon.svg")		add_custom_type(

	

	if ResourceLoader.exists("res://scripts/core/aspect.gd"):	toolbar_button.pressed.connect(open_main_editor)			"Rule", 

		add_custom_type("Aspect", "Fragment", 

			preload("res://scripts/core/aspect.gd"),				"Resource", 

			preload("res://addons/cardstory_tools/icons/aspect.svg"))

		# 将按钮添加到主工具栏			preload("res://scripts/core/rule.gd"),

	if ResourceLoader.exists("res://scripts/core/act.gd"):

		add_custom_type("Act", "Resource", 	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)			preload("res://addons/cardstory_tools/icons/rule.svg")

			preload("res://scripts/core/act.gd"),

			preload("res://addons/cardstory_tools/icons/act.svg"))			)ENE = preload("res://addons/cardstory_tools/dock/cardstory_dock.tscn")

	

	if ResourceLoader.exists("res://scripts/core/rule.gd"):	# 添加菜单项const MAIN_EDITOR_SCENE = preload("res://addons/cardstory_tools/editor/main_editor.tscn")

		add_custom_type("Rule", "Resource", 

			preload("res://scripts/core/rule.gd"),	add_tool_menu_item("CardStory编辑器", open_main_editor)

			preload("res://addons/cardstory_tools/icons/rule.svg"))

		var dock_instance

	if ResourceLoader.exists("res://scripts/core/test.gd"):

		add_custom_type("Test", "Resource", 	# 注册自定义资源类型（有条件加载）var editor_window

			preload("res://scripts/core/test.gd"),

			preload("res://addons/cardstory_tools/icons/test.svg"))	if ResourceLoader.exists("res://scripts/core/fragment.gd"):var toolbar_button

	

	if ResourceLoader.exists("res://scripts/core/slot.gd"):		add_custom_type(

		add_custom_type("Slot", "Resource", 

			preload("res://scripts/core/slot.gd"),			"Fragment", func _enter_tree():

			preload("res://addons/cardstory_tools/icons/slot.svg"))

				"Resource", 	# 添加Dock面板

	if ResourceLoader.exists("res://scripts/core/token.gd"):

		add_custom_type("Token", "Fragment", 			preload("res://scripts/core/fragment.gd"),	dock_instance = DOCK_SCENE.instantiate()

			preload("res://scripts/core/token.gd"),

			preload("res://addons/cardstory_tools/icons/token.svg"))			preload("res://addons/cardstory_tools/icons/fragment.svg")	add_control_to_dock(DOCK_LEFT_UL, dock_instance)

	

	if ResourceLoader.exists("res://scripts/core/deck.gd"):		)	

		add_custom_type("Deck", "Resource", 

			preload("res://scripts/core/deck.gd"),		# 添加工具栏按钮（在资产库按钮旁边）

			preload("res://addons/cardstory_tools/icons/deck.svg"))

		if ResourceLoader.exists("res://scripts/core/card.gd"):	toolbar_button = Button.new()

	print("CardStory编辑工具已加载")

		add_custom_type(	toolbar_button.text = "CardStory"

func _exit_tree():

	# 移除UI组件			"Card", 	toolbar_button.icon = preload("res://addons/cardstory_tools/icons/cardstory_icon.svg")

	if dock_instance:

		remove_control_from_docks(dock_instance)			"Fragment", 	toolbar_button.pressed.connect(open_main_editor)

	if toolbar_button:

		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)			preload("res://scripts/core/card.gd"),	

	

	remove_tool_menu_item("CardStory编辑器")			preload("res://addons/cardstory_tools/icons/card.svg")  	# 将按钮添加到主工具栏

	

	# 移除自定义类型		)	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)

	remove_custom_type("Fragment")

	remove_custom_type("Card")		

	remove_custom_type("Aspect") 

	remove_custom_type("Act")	if ResourceLoader.exists("res://scripts/core/aspect.gd"):	# 添加菜单项

	remove_custom_type("Rule")

	remove_custom_type("Test")		add_custom_type(	add_tool_menu_item("CardStory编辑器", open_main_editor)

	remove_custom_type("Slot")

	remove_custom_type("Token")			"Aspect", 	

	remove_custom_type("Deck")

				"Fragment", 	# 注册自定义资源类型

	if editor_window:

		editor_window.queue_free()			preload("res://scripts/core/aspect.gd"),	add_custom_type(

	

	print("CardStory编辑工具已卸载")			preload("res://addons/cardstory_tools/icons/aspect.svg")		"Fragment", 



func open_main_editor():		)		"Resource", 

	if not editor_window:

		editor_window = MAIN_EDITOR_SCENE.instantiate()			preload("res://scripts/core/fragment.gd"),

		EditorInterface.get_editor_main_screen().add_child(editor_window)

		if ResourceLoader.exists("res://scripts/core/act.gd"):		preload("res://addons/cardstory_tools/icons/fragment.svg")

	editor_window.show()

	editor_window.grab_focus()		add_custom_type(	)

	print("打开CardStory主编辑器")

			"Act", 	add_custom_type(

func _handles(object):

	# 处理CardStory相关资源			"Resource", 		"Card", 

	if object is Resource:

		return object.get_script() and (			preload("res://scripts/core/act.gd"),		"Fragment", 

			object.get_script().get_path().begins_with("res://scripts/core/")

		)			preload("res://addons/cardstory_tools/icons/act.svg")		preload("res://scripts/core/card.gd"),

	return false

		)		preload("res://addons/cardstory_tools/icons/card.svg")  

func _edit(object):

	# 编辑CardStory资源时自动打开专用编辑器		)

	if _handles(object):

		open_main_editor()	if ResourceLoader.exists("res://scripts/core/rule.gd"):	add_custom_type(

		if editor_window and editor_window.has_method("load_resource_for_editing"):

			editor_window.load_resource_for_editing(object.resource_path)		add_custom_type(		"Aspect", 

			"Rule", 		"Fragment", 

			"Resource", 		preload("res://scripts/core/aspect.gd"),

			preload("res://scripts/core/rule.gd"),		preload("res://addons/cardstory_tools/icons/aspect.svg")

			preload("res://addons/cardstory_tools/icons/rule.svg")	)

		)	if ResourceLoader.exists("res://scripts/core/act.gd"):

			add_custom_type(

	if ResourceLoader.exists("res://scripts/core/test.gd"):			"Act", 

		add_custom_type(			"Resource", 

			"Test", 			preload("res://scripts/core/act.gd"),

			"Resource", 			preload("res://addons/cardstory_tools/icons/act.svg")

			preload("res://scripts/core/test.gd"),		)

			preload("res://addons/cardstory_tools/icons/test.svg")	add_custom_type(

		)		"Rule", 

			"Resource", 

	if ResourceLoader.exists("res://scripts/core/slot.gd"):		preload("res://scripts/core/rule.gd"),

		add_custom_type(		preload("res://addons/cardstory_tools/icons/rule.svg")

			"Slot", 	)

			"Resource", 	add_custom_type(

			preload("res://scripts/core/slot.gd"),		"Test", 

			preload("res://addons/cardstory_tools/icons/slot.svg")		"Resource", 

		)		preload("res://scripts/core/test.gd"),

			preload("res://addons/cardstory_tools/icons/test.svg")

	if ResourceLoader.exists("res://scripts/core/token.gd"):	)

		add_custom_type(	add_custom_type(

			"Token", 		"Slot", 

			"Fragment", 		"Resource", 

			preload("res://scripts/core/token.gd"),		preload("res://scripts/core/slot.gd"),

			preload("res://addons/cardstory_tools/icons/token.svg")		preload("res://addons/cardstory_tools/icons/slot.svg")

		)	)

		add_custom_type(

	if ResourceLoader.exists("res://scripts/core/deck.gd"):		"Token", 

		add_custom_type(		"Resource", 

			"Deck", 		preload("res://scripts/core/token.gd"),

			"Resource", 		preload("res://addons/cardstory_tools/icons/token.svg")

			preload("res://scripts/core/deck.gd"),	)

			preload("res://addons/cardstory_tools/icons/deck.svg")	add_custom_type(

		)		"Deck", 

			"Resource", 

	print("CardStory编辑工具已加载")		preload("res://scripts/core/deck.gd"),

		preload("res://addons/cardstory_tools/icons/deck.svg")

func _exit_tree():	)

	# 移除UI组件	

	if dock_instance:	print("CardStory编辑工具已加载")

		remove_control_from_docks(dock_instance)

	if toolbar_button:func _exit_tree():

		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)	remove_control_from_docks(dock_instance)

		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)

	remove_tool_menu_item("CardStory编辑器")	remove_tool_menu_item("CardStory编辑器")

		

	# 移除自定义类型	# 移除自定义类型

	remove_custom_type("Fragment")	remove_custom_type("Fragment")

	remove_custom_type("Card")	remove_custom_type("Card")

	remove_custom_type("Aspect") 	remove_custom_type("Aspect") 

	remove_custom_type("Act")	remove_custom_type("Act")

	remove_custom_type("Rule")	remove_custom_type("Rule")

	remove_custom_type("Test")	remove_custom_type("Test")

	remove_custom_type("Slot")	remove_custom_type("Slot")

	remove_custom_type("Token")	remove_custom_type("Token")

	remove_custom_type("Deck")	remove_custom_type("Deck")

		

	if editor_window:	if editor_window:

		editor_window.queue_free()		editor_window.queue_free()

		

	print("CardStory编辑工具已卸载")	print("CardStory编辑工具已卸载")



func open_main_editor():func open_main_editor():

	if not editor_window:	if not editor_window:

		editor_window = MAIN_EDITOR_SCENE.instantiate()		editor_window = MAIN_EDITOR_SCENE.instantiate()

		EditorInterface.get_editor_main_screen().add_child(editor_window)		EditorInterface.get_editor_main_screen().add_child(editor_window)

		

	editor_window.show()	editor_window.show()

	editor_window.grab_focus()	editor_window.grab_focus()

	print("打开CardStory主编辑器")	print("打开CardStory主编辑器")



func _handles(object):func _handles(object):

	# 处理CardStory相关资源	# 处理CardStory相关资源

	if object is Resource:	if object is Resource:

		return object.get_script() and (		return object.get_script() and (

			object.get_script().get_path().begins_with("res://scripts/core/")			object.get_script().get_path().begins_with("res://scripts/core/")

		)		)

	return false	return false



func _edit(object):func _edit(object):

	# 编辑CardStory资源时自动打开专用编辑器	# 编辑CardStory资源时自动打开专用编辑器

	if _handles(object):	if _handles(object):

		open_main_editor()		open_main_editor()

		if editor_window and editor_window.has_method("load_resource_for_editing"):		if editor_window:

			editor_window.load_resource_for_editing(object.resource_path)			editor_window.load_resource_for_editing(object.resource_path)
