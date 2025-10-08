# SaveManager - 游戏保存管理器
class_name SaveManager
extends Node

# 单例实例
static var instance: SaveManager

# 保存文件名（如果为空则保存到内存）
@export var file_name: String = ""

# 内存保存数据
var memory_save: String = ""

# 卡牌ID映射表
var cards: Dictionary = {}

func _ready():
	# 设置单例
	if instance == null:
		instance = self
	else:
		queue_free()

# 保存数据
func save(json_data: String):
	if not file_name.is_empty():
		save_to_file(json_data)
	else:
		memory_save = json_data

# 加载数据
func load() -> String:
	if not file_name.is_empty():
		return load_from_file()
	else:
		return memory_save

# 保存到文件
func save_to_file(data: String):
	var file = FileAccess.open(file_name, FileAccess.WRITE)
	if file:
		file.store_string(data)
		file.close()
		print("游戏保存到文件: ", file_name)
	else:
		push_error("无法写入保存文件: " + file_name)

# 从文件加载
func load_from_file() -> String:
	if not FileAccess.file_exists(file_name):
		push_warning("保存文件不存在: " + file_name)
		return ""
	
	var file = FileAccess.open(file_name, FileAccess.READ)
	if file:
		var data = file.get_as_text()
		file.close()
		print("从文件加载游戏: ", file_name)
		return data
	else:
		push_error("无法读取保存文件: " + file_name)
		return ""

# 注册卡牌ID映射
func register_card(id: int, card_viz: CardViz):
	if card_viz:
		cards[id] = card_viz

# 根据ID获取卡牌
func card_from_id(id: int) -> CardViz:
	if cards.has(id):
		return cards[id]
	else:
		return null

# 清除卡牌映射表
func clear_cards():
	cards.clear()

# 获取保存文件的完整路径
func get_save_path() -> String:
	if file_name.is_empty():
		return "内存保存"
	
	# 如果是相对路径，添加用户数据目录前缀
	if not file_name.is_absolute_path():
		return "user://" + file_name
	else:
		return file_name

# 检查保存文件是否存在
func has_save_file() -> bool:
	if file_name.is_empty():
		return not memory_save.is_empty()
	else:
		return FileAccess.file_exists(get_save_path())

# 删除保存文件
func delete_save():
	if file_name.is_empty():
		memory_save = ""
	else:
		var full_path = get_save_path()
		if FileAccess.file_exists(full_path):
			DirAccess.remove_absolute(full_path)
			print("删除保存文件: ", full_path)

# 获取保存文件信息
func get_save_info() -> Dictionary:
	var info = {
		"exists": has_save_file(),
		"path": get_save_path(),
		"size": 0,
		"modified_time": ""
	}
	
	if file_name.is_empty():
		info.size = memory_save.length()
		info.modified_time = "内存保存"
	else:
		var full_path = get_save_path()
		if FileAccess.file_exists(full_path):
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				info.size = file.get_length()
				file.close()
			
			# 获取文件修改时间
			var file_time = FileAccess.get_modified_time(full_path)
			var datetime = Time.get_datetime_dict_from_unix_time(file_time)
			info.modified_time = "%04d-%02d-%02d %02d:%02d:%02d" % [
				datetime.year, datetime.month, datetime.day,
				datetime.hour, datetime.minute, datetime.second
			]
	
	return info

# 自动保存功能
var auto_save_enabled: bool = false
var auto_save_interval: float = 300.0  # 5分钟
var auto_save_timer: float = 0.0

func enable_auto_save(interval_seconds: float = 300.0):
	auto_save_enabled = true
	auto_save_interval = interval_seconds
	auto_save_timer = 0.0
	print("自动保存已启用，间隔: ", interval_seconds, "秒")

func disable_auto_save():
	auto_save_enabled = false
	print("自动保存已禁用")

func _process(delta):
	if auto_save_enabled:
		auto_save_timer += delta
		if auto_save_timer >= auto_save_interval:
			auto_save_timer = 0.0
			trigger_auto_save()

func trigger_auto_save():
	if GameManager.instance and GameManager.instance.has_method("save_game"):
		print("执行自动保存...")
		GameManager.instance.save_game()

# 备份保存功能
var backup_count: int = 3

func create_backup():
	if file_name.is_empty():
		return
	
	var full_path = get_save_path()
	if not FileAccess.file_exists(full_path):
		return
	
	# 移动现有备份
	for i in range(backup_count - 1, 0, -1):
		var old_backup = full_path + ".bak" + str(i)
		var new_backup = full_path + ".bak" + str(i + 1)
		
		if FileAccess.file_exists(old_backup):
			if FileAccess.file_exists(new_backup):
				DirAccess.remove_absolute(new_backup)
			DirAccess.rename_absolute(old_backup, new_backup)
	
	# 创建新备份
	var backup_path = full_path + ".bak1"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	DirAccess.copy_absolute(full_path, backup_path)
	
	print("创建备份: ", backup_path)

func restore_backup(backup_number: int = 1) -> bool:
	if file_name.is_empty():
		return false
	
	var full_path = get_save_path()
	var backup_path = full_path + ".bak" + str(backup_number)
	
	if not FileAccess.file_exists(backup_path):
		push_error("备份文件不存在: " + backup_path)
		return false
	
	# 删除当前保存文件
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(full_path)
	
	# 恢复备份
	DirAccess.copy_absolute(backup_path, full_path)
	print("恢复备份: ", backup_path, " -> ", full_path)
	return true

# 重置管理器
func reset():
	clear_cards()
	auto_save_timer = 0.0