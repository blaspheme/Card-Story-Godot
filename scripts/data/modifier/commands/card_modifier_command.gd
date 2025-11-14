extends RefCounted
class_name CardModifierCommand

# 卡牌 modifier 的命令实现，承载已评估的数据并执行副作用
var op = GameEnums.CardOp.FragmentAdditive
var target_cards: Array[CardViz]
var what: Target
var level: int = 0

func execute(context: Context) -> void:
	if target_cards == null || target_cards == null:
		return

	# 清理可能为 null 的条目（参考原 C# 行为）
	for i in range(target_cards.size() - 1, -1, -1):
		if target_cards[i] == null:
			target_cards.remove_at(i)

	match op:
		GameEnums.CardOp.FragmentAdditive:
			for target_card in target_cards:
				target_card.frag_tree.adjust_target(what, level)
		GameEnums.CardOp.FragmentSet:
			for target_card in target_cards:
				var count = target_card.frag_tree.count_target(what)
				target_card.frag_tree.adjust_target(what, level - count)
		GameEnums.CardOp.Transform: # Transform
			if level > 0 and what != null:
				for target_card in target_cards:
					if what.fragment is CardData:
						target_card.transform_card(what.fragment)
						context.scope.adjust_card_viz(target_card, level - 1)
					elif what.cards != null:
						for card_viz in what.cards:
							target_card.transform_card(card_viz.card)
							context.scope.adjust_card_viz(target_card, level - 1)
		GameEnums.CardOp.Decay:
			for target_card in target_cards:
				if what != null and what.fragment is CardData:
					#target_card.decay(what.fragment, level)
					#TODO
					pass
				else:
					pass
					#target_card.Decay(target_card.card.decayTo, target_card.card.lifetime)
		GameEnums.CardOp.SetMemory: # SetMemory
			for target_card in target_cards:
				if what != null:
					if what.fragment is AspectData:
						target_card.frag_tree.memory_fragment = what.fragment
					elif what.cards != null and what.cards.size() > 0:
						target_card.frag_tree.memory_fragment = what.cards[0].frag_tree.memory_fragment
				else:
					target_card.frag_tree.memory_fragment = null
		GameEnums.CardOp.Spread: # Spread
			if what != null:
				for target_card in target_cards:
					if what.fragment is CardData:
						# TODO: 若需要 transform spread 的行为，可在此实现。当前保留空实现以保持与原逻辑一致性。
						pass
					elif what.cards != null:
						for card_viz in what.cards:
							if target_card.frag_tree.cards().filter(func(x: CardViz): return x.memory_equal(card_viz)).size() == 0:
								var _new_card_viz = target_card.frag_tree.adjust_card_viz(card_viz, 1)

func release() -> void:
	# 重置字段，准备回收；注意：不直接依赖全局 PoolManager，调用方可根据需要将对象放回池中
	op = GameEnums.CardOp.FragmentAdditive
	if target_cards != null:
		target_cards.clear()
	what = null
	level = 0
