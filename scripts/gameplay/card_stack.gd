## 卡牌堆叠组件
## 负责卡牌堆叠的 UI 显示和用户交互
## 作为 CardViz2D 的子节点存在
extends Control
class_name CardStack

# 堆叠状态
var state: CardStackState

# UI 节点引用
@onready var stack_counter: Control = $StackCounter
@onready var count_label: Label = $StackCounter/CountLabel

# 父卡牌引用
var parent_card: CardViz2D


func _ready() -> void:
	# 初始化状态
	state = CardStackState.new()
	
	# 获取父卡牌引用
	parent_card = get_parent() as CardViz2D
	assert(parent_card != null, "CardStack 必须是 CardViz2D 的子节点")
	
	# 初始更新显示
	_update_display()


## 推入一张卡牌到堆叠
func push(card: CardViz2D) -> bool:
	if not CardStackSystem.push(state, card):
		return false
	
	# 隐藏被堆叠的卡牌
	card.visible = false
	
	# 设置堆叠引用
	# card.stack = parent_card  # TODO: 需要在 CardViz2D 中添加 stack 属性
	
	_update_display()
	return true


## 从堆叠中弹出顶部卡牌
func pop() -> CardViz2D:
	var card = CardStackSystem.pop(state)
	
	if card:
		# 显示被弹出的卡牌
		card.visible = true
		
		# 清除堆叠引用
		# card.stack = null  # TODO: 需要在 CardViz2D 中添加 stack 属性
	
	_update_display()
	return card


## 获取顶部卡牌
func top() -> CardViz2D:
	return state.top()


## 合并另一个堆叠
func merge(other_stack: CardStack) -> bool:
	if not CardStackSystem.merge(state, other_stack.state):
		return false
	
	# 将另一个堆叠的父卡牌也推入
	if other_stack.parent_card:
		push(other_stack.parent_card)
	
	_update_display()
	other_stack._update_display()
	return true


## 获取堆叠数量
func get_count() -> int:
	return state.count


## 更新 UI 显示
func _update_display() -> void:
	var count = state.count
	
	# 只有堆叠数量 > 1 时才显示计数器
	stack_counter.visible = count > 1
	
	if count > 1:
		count_label.text = str(count)


## 处理拖拽开始
func _on_drag_started() -> void:
	# 如果堆叠数量 > 1，询问是拖整堆还是拖一张
	if state.count > 1:
		# TODO: 实现拖拽逻辑
		# 可以通过按住特定键（如 Shift）来决定是拖整堆还是拖一张
		pass
