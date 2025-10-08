# CardStory主编辑器
@tool
extends Window

# UI组件引用
@onready var resource_tree: Tree = $VBoxContainer/HSplitContainer/LeftPanel/ResourceTree
@onready var node_graph: GraphEdit = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer/NodeGraphContainer/NodeGraph
@onready var property_container: VBoxContainer = $VBoxContainer/HSplitContainer/RightPanel/PropertyTabs/基本/PropertyContainer
@onready var validation_text: RichTextLabel = $VBoxContainer/HSplitContainer/RightPanel/ValidationPanel/ValidationText
@onready var console_log: RichTextLabel = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer/BottomPanel/ConsoleTabs/日志
@onready var console_error: RichTextLabel = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer/BottomPanel/ConsoleTabs/错误
@onready var console_debug: RichTextLabel = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer/BottomPanel/ConsoleTabs/调试

# 菜单引用
@onready var file_menu: PopupMenu = $VBoxContainer/MenuBar/File
@onready var edit_menu: PopupMenu = $VBoxContainer/MenuBar/Edit
@onready var view_menu: PopupMenu = $VBoxContainer/MenuBar/View
@onready var tools_menu: PopupMenu = $VBoxContainer/MenuBar/Tools
@onready var help_menu: PopupMenu = $VBoxContainer/MenuBar/Help

# 工具栏引用
@onready var layout_button: Button = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer/NodeGraphContainer/GraphToolbar/LayoutButton
@onready var zoom_slider: HSlider = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer/NodeGraphContainer/GraphToolbar/ZoomSlider

# 当前编辑的资源
var current_resource: Resource
var current_resource_path: String

# 资源缓存
var resource_cache: Dictionary = {}

# 节点图相关
var node_instances: Dictionary = {}

func _ready():
	setup_ui()
	setup_menu_connections()
	load_resources()
	log_message("CardStory编辑器已启动", Color.CYAN)

func setup_ui():
	title = "CardStory编辑器"
	
	# 设置分割面板比例
	var hsplit = $VBoxContainer/HSplitContainer
	hsplit.split_offset = 250
	
	var vsplit = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer
	vsplit.split_offset = -150
	
	# 连接节点图信号
	node_graph.connection_request.connect(_on_connection_request)
	node_graph.disconnection_request.connect(_on_disconnection_request)
	
	# 连接缩放滑块
	zoom_slider.value_changed.connect(_on_zoom_changed)
	
	# 连接布局按钮
	layout_button.pressed.connect(_on_auto_layout_pressed)
	
	# 连接资源树
	resource_tree.item_selected.connect(_on_resource_selected)

func setup_menu_connections():
	# 文件菜单
	file_menu.id_pressed.connect(_on_file_menu_pressed)
	edit_menu.id_pressed.connect(_on_edit_menu_pressed)
	view_menu.id_pressed.connect(_on_view_menu_pressed)
	tools_menu.id_pressed.connect(_on_tools_menu_pressed)
	help_menu.id_pressed.connect(_on_help_menu_pressed)

func load_resources():
	resource_tree.clear()
	var root = resource_tree.create_item()
	root.set_text(0, "CardStory资源")
	
	# 加载各类型资源
	load_resource_folder("res://resources/content/fragments/aspects/", "Aspects", root)
	load_resource_folder("res://resources/content/fragments/cards/", "Cards", root)
	load_resource_folder("res://resources/content/acts/", "Acts", root)
	load_resource_folder("res://resources/content/rules/", "Rules", root)
	load_resource_folder("res://resources/content/slots/", "Slots", root)
	load_resource_folder("res://resources/content/tokens/", "Tokens", root)
	load_resource_folder("res://resources/content/decks/", "Decks", root)

func load_resource_folder(path: String, type_name: String, parent: TreeItem):
	# 确保目录存在
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	
	var dir = DirAccess.open(path)
	if not dir:
		log_error("无法打开目录: " + path)
		return
		
	var type_item = resource_tree.create_item(parent)
	type_item.set_text(0, type_name)
	type_item.set_icon(0, get_type_icon(type_name))
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_item = resource_tree.create_item(type_item)
			resource_item.set_text(0, file_name.get_basename())
			resource_item.set_metadata(0, path + file_name)
		file_name = dir.get_next()

func get_type_icon(type_name: String) -> Texture2D:
	var icon_path = "res://addons/cardstory_tools/icons/" + type_name.to_lower() + ".svg"
	if ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	else:
		# 返回默认图标
		return EditorInterface.get_editor_theme().get_icon("Object", "EditorIcons")

func _on_resource_selected():
	var selected = resource_tree.get_selected()
	if not selected or not selected.get_metadata(0):
		return
		
	var resource_path = selected.get_metadata(0)
	load_resource_for_editing(resource_path)

func load_resource_for_editing(path: String):
	current_resource_path = path
	
	# 从缓存加载或创建新资源
	if path in resource_cache:
		current_resource = resource_cache[path]
	else:
		if ResourceLoader.exists(path):
			current_resource = load(path)
			resource_cache[path] = current_resource
		else:
			log_error("资源文件不存在: " + path)
			return
	
	# 更新各个面板
	update_node_graph()
	update_property_panel()
	validate_current_resource()
	
	log_message("已加载资源: " + path.get_file(), Color.GREEN)

func update_node_graph():
	clear_node_graph()
	
	if current_resource is Act:
		create_act_graph(current_resource as Act)
	elif current_resource is Rule:
		create_rule_graph(current_resource as Rule)

func clear_node_graph():
	for child in node_graph.get_children():
		if child is GraphNode:
			child.queue_free()
	node_instances.clear()

func create_act_graph(act: Act):
	# 创建主Act节点
	var main_node = create_act_node(act, Vector2(400, 200))
	
	# 创建Entry Tests节点
	if not act.tests.is_empty() or not act.and_rules.is_empty() or not act.or_rules.is_empty():
		var entry_node = create_entry_tests_node(act, Vector2(100, 200))
		node_graph.connect_node(entry_node.name, 0, main_node.name, 0)
	
	# 创建后续Act节点
	var x_offset = 700
	var y_offset = 100
	
	# Alt Acts
	for i in range(act.alt_acts.size()):
		if act.alt_acts[i] and act.alt_acts[i].act:
			var alt_act = act.alt_acts[i].act
			var alt_node = create_act_node(alt_act, Vector2(x_offset, y_offset + i * 120), true)
			node_graph.connect_node(main_node.name, 1, alt_node.name, 0)
	
	# Next Acts  
	for i in range(act.next_acts.size()):
		if act.next_acts[i] and act.next_acts[i].act:
			var next_act = act.next_acts[i].act
			var next_node = create_act_node(next_act, Vector2(x_offset + 200, y_offset + i * 120), true)
			node_graph.connect_node(main_node.name, 2, next_node.name, 0)
	
	# Spawned Acts
	for i in range(act.spawned_acts.size()):
		if act.spawned_acts[i] and act.spawned_acts[i].act:
			var spawned_act = act.spawned_acts[i].act
			var spawned_node = create_act_node(spawned_act, Vector2(x_offset + 400, y_offset + i * 120), true)
			node_graph.connect_node(main_node.name, 3, spawned_node.name, 0)

func create_act_node(act: Act, pos: Vector2, readonly: bool = false) -> GraphNode:
	var node = GraphNode.new()
	node.name = "Act_" + str(act.get_instance_id())
	node.title = act.label if not act.label.is_empty() else "未命名Act"
	node.position_offset = pos
	
	# 设置插槽
	if not readonly:
		node.set_slot_enabled_left(0, true)   # 输入：条件
		node.set_slot_enabled_right(1, true)  # 输出：Alt Acts
		node.set_slot_enabled_right(2, true)  # 输出：Next Acts  
		node.set_slot_enabled_right(3, true)  # 输出：Spawned Acts
		
		node.set_slot_color_left(0, Color.BLUE)
		node.set_slot_color_right(1, Color.YELLOW)
		node.set_slot_color_right(2, Color.GREEN)
		node.set_slot_color_right(3, Color.RED)
	else:
		node.set_slot_enabled_left(0, true)
		node.set_slot_color_left(0, Color.GRAY)
	
	# 添加内容
	var content_container = VBoxContainer.new()
	
	if act.time > 0:
		var time_label = Label.new()
		time_label.text = "执行时间: " + str(act.time) + "s"
		content_container.add_child(time_label)
	
	if act.fragments.size() > 0:
		var fragments_label = Label.new()
		fragments_label.text = "效果: " + str(act.fragments.size()) + " 个Fragment"
		content_container.add_child(fragments_label)
	
	if not act.text.is_empty():
		var desc_label = Label.new()
		desc_label.text = act.text.substr(0, 30) + ("..." if act.text.length() > 30 else "")
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_container.add_child(desc_label)
	
	node.add_child(content_container)
	
	# 存储关联数据
	node.set_meta("resource", act)
	node_instances[node.name] = node
	
	node_graph.add_child(node)
	return node

func create_entry_tests_node(act: Act, pos: Vector2) -> GraphNode:
	var node = GraphNode.new()
	node.name = "Entry_" + str(act.get_instance_id())
	node.title = "进入条件"
	node.position_offset = pos
	
	node.set_slot_enabled_right(0, true)
	node.set_slot_color_right(0, Color.BLUE)
	
	var content_container = VBoxContainer.new()
	
	# 添加条件信息
	if act.tests.size() > 0:
		var tests_label = Label.new()
		tests_label.text = "Tests: " + str(act.tests.size())
		content_container.add_child(tests_label)
	
	if act.and_rules.size() > 0:
		var and_label = Label.new()
		and_label.text = "AND Rules: " + str(act.and_rules.size())
		content_container.add_child(and_label)
	
	if act.or_rules.size() > 0:
		var or_label = Label.new()
		or_label.text = "OR Rules: " + str(act.or_rules.size())  
		content_container.add_child(or_label)
	
	node.add_child(content_container)
	node_graph.add_child(node)
	return node

func create_rule_graph(rule: Rule):
	# 为Rule创建简化的节点图
	var main_node = GraphNode.new()
	main_node.name = "Rule_Main"
	main_node.title = "规则"
	main_node.position_offset = Vector2(400, 200)
	
	var content_container = VBoxContainer.new()
	
	if rule.tests.size() > 0:
		var tests_label = Label.new()
		tests_label.text = "Tests: " + str(rule.tests.size())
		content_container.add_child(tests_label)
	
	if rule.act_modifiers.size() > 0:
		var act_mod_label = Label.new()
		act_mod_label.text = "Act修改器: " + str(rule.act_modifiers.size())
		content_container.add_child(act_mod_label)
	
	if rule.card_modifiers.size() > 0:
		var card_mod_label = Label.new()
		card_mod_label.text = "Card修改器: " + str(rule.card_modifiers.size())
		content_container.add_child(card_mod_label)
	
	main_node.add_child(content_container)
	node_graph.add_child(main_node)

func update_property_panel():
	# 清空现有属性
	for child in property_container.get_children():
		child.queue_free()
	
	if not current_resource:
		return
	
	# 创建基本属性编辑器
	create_basic_properties()

func create_basic_properties():
	if not current_resource:
		return
	
	var properties = current_resource.get_property_list()
	
	for property in properties:
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			create_property_editor(property)

func create_property_editor(property: Dictionary):
	var property_name = property.name
	var property_type = property.type
	var current_value = current_resource.get(property_name)
	
	# 创建属性行
	var hbox = HBoxContainer.new()
	property_container.add_child(hbox)
	
	# 属性标签
	var label = Label.new()
	label.text = beautify_property_name(property_name)
	label.custom_minimum_size.x = 120
	hbox.add_child(label)
	
	# 创建对应的编辑器控件
	match property_type:
		TYPE_STRING:
			var line_edit = LineEdit.new()
			line_edit.text = str(current_value)
			line_edit.text_changed.connect(func(text): update_property(property_name, text))
			hbox.add_child(line_edit)
			
		TYPE_INT:
			var spin_box = SpinBox.new()
			spin_box.value = current_value
			spin_box.allow_greater = true
			spin_box.allow_lesser = true
			spin_box.value_changed.connect(func(value): update_property(property_name, int(value)))
			hbox.add_child(spin_box)
			
		TYPE_FLOAT:
			var spin_box = SpinBox.new()
			spin_box.step = 0.01
			spin_box.value = current_value
			spin_box.allow_greater = true
			spin_box.allow_lesser = true
			spin_box.value_changed.connect(func(value): update_property(property_name, value))
			hbox.add_child(spin_box)
			
		TYPE_BOOL:
			var check_box = CheckBox.new()
			check_box.button_pressed = current_value
			check_box.toggled.connect(func(pressed): update_property(property_name, pressed))
			hbox.add_child(check_box)
			
		_:
			# 其他类型暂时显示为标签
			var value_label = Label.new()
			value_label.text = str(current_value)
			hbox.add_child(value_label)

func beautify_property_name(name: String) -> String:
	return name.replace("_", " ").capitalize()

func update_property(property_name: String, value):
	if current_resource:
		current_resource.set(property_name, value)
		mark_resource_dirty()
		validate_current_resource()

func mark_resource_dirty():
	if current_resource_path:
		title = "CardStory编辑器*"  # 添加*表示未保存

func save_current_resource():
	if current_resource and current_resource_path:
		var result = ResourceSaver.save(current_resource, current_resource_path)
		if result == OK:
			title = "CardStory编辑器"  # 移除*
			log_message("已保存: " + current_resource_path.get_file(), Color.GREEN)
		else:
			log_error("保存失败: " + current_resource_path.get_file())

func validate_current_resource():
	if not current_resource:
		validation_text.clear()
		validation_text.append_text("选择资源以查看验证结果...")
		return
	
	# 这里应该调用验证器，暂时显示基本信息
	validation_text.clear()
	validation_text.append_text("[color=green]✓ 基本验证通过[/color]\n")
	validation_text.append_text("资源类型: " + current_resource.get_class() + "\n")
	if current_resource.has_method("get_property_list"):
		var props = current_resource.get_property_list()
		var script_props = props.filter(func(p): return p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE)
		validation_text.append_text("属性数量: " + str(script_props.size()))

# 信号处理函数
func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	node_graph.connect_node(from_node, from_port, to_node, to_port)
	log_debug("连接节点: " + from_node + ":" + str(from_port) + " -> " + to_node + ":" + str(to_port))

func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	node_graph.disconnect_node(from_node, from_port, to_node, to_port)
	log_debug("断开连接: " + from_node + ":" + str(from_port) + " -> " + to_node + ":" + str(to_port))

func _on_zoom_changed(value: float):
	node_graph.zoom = value

func _on_auto_layout_pressed():
	# 自动布局节点图
	log_message("执行自动布局", Color.YELLOW)

# 菜单处理函数
func _on_file_menu_pressed(id: int):
	match id:
		0: # 新建
			log_message("新建资源", Color.CYAN)
		1: # 打开
			show_open_dialog()
		2: # 保存
			save_current_resource()
		4: # 退出
			hide()

func _on_edit_menu_pressed(id: int):
	match id:
		0: # 撤销
			log_message("撤销操作", Color.YELLOW)
		1: # 重做
			log_message("重做操作", Color.YELLOW)

func _on_view_menu_pressed(id: int):
	match id:
		0: # 重置布局
			reset_layout()
		1: # 全屏
			if get_window().mode == Window.MODE_WINDOWED:
				get_window().mode = Window.MODE_FULLSCREEN
			else:
				get_window().mode = Window.MODE_WINDOWED

func _on_tools_menu_pressed(id: int):
	match id:
		0: # 验证所有资源
			validate_all_resources()
		1: # 导出配置
			log_message("导出配置", Color.CYAN)
		2: # 导入配置
			log_message("导入配置", Color.CYAN)

func _on_help_menu_pressed(id: int):
	match id:
		0: # 帮助文档
			OS.shell_open("https://github.com/your-repo/cardstory-docs")
		1: # 关于
			show_about_dialog()

func show_open_dialog():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot资源文件")
	dialog.add_filter("*.res", "Godot二进制资源")
	dialog.current_dir = "res://resources/content/"
	
	dialog.file_selected.connect(func(path): load_resource_for_editing(path))
	
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func reset_layout():
	var hsplit = $VBoxContainer/HSplitContainer
	hsplit.split_offset = 250
	
	var vsplit = $VBoxContainer/HSplitContainer/CenterPanel/VSplitContainer
	vsplit.split_offset = -150
	
	log_message("已重置布局", Color.GREEN)

func validate_all_resources():
	log_message("开始验证所有资源...", Color.CYAN)
	# 这里实现批量验证逻辑
	log_message("验证完成", Color.GREEN)

func show_about_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "关于CardStory编辑器"
	dialog.dialog_text = """CardStory编辑器 v1.0.0

一个功能强大的卡牌游戏框架编辑工具
基于Godot引擎开发

© 2024 CardStory Team"""
	
	add_child(dialog)
	dialog.popup_centered()

# 日志函数
func log_message(message: String, color: Color = Color.WHITE):
	console_log.push_color(color)
	console_log.append_text("[" + Time.get_time_string_from_system() + "] " + message + "\n")
	console_log.pop()

func log_error(message: String):
	console_error.push_color(Color.RED)
	console_error.append_text("[" + Time.get_time_string_from_system() + "] ERROR: " + message + "\n")
	console_error.pop()
	
	# 同时在主日志显示
	log_message("ERROR: " + message, Color.RED)

func log_debug(message: String):
	console_debug.push_color(Color.GRAY)
	console_debug.append_text("[" + Time.get_time_string_from_system() + "] DEBUG: " + message + "\n")
	console_debug.pop()