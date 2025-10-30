extends "res://scripts/system/core/commands/modifier_command_base.gd"
class_name CardModifierCommand

# 卡牌 modifier 的命令实现，承载已评估的数据并执行副作用。
# 遵循 AGENTS.md 的静态契约：不使用动态容错(has_method/has_node 等)，在需要的前置条件处使用 assert。

var op = GameEnums.CardOp.FragmentAdditive
var target_cards: Array = []
var what = null
var level: int = 0

func setup(...varargs: Array) -> void:
	"""初始化命令数据。调用者负责传入已评估（Evaluate）后的数据。
	支持多种调用签名：setup(op, target_cards, what, level) 或者传入一个结构体/字典。
	"""
	var _op = varargs[0] if varargs.size() > 0 else null
	var _target_cards = varargs[1] if varargs.size() > 1 else []
	var _what = varargs[2] if varargs.size() > 2 else null
	var _level = varargs[3] if varargs.size() > 3 else 0
	op = _op as GameEnums.CardOp
	target_cards = _target_cards
	what = _what
	level = _level

func execute(context) -> void:
	# 静态契约：需要有 context 且 context.scope 可用
	assert(context != null and context.scope != null)

	if target_cards == null:
		return

	# 清理可能为 null 的条目（参考原 C# 行为）
	for i in range(target_cards.size() - 1, -1, -1):
		if target_cards[i] == null:
			target_cards.remove_at(i)

	match op:
		GameEnums.CardOp.FragmentAdditive: # FragmentAdditive
			for target_card in target_cards:
				# 假定 target_card.frag_tree.Adjust 可用并按契约工作
				target_card.frag_tree.Adjust(what, level)
		GameEnums.CardOp.FragmentSet: # FragmentSet
			for target_card in target_cards:
				var count = target_card.frag_tree.Count(what)
				target_card.frag_tree.Adjust(what, level - count)
		GameEnums.CardOp.Transform: # Transform
			if level > 0 and what != null:
				for target_card in target_cards:
					if typeof(what) == TYPE_OBJECT and "fragment" in what and what.fragment != null:
						# 如果 what.fragment 是 Card 类型（按项目契约），调用 Transform
						target_card.Transform(what.fragment)
						context.scope.Adjust(target_card, level - 1)
					elif typeof(what) == TYPE_OBJECT and "cards" in what and what.cards != null:
						for card_viz in what.cards:
							target_card.Transform(card_viz.card)
							context.scope.Adjust(target_card, level - 1)
		GameEnums.CardOp.Decay: # Decay
			for target_card in target_cards:
				if what != null and typeof(what) == TYPE_OBJECT and "fragment" in what and what.fragment != null:
					target_card.Decay(what.fragment, level)
				else:
					target_card.Decay(target_card.card.decayTo, target_card.card.lifetime)
		GameEnums.CardOp.SetMemory: # SetMemory
			for target_card in target_cards:
				if what != null:
					if typeof(what.fragment) != TYPE_NIL and what.fragment is Object:
						target_card.frag_tree.memory_fragment = what.fragment
					elif what.cards != null and what.cards.size() > 0:
						target_card.frag_tree.memory_fragment = what.cards[0].frag_tree.memory_fragment
				else:
					target_card.frag_tree.memory_fragment = null
		GameEnums.CardOp.Spread: # Spread
			if what != null:
				for target_card in target_cards:
					if typeof(what.fragment) != TYPE_NIL and what.fragment is Object:
						# TODO: 若需要 transform spread 的行为，可在此实现。当前保留空实现以保持与原逻辑一致性。
						pass
					elif what.cards != null:
						for card_viz in what.cards:
							if target_card.frag_tree.cards.find_all(func(x): return x.MemoryEqual(card_viz)).size() == 0:
								var _new_card_viz = target_card.frag_tree.Adjust(card_viz, 1)

func release() -> void:
	# 重置字段，准备回收；注意：不直接依赖全局 PoolManager，调用方可根据需要将对象放回池中
	op = GameEnums.CardOp.FragmentAdditive
	if target_cards != null:
		target_cards.clear()
	what = null
	level = 0
