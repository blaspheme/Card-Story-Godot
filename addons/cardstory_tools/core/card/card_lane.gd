# CardLane - 卡牌通道组件
class_name CardLane
extends Control

# 配置属性
@export var stack_matching: bool = false			# 是否堆叠相同卡牌
@export var max_spacing_x: float = 100.0			# 最大X轴间距
@export var spacing_z: float = 0.1					# Z轴间距（深度）

# 卡牌列表
var cards: Array[CardViz] = []

# 父窗口引用
var act_window: ActWindow

# 接口：卡牌停靠时调用
func on_card_dock(card_viz: CardViz):
	if card_viz and GameManager.instance:
		# 返回到桌面
		if GameManager.instance.table and GameManager.instance.table.has_method("return_to_table"):
			GameManager.instance.table.return_to_table(card_viz)

# 接口：卡牌离开时调用
func on_card_undock(card_viz: CardViz):
	if card_viz:
		cards.erase(card_viz)
		# 显示正面
		if card_viz.has_method("show_face"):
			card_viz.show_face()

# 放置卡牌列表
func place_cards(card_list: Array[CardViz]):
	if card_list.is_empty():
		return
	
	# 预处理卡牌状态
	for card_viz in card_list:
		if card_viz:
			# 完成当前动画
			if card_viz.has_method("complete_tweens"):
				card_viz.complete_tweens()
			
			# 显示卡牌并设置交互状态
			card_viz.show()
			if card_viz.has_method("set_free"):
				card_viz.set_free(true)
			if card_viz.has_method("set_interactive"):
				card_viz.set_interactive(true)
	
	# 处理堆叠
	var final_cards: Array[CardViz] = []
	if stack_matching:
		final_cards = _stack_matching_cards(card_list)
	else:
		final_cards = card_list.duplicate()
	
	self.cards = final_cards
	
	# 布局卡牌
	_layout_cards()
	
	# 触发卡牌进场事件
	for i in range(card_list.size() - 1, -1, -1):
		var card_viz = card_list[i]
		if GameManager.instance and GameManager.instance.has_method("trigger_card_in_play"):
			GameManager.instance.trigger_card_in_play(card_viz)

# 堆叠相同卡牌
func _stack_matching_cards(card_list: Array[CardViz]) -> Array[CardViz]:
	var stacked_cards: Array[CardViz] = []
	
	for card_viz in card_list:
		if not card_viz:
			continue
			
		var stacked = false
		
		# 寻找可以堆叠的卡牌
		for existing_card in stacked_cards:
			if existing_card and existing_card.has_method("can_stack_with") and existing_card.can_stack_with(card_viz):
				# 堆叠到现有卡牌
				if existing_card.has_method("stack_card"):
					existing_card.stack_card(card_viz)
				stacked = true
				break
		
		if not stacked:
			stacked_cards.append(card_viz)
	
	return stacked_cards

# 布局卡牌
func _layout_cards():
	if cards.is_empty():
		return
	
	var card_count = cards.size()
	
	# 计算间距
	var rect_size = size
	var spacing_x = min(rect_size.x / card_count, max_spacing_x) if card_count > 1 else 0
	
	# 计算起始偏移
	var start_offset = Vector2(
		-0.5 * spacing_x * (card_count - 1),
		0
	)
	
	# 布局每张卡牌
	for i in range(cards.size()):
		var card_viz = cards[i]
		if card_viz:
			# 设置父节点
			card_viz.reparent(self)
			
			# 计算位置
			var local_pos = Vector2(
				start_offset.x + i * spacing_x,
				0
			)
			card_viz.position = local_pos
			
			# 设置Z顺序（深度）
			card_viz.z_index = -i * spacing_z

# 保存通道状态
func save() -> Dictionary:
	var save_data = {
		"max_spacing_x": max_spacing_x,
		"spacing_z": spacing_z,
		"stack_matching": stack_matching,
		"cards": []
	}
	
	for card_viz in cards:
		if card_viz and card_viz.has_method("get_instance_id"):
			save_data.cards.append(card_viz.get_instance_id())
	
	return save_data

# 加载通道状态
func load_from_dict(save_data: Dictionary):
	if save_data.has("max_spacing_x"):
		max_spacing_x = save_data.max_spacing_x
	
	if save_data.has("spacing_z"):
		spacing_z = save_data.spacing_z
	
	if save_data.has("stack_matching"):
		stack_matching = save_data.stack_matching
	
	# 重建卡牌列表（需要配合SaveManager）
	if save_data.has("cards") and SaveManager.instance:
		var rebuilt_cards: Array[CardViz] = []
		for card_id in save_data.cards:
			if SaveManager.instance.has_method("card_from_id"):
				var card_viz = SaveManager.instance.card_from_id(card_id)
				if card_viz:
					rebuilt_cards.append(card_viz)
		
		place_cards(rebuilt_cards)

# 添加单张卡牌
func add_card(card_viz: CardViz):
	if card_viz and not cards.has(card_viz):
		cards.append(card_viz)
		_layout_cards()

# 移除单张卡牌
func remove_card(card_viz: CardViz):
	if card_viz and cards.has(card_viz):
		cards.erase(card_viz)
		_layout_cards()

# 清空通道
func clear():
	for card_viz in cards:
		if card_viz and card_viz.get_parent() == self:
			card_viz.reparent(get_parent())
	
	cards.clear()

# 获取通道中的卡牌数量
func get_card_count() -> int:
	return cards.size()

# 检查是否为空
func is_empty() -> bool:
	return cards.is_empty()

# 获取第一张卡牌
func get_first_card() -> CardViz:
	return cards[0] if not cards.is_empty() else null

# 获取最后一张卡牌
func get_last_card() -> CardViz:
	return cards[-1] if not cards.is_empty() else null

func _ready():
	# 查找父窗口
	var parent = get_parent()
	while parent:
		if parent is ActWindow:
			act_window = parent
			break
		parent = parent.get_parent()

# 拖拽处理
func _can_drop_data(position: Vector2, data) -> bool:
	return data is CardViz

func _drop_data(position: Vector2, data):
	if data is CardViz:
		on_card_dock(data)

# 获取通道信息（调试用）
func get_lane_info() -> String:
	return "CardLane: %d 张卡牌, 堆叠: %s" % [cards.size(), stack_matching]

# 打印通道内容（调试用）
func print_lane_contents():
	print("=== 卡牌通道内容 ===")
	print(get_lane_info())
	for i in range(cards.size()):
		var card = cards[i]
		print("  [%d] %s" % [
			i, 
			card.get_card_name() if card and card.has_method("get_card_name") else "未知卡牌"
		])
	print("====================")