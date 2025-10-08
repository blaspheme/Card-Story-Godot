# DeckInst - 牌库实例
class_name DeckInst
extends RefCounted

# 牌库资源引用
@export var deck: Deck

# 当前可用的Fragment列表
var fragments: Array[Fragment] = []

func _init(deck_resource: Deck = null):
	if deck_resource:
		deck = deck_resource
		fragments = []
		reshuffle()

# 抽取卡牌
func draw() -> Fragment:
	if fragments.size() > 0:
		return _draw_at_index(0)
	else:
		if deck and deck.replenish:
			reshuffle()
			return _draw_at_index(0)
		else:
			return deck.default_fragment if deck else null

# 从指定位置抽取卡牌
func _draw_at_index(index: int) -> Fragment:
	if index >= 0 and index < fragments.size():
		var fragment = fragments[index]
		if deck and not deck.infinite:
			fragments.remove_at(index)
		return fragment
	else:
		return null

# 基于偏移抽取卡牌
func draw_offset(fragment: Fragment, offset: int) -> Fragment:
	if fragment:
		var index = fragments.find(fragment)
		if index != -1:
			return _draw_at_index(index + offset)
	return null

# 添加Fragment到牌库
func add(fragment: Fragment):
	if fragment:
		fragments.append(fragment)

# 重新洗牌
func reshuffle():
	fragments.clear()
	
	if not deck:
		return
	
	if deck.shuffle:
		# 洗牌模式：随机插入
		var temp_fragments = deck.fragments.duplicate()
		while temp_fragments.size() > 0:
			var random_index = randi() % temp_fragments.size()
			var fragment = temp_fragments[random_index]
			temp_fragments.remove_at(random_index)
			
			# 随机位置插入到目标数组
			var insert_pos = randi() % (fragments.size() + 1)
			fragments.insert(insert_pos, fragment)
	else:
		# 不洗牌：按顺序复制
		fragments = deck.fragments.duplicate()

# 获取剩余卡牌数量
func get_remaining_count() -> int:
	if deck and deck.infinite:
		return -1  # -1 表示无限
	return fragments.size()

# 获取牌库总容量
func get_total_count() -> int:
	return deck.fragments.size() if deck else 0

# 检查牌库是否为空
func is_empty() -> bool:
	if deck and deck.infinite:
		return false
	return fragments.is_empty()

# 查看顶部卡牌（不抽取）
func peek_top() -> Fragment:
	if fragments.size() > 0:
		return fragments[0]
	return null

# 查看底部卡牌（不抽取）
func peek_bottom() -> Fragment:
	if fragments.size() > 0:
		return fragments[-1]
	return null

# 查看指定位置的卡牌（不抽取）
func peek_at(index: int) -> Fragment:
	if index >= 0 and index < fragments.size():
		return fragments[index]
	return null

# 移除特定Fragment
func remove_fragment(fragment: Fragment) -> bool:
	var index = fragments.find(fragment)
	if index != -1:
		fragments.remove_at(index)
		return true
	return false

# 查找Fragment的位置
func find_fragment(fragment: Fragment) -> int:
	return fragments.find(fragment)

# 检查是否包含特定Fragment
func contains_fragment(fragment: Fragment) -> bool:
	return fragments.has(fragment)

# 获取所有Fragment的副本
func get_all_fragments() -> Array[Fragment]:
	return fragments.duplicate()

# 清空牌库
func clear():
	fragments.clear()

# 保存数据
func save() -> Dictionary:
	var save_data = {
		"deck_path": deck.resource_path if deck else "",
		"fragments": []
	}
	
	for fragment in fragments:
		if fragment:
			save_data.fragments.append(fragment.resource_path)
	
	return save_data

# 从保存数据加载
func load_from_dict(save_data: Dictionary):
	if save_data.has("deck_path") and save_data.deck_path != "":
		deck = load(save_data.deck_path) as Deck
	
	fragments.clear()
	if save_data.has("fragments"):
		for fragment_path in save_data.fragments:
			if fragment_path is String and fragment_path != "":
				var fragment = load(fragment_path) as Fragment
				if fragment:
					fragments.append(fragment)

# 调试信息
func get_debug_info() -> String:
	var info = "DeckInst[%s]: %d/%d 张卡牌" % [
		deck.get_display_name() if deck else "无名牌库",
		get_remaining_count(),
		get_total_count()
	]
	
	if deck:
		info += " (洗牌:%s, 无限:%s, 补充:%s)" % [
			deck.shuffle, deck.infinite, deck.replenish
		]
	
	return info

# 打印牌库内容（调试用）
func print_contents():
	print("=== 牌库内容 ===")
	print(get_debug_info())
	print("当前卡牌:")
	for i in range(fragments.size()):
		var fragment = fragments[i]
		print("  [%d] %s" % [i, fragment.get_display_name() if fragment else "null"])
	print("==================")