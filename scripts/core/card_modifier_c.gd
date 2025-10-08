# CardModifierC - CardModifier的计算执行版本
class_name CardModifierC
extends RefCounted

var op: CardModifier.CardOp
var target: Fragment
var fragment: Fragment
var level: int
var context: Context

# 执行修改器
func execute() -> void:
	if not target or not fragment or not context:
		print("错误: CardModifierC.execute() - 缺少必要参数")
		return
	
	match op:
		CardModifier.CardOp.FRAGMENT_ADDITIVE:
			execute_fragment_additive()
		CardModifier.CardOp.TRANSFORM:
			execute_transform()
		CardModifier.CardOp.DECAY:
			execute_decay()
		CardModifier.CardOp.SET_MEMORY:
			execute_set_memory()
		_:
			print("错误: 未知的CardOp类型: ", op)

func execute_fragment_additive() -> void:
	# 为匹配的卡牌添加/移除Fragment
	var target_cards = get_target_cards()
	
	for card_viz in target_cards:
		if card_viz and card_viz.card:
			if level > 0:
				# 添加Fragment
				if fragment not in card_viz.card.fragments:
					card_viz.card.fragments.append(fragment)
					print("为卡牌添加Fragment: ", card_viz.card.get_display_name(), " + ", fragment.get_display_name())
			else:
				# 移除Fragment
				if fragment in card_viz.card.fragments:
					card_viz.card.fragments.erase(fragment)
					print("从卡牌移除Fragment: ", card_viz.card.get_display_name(), " - ", fragment.get_display_name())
			
			# 更新卡牌显示
			if card_viz.has_method("update_display"):
				card_viz.update_display()

func execute_transform() -> void:
	# 变形卡牌
	if not fragment is Card:
		print("错误: 变形目标必须是Card类型")
		return
	
	var target_cards = get_target_cards()
	var target_card = fragment as Card
	
	for card_viz in target_cards:
		if card_viz and card_viz.card:
			var old_card = card_viz.card
			card_viz.card = target_card
			
			print("卡牌变形: ", old_card.get_display_name(), " -> ", target_card.get_display_name())
			
			# 触发变形目标的on_decay_into规则
			if target_card.on_decay_into:
				target_card.on_decay_into.execute(context)
			
			# 更新卡牌显示
			if card_viz.has_method("update_display"):
				card_viz.update_display()

func execute_decay() -> void:
	# 开始衰变过程
	if not fragment is Card:
		print("错误: 衰变目标必须是Card类型")
		return
	
	var target_cards = get_target_cards()
	var decay_target = fragment as Card
	
	for card_viz in target_cards:
		if card_viz and card_viz.card:
			# 设置衰变参数
			card_viz.card.decay_to = decay_target
			if card_viz.card.lifetime <= 0:
				card_viz.card.lifetime = 10.0  # 默认10秒衰变时间
			
			# 开始衰变
			card_viz.card.start_decay(context)

func execute_set_memory() -> void:
	# 设置卡牌记忆
	var target_cards = get_target_cards()
	
	for card_viz in target_cards:
		if card_viz:
			# 这里需要在CardViz中实现memory_fragment属性
			print("为卡牌设置记忆: ", card_viz.card.get_display_name(), " -> ", fragment.get_display_name())

func get_target_cards() -> Array:
	# 获取目标卡牌列表
	if not context or not context.scope:
		return []
	
	# 如果target为null，使用context.matches
	if not target:
		return context.matches
	
	# 否则查找包含target Fragment的卡牌
	if context.scope.has_method("get_cards_with_fragment"):
		return context.scope.get_cards_with_fragment(target)
	else:
		return []