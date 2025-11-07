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
