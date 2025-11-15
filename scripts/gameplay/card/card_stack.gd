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
## 标记是否正在进行堆叠拖拽（区分从堆叠拖拽还是从单卡拖拽）
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
	var parent_label = _parent_card.card_data.label.get_text() if _parent_card and _parent_card.card_data and _parent_card.card_data.label else "未命名"
	print("[CardStack.update_ui] %s: _count=%d, 显示=%d, visible=%s" % [parent_label, _count, _count + 1, _count > 0])
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
	
	# 重父到当前堆节点（使用 reparent() 方法）
	card_viz.reparent(self)
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
	var old_count = _count
	_count += 1
	var parent_label = _parent_card.card_data.label.get_text() if _parent_card and _parent_card.card_data and _parent_card.card_data.label else "未命名"
	var card_label = card_viz.card_data.label.get_text() if card_viz.card_data and card_viz.card_data.label else "未命名"
	print("[CardStack.push] %s: _count %d -> %d (push %s)" % [parent_label, old_count, _count, card_label])
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
	var target_pos := _parent_card.global_position
	top_card.reparent(target_parent)
	top_card.global_position = target_pos
	
	# 更新计数与堆引用
	var old_count = _count
	_count -= 1
	var parent_label = _parent_card.card_data.label.get_text() if _parent_card and _parent_card.card_data and _parent_card.card_data.label else "未命名"
	var card_label = top_card.card_data.label.get_text() if top_card.card_data and top_card.card_data.label else "未命名"
	print("[CardStack.pop] %s: _count %d -> %d (pop %s)" % [parent_label, old_count, _count, card_label])
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
	# 不能合并自己到自己
	if other == self:
		print("无法合并：不能合并自己到自己")
		return false
	
	# 合并逻辑：将 other 的所有卡片（包括父卡）逐个 push 到当前堆
	# 不直接操作节点关系，而是通过 pop 和 push 来实现
	
	if _count + other._count + 1 > MAX_COUNT:  # +1 是 other 的父卡
		print("无法合并：超过最大数量限制")
		return false
	
	# 检查是否可以与另一个堆的父卡合并
	if not _can_stack_with(other._parent_card):
		print("无法合并：卡片类型不同")
		return false
	
	print("开始合并堆叠：当前 %d 张 + 来源 %d 张" % [_count + 1, other._count + 1])
	
	# 收集所有要转移的卡片（包括堆叠中的和父卡）
	var cards_to_transfer: Array[CardViz] = []
	
	# 先弹出所有堆叠中的卡片
	while other._count > 0:
		var card := other.pop()
		if card:
			cards_to_transfer.append(card)
	
	# 添加 other 的父卡
	if other._parent_card and other._parent_card != _parent_card:
		cards_to_transfer.append(other._parent_card)
	
	# 将所有卡片 push 到当前堆叠
	for card in cards_to_transfer:
		if not push(card):
			print("合并失败：无法 push 卡片 %s" % card.name)
			return false
	
	print("合并完成：总共 %d 张卡片" % (_count + 1))
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
	
	# 弹出不匹配的卡版
	for card in cards_to_remove:
		# 设置为可见
		card.visible = true
		if card.has_method("set_process"):
			card.set_process(true)
			card.set_physics_process(true)
		
		# 移动到父卡的父节点（使用 reparent() 方法）
		var target_parent = _parent_card.get_parent()
		var target_pos = _parent_card.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		card.reparent(target_parent)
		card.global_position = target_pos
		
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
	
	print("CardStack: 处理堆叠中卡版的衰变: %s" % decaying_card.card_data.label)
	
	# 设置为可见
	decaying_card.visible = true
	if decaying_card.has_method("set_process"):
		decaying_card.set_process(true)
		decaying_card.set_physics_process(true)
	
	# 移动到父卡的父节点（使用 reparent() 方法）
	var target_parent = _parent_card.get_parent()
	var target_pos = _parent_card.global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	decaying_card.reparent(target_parent)
	decaying_card.global_position = target_pos
	
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
				var parent_label = _parent_card.card_data.label.get_text() if _parent_card.card_data and _parent_card.card_data.label else "未命名"
				print("[StackCounter] 开始整堆拖拽 - 父卡: %s, stack_drag: %s, count: %d" % [parent_label, stack_drag, get_count()])
				# 开始整堆拖拽
				_parent_card.start_drag_directly()
				get_viewport().set_input_as_handled()

## 鼠标进入堆叠区域（标记为堆叠拖拽模式）
func _on_area_2d_mouse_entered() -> void:
	var parent_label = _parent_card.card_data.label.get_text() if _parent_card and _parent_card.card_data and _parent_card.card_data.label else "未命名"
	print("[StackCounter] 鼠标进入 - 父卡: %s, 设置 stack_drag = true" % parent_label)
	stack_drag = true

## 鼠标离开堆叠区域
## 注意：不在这里重置 stack_drag，因为拖拽开始时鼠标会立即离开区域
## stack_drag 会在拖拽结束后的 _on_drag_ended 中重置
func _on_area_2d_mouse_exited() -> void:
	pass
