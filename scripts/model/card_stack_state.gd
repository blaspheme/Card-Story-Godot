## 卡牌堆叠状态
## 保存卡牌堆叠的运行时状态，不包含逻辑
extends RefCounted
class_name CardStackState

# 最大堆叠数量
const MAX_COUNT := 99

# 堆叠中的卡牌列表（底部到顶部）
var cards: Array[CardViz2D] = []

# 当前堆叠数量
var count: int:
	get:
		return cards.size()

# 是否正在拖拽整个堆叠
var stack_drag := false


## 初始化
func _init() -> void:
	cards = []


## 清空堆叠
func clear() -> void:
	cards.clear()


## 获取顶部卡牌
func top() -> CardViz2D:
	if cards.is_empty():
		return null
	return cards[-1]


## 检查是否可以继续堆叠
func can_push() -> bool:
	return count < MAX_COUNT


## 检查是否可以与另一个堆叠合并
func can_merge(other: CardStackState) -> bool:
	return count + other.count <= MAX_COUNT
