# CardStack - 卡牌堆叠组件
class_name CardStack
extends Control

# 是否支持堆叠拖拽
@export var stack_drag: bool = false

# UI 组件引用
@export var text_label: Label
@export var stack_counter: Control

# 堆叠数量
var count: int = 0:
	set(value):
		_set_count(value)

# 父卡牌引用
var parent_card: CardViz

# 最大堆叠数量
const MAX_COUNT = 99

signal stack_drag_started(card_viz: CardViz)

func _ready():
	parent_card = get_parent() as CardViz
	_set_count(count)

# 处理拖拽开始
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if stack_drag and parent_card:
				stack_drag_started.emit(parent_card)
				# 开始拖拽父卡牌
				if parent_card.has_method("start_drag"):
					parent_card.start_drag()

# 推入卡牌到堆叠
func push(card_viz: CardViz) -> bool:
	if count < MAX_COUNT and card_viz:
		# 将卡牌设为当前节点的子节点
		card_viz.reparent(self)
		card_viz.position = Vector2.ZERO
		
		# 隐藏卡牌（这会停止衰变计时器，适用于不允许衰变卡牌堆叠的设计）
		card_viz.hide()
		
		# 设置堆叠引用
		if card_viz.has_method("set_stack"):
			card_viz.set_stack(parent_card)
		
		count += 1
		return true
	
	return false

# 弹出顶部卡牌
func pop() -> CardViz:
	var card_viz = get_top_card()
	if card_viz:
		# 显示卡牌
		card_viz.show()
		
		# 清除堆叠引用
		if card_viz.has_method("set_stack"):
			card_viz.set_stack(null)
		
		count -= 1
	
	return card_viz

# 获取顶部卡牌（不弹出）
func get_top_card() -> CardViz:
	# 查找隐藏的CardViz子节点
	for child in get_children():
		if child is CardViz and not child.visible:
			return child
	return null

# 合并另一个堆叠
func merge(other_stack: CardStack) -> bool:
	if count + other_stack.count <= MAX_COUNT:
		# 弹出所有卡牌并推入当前堆叠
		var card_viz = other_stack.pop()
		while card_viz:
			push(card_viz)
			card_viz = other_stack.pop()
		
		# 将其他堆叠的父卡牌也推入
		if other_stack.parent_card:
			push(other_stack.parent_card)
		
		return true
	
	return false

# 获取堆叠中的所有卡牌
func get_all_cards() -> Array[CardViz]:
	var cards: Array[CardViz] = []
	for child in get_children():
		if child is CardViz:
			cards.append(child)
	return cards

# 检查是否可以堆叠特定卡牌
func can_stack(card_viz: CardViz) -> bool:
	if not parent_card or not card_viz:
		return false
	
	# 检查卡牌是否支持堆叠
	if parent_card.has_method("can_stack_with"):
		return parent_card.can_stack_with(card_viz)
	
	return false

# 设置堆叠数量（私有方法）
func _set_count(new_count: int):
	count = new_count
	
	# 更新UI显示
	if text_label:
		text_label.text = str(count)
	
	if stack_counter:
		stack_counter.visible = count > 1

# 保存堆叠状态
func save() -> Dictionary:
	var save_data = {
		"count": count,
		"cards": []
	}
	
	var cards = get_all_cards()
	for card in cards:
		if card.has_method("save"):
			save_data.cards.append(card.save())
	
	return save_data

# 加载堆叠状态
func load_from_dict(save_data: Dictionary):
	if save_data.has("count"):
		count = save_data.count
	
	# 这里需要配合GameManager或SaveManager来重建卡牌
	# 具体实现取决于保存系统的设计

# 清空堆叠
func clear():
	var cards = get_all_cards()
	for card in cards:
		card.queue_free()
	count = 0

# 获取堆叠信息（调试用）
func get_stack_info() -> String:
	return "CardStack: %d/%d 张卡牌" % [count, MAX_COUNT]

# 打印堆叠内容（调试用）
func print_stack_contents():
	print("=== 卡牌堆叠内容 ===")
	print(get_stack_info())
	var cards = get_all_cards()
	for i in range(cards.size()):
		var card = cards[i]
		print("  [%d] %s (visible: %s)" % [
			i, 
			card.get_card_name() if card.has_method("get_card_name") else "未知卡牌",
			card.visible
		])
	print("=====================")