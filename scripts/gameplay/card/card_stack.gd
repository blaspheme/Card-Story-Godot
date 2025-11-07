# 卡牌堆叠组件，负责卡牌堆叠的 UI 显示和用户交互， 作为 CardViz2D 的子节点存在
extends Node2D
class_name CardStack

# ===============================
# SceneTree引用
# ===============================
## 堆叠计数器的 Node（数量>1时显示）
@onready var stack_counter := self
## 显示堆叠数量的文本组件
@onready var count_label: Label = $Label

# ===============================
# 属性
# ===============================
# 标记是否正在进行堆叠拖拽（区分从堆叠拖拽还是从单卡拖拽）
var stack_drag : bool = false
## 当前堆叠中的卡牌数量
var _count : int = 0
## 持有此 CardStack 的父 CardViz
var _parent_card: CardViz
## 堆叠最大数量限制（99张）
const MAX_COUNT : int = 98

# ===============================
# 方法
# ===============================
## 更新UI展示
func update_ui() -> void:
	count_label.text = str(_count + 1)
	if _count > 0:
		self.visible = true
	else:
		self.visible = false

## 将卡片压入堆栈（只能堆叠相同类型的卡）
func push(card_viz: CardViz) -> bool:
	if _count >= MAX_COUNT:
		return false
	
	# 检查卡片类型是否相同
	if not _can_stack_with(card_viz):
		print("无法堆叠：卡片类型不同")
		return false
	
	# 重父到当前堆节点
	card_viz.get_parent().remove_child(card_viz)
	add_child(card_viz)
	# 放到本地原点并隐藏（表示被堆起来）
	card_viz.position = Vector2.ZERO
	if card_viz.has_method("set_process") :
		# 停止处理（若卡片脚本使用 process）
		card_viz.set_process(false)
		card_viz.set_physics_process(false)
	card_viz.visible = false
	
	# 保持衰变计时器运行（堆叠中的卡牌仍然可以独立衰变）
	# 衰变计时器会继续运行，当衰变完成时会自动弹出
	# 更新计数
	_count += 1
	# 运行时记录所属堆栈的父卡引用（CardViz 的字段 stack）
	card_viz.stack = _parent_card
	update_ui()
	return true


## 从堆栈顶部弹出一张卡
func pop() -> CardViz:
	var top_card := _top()
	if top_card == null:
		return null
	# 将卡设为可见并恢复处理
	top_card.visible = true
	if top_card.has_method("set_process"):
		top_card.set_process(true)
		top_card.set_physics_process(true)
	# 从堆栈移除并把父级设为场景中的原位（此处将其父设为父卡的父节点，通常是 Table 节点）
	var target_parent := _parent_card.get_parent()
	remove_child(top_card)
	target_parent.add_child(top_card)
	# 将卡放到父卡所在位置（局部坐标）
	top_card.global_position = _parent_card.global_position
	# 更新计数与堆引用
	_count -= 1
	top_card.stack = null
	update_ui()
	return top_card


## 获取堆栈顶部卡（不弹出）
func _top() -> CardViz:
	# 若没有子节点返回 null
	for i in range(get_child_count() - 1, -1, -1):
		var c := get_child(i)
		# 只返回类型为 CardViz 的节点
		if c is CardViz:
			return c as CardViz
	return null

## 检查是否可以与指定卡片堆叠（卡片类型必须相同）
func _can_stack_with(card_viz: CardViz) -> bool:
	if _parent_card == null or card_viz == null:
		return false
	if _parent_card.card_data == null or card_viz.card_data == null:
		return false
	# 卡片类型必须相同才能堆叠
	return _parent_card.card_data == card_viz.card_data


## 合并另一个 CardStack 到当前堆（只能合并相同类型的卡）
func merge(other: CardStack) -> bool:
	if _count + other._count >= MAX_COUNT:
		return false
	
	# 检查是否可以与另一个堆的父卡合并
	if not _can_stack_with(other._parent_card):
		print("无法合并：卡片类型不同")
		return false
	
	# 逐个弹出并压入
	while true:
		var card := other.pop()
		if card == null:
			break
		push(card)
	# 将其他堆的 parent 也入栈（如果合适）
	if other._parent_card != null:
		push(other._parent_card)
	update_ui()
	return true


# ===============================
# 接口方法
# ===============================

## 获取堆叠数量（只读属性）
func get_count() -> int:
	return _count

## 检查堆叠是否为空
func is_empty() -> bool:
	return _count == 0

## 检查是否可以合并另一个堆叠（数量和类型都必须满足）
func can_merge(other: CardStack) -> bool:
	if _count + other._count > MAX_COUNT:
		return false
	return _can_stack_with(other._parent_card)

## 获取堆叠中所有卡牌（不弹出，用于遍历）
func get_all_stacked_cards() -> Array[CardViz]:
	var cards: Array[CardViz] = []
	for i in range(get_child_count()):
		var child = get_child(i)
		if child is CardViz:
			cards.append(child as CardViz)
	return cards

## 当父卡类型改变时，弹出所有不匹配的卡牌
func eject_mismatched_cards() -> Array[CardViz]:
	if _parent_card == null or _parent_card.card_data == null:
		return []
	
	print("CardStack: 检查堆叠中不匹配的卡牌，父卡类型: %s" % _parent_card.card_data.label)
	
	var ejected_cards: Array[CardViz] = []
	var cards_to_remove: Array[CardViz] = []
	
	# 收集所有需要弹出的卡牌（类型与父卡不匹配的）
	var stacked_cards = get_all_stacked_cards()
	for card in stacked_cards:
		if card.card_data != _parent_card.card_data:
			cards_to_remove.append(card)
			print("发现不匹配的卡牌: %s (父卡: %s)" % [card.card_data.label, _parent_card.card_data.label])
	
	# 弹出不匹配的卡牌
	for card in cards_to_remove:
		# 从堆叠中移除
		remove_child(card)
		card.visible = true
		if card.has_method("set_process"):
			card.set_process(true)
			card.set_physics_process(true)
		
		# 移动到父卡的父节点
		var target_parent = _parent_card.get_parent()
		target_parent.add_child(card)
		card.global_position = _parent_card.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		
		# 清除堆叠引用
		card.stack = null
		_count -= 1
		
		ejected_cards.append(card)
	
	# 更新UI
	update_ui()
	
	print("弹出了 %d 张不匹配的卡牌，剩余堆叠数量: %d" % [ejected_cards.size(), _count])
	return ejected_cards

## 处理堆叠中卡牌的衰变（弹出特定卡牌进行转换）
func handle_stacked_card_decay(decaying_card: CardViz) -> bool:
	# 检查这张卡是否在当前堆叠中
	var stacked_cards = get_all_stacked_cards()
	if not stacked_cards.has(decaying_card):
		return false
	
	print("CardStack: 处理堆叠中卡牌的衰变: %s" % decaying_card.card_data.label)
	
	# 弹出这张卡牌
	remove_child(decaying_card)
	decaying_card.visible = true
	if decaying_card.has_method("set_process"):
		decaying_card.set_process(true)
		decaying_card.set_physics_process(true)
	
	# 移动到父卡的父节点
	var target_parent = _parent_card.get_parent()
	target_parent.add_child(decaying_card)
	decaying_card.global_position = _parent_card.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	
	# 清除堆叠引用
	decaying_card.stack = null
	_count -= 1
	
	# 更新UI
	update_ui()
	
	print("成功弹出衰变卡牌，剩余堆叠数量: %d" % _count)
	return true

# ===============================
# 信号机制
# ===============================

## 处理堆叠区域的输入事件（整堆拖拽）
@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if stack_drag and _parent_card != null:
				# 开始整堆拖拽
				_parent_card.start_drag_directly()
				get_viewport().set_input_as_handled()

## 鼠标进入堆叠区域（标记为堆叠拖拽模式）
func _on_area_2d_mouse_entered() -> void:
	stack_drag = true

## 鼠标离开堆叠区域（取消堆叠拖拽模式）
func _on_area_2d_mouse_exited() -> void:
	stack_drag = false
