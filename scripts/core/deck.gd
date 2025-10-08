# Deck - 牌库系统
class_name Deck
extends Resource

# 牌库类型枚举
enum DeckType {
	MAIN = 0,			# 主牌库
	DISCARD = 10,		# 弃牌堆
	EXILE = 20,			# 流放区
	TEMPORARY = 30,		# 临时牌库
}

# 洗牌类型枚举
enum ShuffleType {
	RANDOM = 0,			# 随机洗牌
	WEIGHTED = 10,		# 权重洗牌
	ORDERED = 20,		# 有序排列
	CUSTOM = 30,		# 自定义顺序
}

@export var deck_type: DeckType = DeckType.MAIN		# 牌库类型
@export var label: String = ""						# 显示标签
@export var description: String = ""				# 描述
@export var icon: Texture2D							# 牌库图标

# 容量和限制
@export_group("容量")
@export var max_size: int = -1						# 最大容量（-1表示无限制）
@export var min_size: int = 0						# 最小容量
@export var allow_duplicates: bool = true			# 是否允许重复卡牌
@export var max_duplicates: int = -1				# 每种卡牌最大数量

# 洗牌相关
@export_group("洗牌")
@export var auto_shuffle: bool = true				# 自动洗牌
@export var shuffle_type: ShuffleType = ShuffleType.RANDOM	# 洗牌类型
@export var shuffle_trigger_threshold: int = 0		# 触发洗牌的剩余卡牌数

# 抽牌相关
@export_group("抽牌")
@export var draw_from_top: bool = true				# 从顶部抽牌
@export var reshuffle_discard: bool = true			# 自动重洗弃牌堆
@export var linked_discard_deck: Deck				# 关联的弃牌堆

# 效果相关
@export_group("效果")
@export var on_draw_effects: Array[ActModifier] = []	# 抽牌时效果
@export var on_add_effects: Array[ActModifier] = []		# 添加卡牌时效果
@export var on_shuffle_effects: Array[ActModifier] = []	# 洗牌时效果
@export var on_empty_effects: Array[ActModifier] = []	# 牌库为空时效果

# 内部状态
var _cards: Array[Card] = []						# 卡牌列表
var _shuffle_count: int = 0							# 洗牌次数
var _cards_drawn: int = 0							# 抽牌总数
var _last_shuffle_turn: int = -1					# 上次洗牌回合

# 基础操作
func add_card(card: Card, position: int = -1, context: Context = null) -> bool:
	if not card:
		return false
	
	# 检查容量限制
	if max_size >= 0 and _cards.size() >= max_size:
		print("牌库已满，无法添加: ", get_display_name())
		return false
	
	# 检查重复限制
	if not allow_duplicates and card in _cards:
		print("牌库不允许重复卡牌: ", card.get_display_name())
		return false
	
	if max_duplicates >= 0:
		var duplicate_count = _cards.count(card)
		if duplicate_count >= max_duplicates:
			print("卡牌数量已达上限: ", card.get_display_name())
			return false
	
	# 添加卡牌
	if position < 0 or position >= _cards.size():
		_cards.append(card)
	else:
		_cards.insert(position, card)
	
	# 触发添加效果
	if context:
		for effect in on_add_effects:
			if effect:
				var computed_effect = effect.evaluate(context)
				computed_effect.execute()
	
	print("添加卡牌到牌库: ", card.get_display_name(), " -> ", get_display_name())
	EventBus.emit_signal("deck_card_added", self, card, position)
	
	return true

func remove_card(card: Card, context: Context = null) -> bool:
	if card not in _cards:
		return false
	
	var position = _cards.find(card)
	_cards.erase(card)
	
	print("从牌库移除卡牌: ", card.get_display_name(), " <- ", get_display_name())
	EventBus.emit_signal("deck_card_removed", self, card, position)
	
	# 检查是否触发空牌库效果
	if _cards.is_empty() and context:
		trigger_empty_effects(context)
	
	return true

func draw_card(context: Context = null) -> Card:
	if _cards.is_empty():
		# 尝试重洗弃牌堆
		if reshuffle_discard and linked_discard_deck:
			reshuffle_from_discard(context)
		
		if _cards.is_empty():
			print("牌库为空，无法抽牌: ", get_display_name())
			if context:
				trigger_empty_effects(context)
			return null
	
	# 从指定位置抽牌
	var card: Card
	if draw_from_top:
		card = _cards.pop_front()
	else:
		card = _cards.pop_back()
	
	_cards_drawn += 1
	
	# 检查是否需要洗牌
	if auto_shuffle and shuffle_trigger_threshold > 0:
		if _cards.size() <= shuffle_trigger_threshold:
			shuffle(context)
	
	# 触发抽牌效果
	if context:
		for effect in on_draw_effects:
			if effect:
				var computed_effect = effect.evaluate(context)
				computed_effect.execute()
	
	print("从牌库抽牌: ", card.get_display_name(), " <- ", get_display_name())
	EventBus.emit_signal("deck_card_drawn", self, card)
	
	return card

func draw_cards(count: int, context: Context = null) -> Array[Card]:
	var drawn_cards: Array[Card] = []
	
	for i in range(count):
		var card = draw_card(context)
		if card:
			drawn_cards.append(card)
		else:
			break  # 牌库为空，停止抽牌
	
	return drawn_cards

# 洗牌操作
func shuffle(context: Context = null) -> void:
	if _cards.is_empty():
		return
	
	match shuffle_type:
		ShuffleType.RANDOM:
			_cards.shuffle()
		ShuffleType.WEIGHTED:
			shuffle_weighted()
		ShuffleType.ORDERED:
			shuffle_ordered()
		ShuffleType.CUSTOM:
			shuffle_custom()
		_:
			_cards.shuffle()
	
	_shuffle_count += 1
	if context:
		_last_shuffle_turn = context.get_turn_count()
	
	# 触发洗牌效果
	if context:
		for effect in on_shuffle_effects:
			if effect:
				var computed_effect = effect.evaluate(context)
				computed_effect.execute()
	
	print("洗牌: ", get_display_name(), " (第", _shuffle_count, "次)")
	EventBus.emit_signal("deck_shuffled", self, _shuffle_count)

func shuffle_weighted() -> void:
	# 权重洗牌（可以根据卡牌权重调整概率）
	var weighted_cards = []
	for card in _cards:
		var weight = 1.0
		# 这里可以根据卡牌属性计算权重
		if card.has_method("get_shuffle_weight"):
			weight = card.get_shuffle_weight()
		
		for i in range(int(weight * 10)):  # 权重转换为重复次数
			weighted_cards.append(card)
	
	weighted_cards.shuffle()
	
	# 从加权列表中重新构建牌库（去重）
	_cards.clear()
	for card in weighted_cards:
		if card not in _cards:
			_cards.append(card)

func shuffle_ordered() -> void:
	# 有序排列（按某种规则排序）
	_cards.sort_custom(func(a, b): return a.get_display_name() < b.get_display_name())

func shuffle_custom() -> void:
	# 自定义洗牌逻辑（可以在子类中重写）
	_cards.shuffle()

# 重洗弃牌堆
func reshuffle_from_discard(context: Context = null) -> void:
	if not linked_discard_deck or linked_discard_deck._cards.is_empty():
		return
	
	print("重洗弃牌堆到主牌库: ", linked_discard_deck.get_display_name(), " -> ", get_display_name())
	
	# 将弃牌堆的卡牌移动到主牌库
	for card in linked_discard_deck._cards:
		_cards.append(card)
	
	linked_discard_deck._cards.clear()
	
	# 洗牌
	shuffle(context)
	
	EventBus.emit_signal("deck_reshuffled", self, linked_discard_deck)

# 触发空牌库效果
func trigger_empty_effects(context: Context) -> void:
	for effect in on_empty_effects:
		if effect:
			var computed_effect = effect.evaluate(context)
			computed_effect.execute()
	
	EventBus.emit_signal("deck_empty", self)

# 查询操作
func peek_top(count: int = 1) -> Array[Card]:
	var peek_count = min(count, _cards.size())
	var peeked_cards: Array[Card] = []
	
	for i in range(peek_count):
		peeked_cards.append(_cards[i])
	
	return peeked_cards

func peek_bottom(count: int = 1) -> Array[Card]:
	var peek_count = min(count, _cards.size())
	var peeked_cards: Array[Card] = []
	var start_index = max(0, _cards.size() - peek_count)
	
	for i in range(start_index, _cards.size()):
		peeked_cards.append(_cards[i])
	
	return peeked_cards

func find_card(fragment: Fragment) -> Card:
	for card in _cards:
		if card == fragment or card.contains_fragment(fragment):
			return card
	return null

func find_cards(fragment: Fragment) -> Array[Card]:
	var found_cards: Array[Card] = []
	for card in _cards:
		if card == fragment or card.contains_fragment(fragment):
			found_cards.append(card)
	return found_cards

func count_cards(fragment: Fragment = null) -> int:
	if not fragment:
		return _cards.size()
	
	var count = 0
	for card in _cards:
		if card == fragment or card.contains_fragment(fragment):
			count += 1
	return count

# 状态查询
func is_empty() -> bool:
	return _cards.is_empty()

func is_full() -> bool:
	return max_size >= 0 and _cards.size() >= max_size

func get_size() -> int:
	return _cards.size()

func get_remaining_capacity() -> int:
	if max_size < 0:
		return -1  # 无限制
	return max_size - _cards.size()

func can_add_card(card: Card) -> bool:
	if not card:
		return false
	
	if max_size >= 0 and _cards.size() >= max_size:
		return false
	
	if not allow_duplicates and card in _cards:
		return false
	
	if max_duplicates >= 0 and _cards.count(card) >= max_duplicates:
		return false
	
	return true

# 获取卡牌列表
func get_cards() -> Array[Card]:
	return _cards.duplicate()

func get_all_fragments() -> Array[Fragment]:
	var fragments: Array[Fragment] = []
	for card in _cards:
		fragments.append(card)
		fragments.append_array(card.fragments)
	return fragments

# 清空牌库
func clear(context: Context = null) -> Array[Card]:
	var removed_cards = _cards.duplicate()
	_cards.clear()
	
	if context:
		trigger_empty_effects(context)
	
	EventBus.emit_signal("deck_cleared", self, removed_cards)
	return removed_cards

# 显示信息
func get_display_name() -> String:
	if label:
		return label
	return get_type_description()

func get_type_description() -> String:
	match deck_type:
		DeckType.MAIN:
			return "主牌库"
		DeckType.DISCARD:
			return "弃牌堆"
		DeckType.EXILE:
			return "流放区"
		DeckType.TEMPORARY:
			return "临时牌库"
		_:
			return "牌库"

func get_status_description() -> String:
	var status = str(_cards.size())
	if max_size >= 0:
		status += "/" + str(max_size)
	status += " 张牌"
	
	if _shuffle_count > 0:
		status += " (洗牌" + str(_shuffle_count) + "次)"
	
	return status

# 验证配置
func is_valid() -> bool:
	return min_size >= 0 and (max_size < 0 or max_size >= min_size)

# 调试信息
func get_debug_info() -> Dictionary:
	return {
		"label": label,
		"type": get_type_description(),
		"size": _cards.size(),
		"max_size": max_size,
		"min_size": min_size,
		"shuffle_count": _shuffle_count,
		"cards_drawn": _cards_drawn,
		"last_shuffle_turn": _last_shuffle_turn,
		"auto_shuffle": auto_shuffle,
		"allow_duplicates": allow_duplicates,
		"linked_discard": linked_discard_deck != null
	}