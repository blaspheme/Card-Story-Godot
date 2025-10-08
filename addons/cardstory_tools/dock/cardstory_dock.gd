# CardStory停靠面板
@tool
extends Control

@onready var quick_create_container: VBoxContainer = $VBoxContainer/QuickCreateContainer
@onready var resource_list: ItemList = $VBoxContainer/ResourceList
@onready var debug_panel: Control = $VBoxContainer/DebugPanel

var recent_resources: Array[String] = []

func _ready():
	setup_quick_create()
	load_recent_resources()

func setup_quick_create():
	# 创建快速创建按钮
	var button_configs = [
		{"text": "新建Fragment", "script": "res://scripts/core/fragment.gd"},
		{"text": "新建Card", "script": "res://scripts/core/card.gd"},
		{"text": "新建Aspect", "script": "res://scripts/core/aspect.gd"},
		{"text": "新建Act", "script": "res://scripts/core/act.gd"},
		{"text": "新建Rule", "script": "res://scripts/core/rule.gd"},
		{"text": "新建Slot", "script": "res://scripts/core/slot.gd"},
		{"text": "新建Token", "script": "res://scripts/core/token.gd"},
		{"text": "新建Deck", "script": "res://scripts/core/deck.gd"}
	]
	
	for config in button_configs:
		var button = Button.new()
		button.text = config.text
		button.pressed.connect(func(): create_new_resource(config.script))
		quick_create_container.add_child(button)

func create_new_resource(script_path: String):
	# 创建新资源的逻辑
	var script = load(script_path)
	var new_resource = script.new()
	
	# 打开保存对话框
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot资源文件")
	
	# 根据类型设置默认目录
	var default_dir = get_default_save_directory(script_path)
	dialog.current_dir = default_dir
	
	dialog.file_selected.connect(func(path): save_new_resource(new_resource, path))
	
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))

func get_default_save_directory(script_path: String) -> String:
	if "fragment" in script_path:
		return "res://resources/content/fragments/"
	elif "card" in script_path:
		return "res://resources/content/fragments/cards/"
	elif "aspect" in script_path:
		return "res://resources/content/fragments/aspects/"
	elif "act" in script_path:
		return "res://resources/content/acts/"
	elif "rule" in script_path:
		return "res://resources/content/rules/"
	elif "slot" in script_path:
		return "res://resources/content/slots/"
	elif "token" in script_path:
		return "res://resources/content/tokens/"
	elif "deck" in script_path:
		return "res://resources/content/decks/"
	else:
		return "res://resources/content/"

func save_new_resource(resource: Resource, path: String):
	# 设置基本属性
	if resource.has_method("set") and resource.has_property("label"):
		resource.label = path.get_file().get_basename()
	
	# 保存资源
	var result = ResourceSaver.save(resource, path)
	if result == OK:
		print("已创建新资源: ", path)
		add_to_recent_resources(path)
		# 资源创建完成，可以手动打开编辑器
	else:
		print("创建资源失败: ", path)

func load_recent_resources():
	resource_list.clear()
	for path in recent_resources:
		if FileAccess.file_exists(path):
			resource_list.add_item(path.get_file().get_basename())
			resource_list.set_item_metadata(resource_list.get_item_count() - 1, path)

func add_to_recent_resources(path: String):
	if path in recent_resources:
		recent_resources.erase(path)
	recent_resources.push_front(path)
	
	# 限制最近资源数量
	if recent_resources.size() > 10:
		recent_resources.resize(10)
	
	load_recent_resources()

func _on_resource_list_item_selected(index: int):
	var path = resource_list.get_item_metadata(index)
	if path:
		# 在编辑器中选择资源
		EditorInterface.select_file(path)