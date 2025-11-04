## 卡牌堆叠系统
## 处理卡牌堆叠的核心逻辑，不依赖具体 UI 节点
extends RefCounted
class_name CardStackSystem


## 将卡牌推入堆叠
## 返回是否成功
static func push(state: CardStackState, card: CardViz2D) -> bool:
	if not state.can_push():
		return false
	
	state.cards.append(card)
	return true


## 从堆叠中弹出顶部卡牌
## 返回弹出的卡牌，如果堆叠为空则返回 null
static func pop(state: CardStackState) -> CardViz2D:
	if state.cards.is_empty():
		return null
	
	var card = state.cards.pop_back()
	return card


## 合并两个堆叠
## 将 source 堆叠中的所有卡牌转移到 target 堆叠
## 返回是否成功
static func merge(target: CardStackState, source: CardStackState) -> bool:
	if not target.can_merge(source):
		return false
	
	# 将源堆叠的所有卡牌转移到目标堆叠
	while not source.cards.is_empty():
		var card = pop(source)
		if card:
			push(target, card)
	
	return true


## 检查两张卡牌是否可以堆叠
## 根据游戏规则判断（相同卡牌、都面朝上、没有衰减等）
static func can_stack(card1: CardViz2D, card2: CardViz2D) -> bool:
	if not card1 or not card2:
		return false
	
	if not card1.card_data or not card2.card_data:
		return false
	
	# TODO: 根据实际游戏规则完善判断条件
	# 目前简单判断：相同的卡牌数据
	return card1.card_data == card2.card_data
