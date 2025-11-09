extends Node2D
class_name Table

## 桌面基类
## 管理卡片在桌面上的放置、移除、查找空位等功能

# ===============================
# 引用
# ===============================
## FragTree 引用（通过路径获取）
var frag_tree: FragTree

## 记录卡片最后的位置（用于返回桌面）
var last_locations: Dictionary = {}  # {CardViz: T}

# ===============================
# 抽象方法（子类必须实现）
# ===============================

## 将逻辑坐标转换为本地世界坐标
func to_local_position(_grid_pos) -> Vector2:
	push_error("Table.to_local_position() 必须被子类重写")
	return Vector2.ZERO

## 将本地世界坐标转换为逻辑坐标
func from_local_position(_local_pos: Vector2):
	push_error("Table.from_local_position() 必须被子类重写")
	return null

## 查找空闲位置（在指定位置附近螺旋搜索）
## @param grid_pos: 起始搜索位置（引用传递，会被修改为找到的空位）
## @param card: 要放置的卡片
## @return: 是否找到空位
func find_free_location(_grid_pos, _card: CardViz) -> bool:
	push_error("Table.find_free_location() 必须被子类重写")
	return false

## 查找多个空闲位置
## @param anchor_card: 锚点卡片（搜索起点）
## @param cards: 要放置的卡片列表
## @return: 位置列表
func find_free_locations(_anchor_card: CardViz, _cards: Array[CardViz]) -> Array:
	push_error("Table.find_free_locations() 必须被子类重写")
	return []

## 从桌面移除卡片（清空占用的网格）
func remove_card(_card: CardViz) -> void:
	push_error("Table.remove_card() 必须被子类重写")

# ===============================
# 公开接口
# ===============================

## 将卡片放置到指定位置
## @param card: 要放置的卡片
## @param grid_pos: 网格位置
## @param move_duration: 移动动画时长
func place_card(card: CardViz, grid_pos, move_duration: float = 0.3) -> void:
	if card == null:
		return
	
	# 重新父化到桌面
	if card.get_parent() != self:
		card.reparent(self)
	
	# 移动到目标位置
	var target_pos := to_local_position(grid_pos)
	card.move_to(target_pos, move_duration)
	
	# 记录位置
	last_locations[card] = grid_pos
	
	# 子类实现：标记网格占用
	_on_card_placed(card, grid_pos)

## 放置多张卡片
## @param anchor_card: 锚点卡片（搜索起点）
## @param cards: 要放置的卡片列表
func place_cards(anchor_card: CardViz, cards: Array[CardViz], move_duration: float = 0.3) -> void:
	var locations := find_free_locations(anchor_card, cards)
	
	for i in range(min(cards.size(), locations.size())):
		place_card(cards[i], locations[i], move_duration)
	
	if cards.size() > locations.size():
		push_warning("Table: 没有足够的空间放置所有卡片 (%d/%d)" % [locations.size(), cards.size()])

## 将卡片返回到上次位置（或最近的空位）
func return_to_table(card: CardViz) -> void:
	if card == null:
		return
	
	# 尝试返回上次位置
	if last_locations.has(card):
		var last_pos = last_locations[card]
		if find_free_location(last_pos, card):
			place_card(card, last_pos, 0.3)
			return
	
	# 否则从当前位置搜索最近的空位
	var local_pos := card.position
	var grid_pos = from_local_position(local_pos)  # 不指定类型，因为子类返回类型不同
	if find_free_location(grid_pos, card):
		place_card(card, grid_pos, 0.3)
	else:
		push_error("Table: 无法找到空位返回卡片")

## 获取桌面上的所有卡片
func get_cards() -> Array[CardViz]:
	if frag_tree and frag_tree.has_method("get_cards"):
		return frag_tree.get_cards()
	return []

## 高亮指定的卡片列表（持续1秒）
func highlight_cards(cards: Array[CardViz]) -> void:
	if cards.is_empty():
		return
	
	# 开启高亮
	for card in cards:
		if card:
			card._highlight(true)
	
	# 1秒后关闭
	await get_tree().create_timer(1.0).timeout
	
	for card in cards:
		if card:
			card._highlight(false)

## 检查卡片是否记录了上次位置
func has_last_location(card: CardViz) -> bool:
	return last_locations.has(card)

## 获取卡片上次位置
func get_last_location(card: CardViz):
	return last_locations.get(card, null)

# ===============================
# 内部回调（子类重写）
# ===============================

## 卡片放置后的回调（子类实现网格标记等）
func _on_card_placed(_card: CardViz, _grid_pos) -> void:
	pass

# ===============================
# 生命周期
# ===============================

func _ready() -> void:
	# 获取 FragTree 引用（假设在父节点或同级）
	var parent := get_parent()
	if parent and parent is FragTree:
		frag_tree = parent
	else:
		frag_tree = get_node_or_null("../Root") as FragTree
		if not frag_tree:
			push_warning("Table: 未找到 FragTree 引用")
	
	# 初始化完成后，将现有子卡片放置到桌面
	await get_tree().process_frame
	_initialize_existing_cards()

## 初始化已存在的子卡片
func _initialize_existing_cards() -> void:
	for child in get_children():
		var card := child as CardViz
		if card and card.visible:
			# 从卡片当前位置计算网格坐标
			var grid_pos = from_local_position(card.position)  # 不指定类型
			if find_free_location(grid_pos, card):
				# 不移动，只标记占用
				last_locations[card] = grid_pos
				_on_card_placed(card, grid_pos)
