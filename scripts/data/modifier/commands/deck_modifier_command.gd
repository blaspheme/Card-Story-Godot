extends RefCounted
class_name DeckModifierCommand

# 牌堆相关 modifier 的命令实现。
# 尽量贴合 Modifier.cs 的 Execute 行为，依赖上下文契约（context.scope, deck 对象等）。

var op = GameEnums.DeckOp.Draw
var deck = null
var target = null

func setup(...varargs: Array) -> void:
	# 支持签名：setup(op, deck, target)
	var _op = varargs[0] if varargs.size() > 0 else null
	var _deck = varargs[1] if varargs.size() > 1 else null
	var _target = varargs[2] if varargs.size() > 2 else null
	op = _op as GameEnums.DeckOp
	deck = _deck
	target = _target

func execute(context) -> void:
	assert(context != null)
	match op:
		GameEnums.DeckOp.Draw:
			# 简化实现：尝试多次从 deck.Draw() 获取可用 fragment 并创建卡牌
			var max_tries = 3
			var frag = null
			while max_tries > 0:
				frag = deck.Draw()
				max_tries -= 1
				# 这里假设存在 GameManager.AllowedToCreate 或类似逻辑；如果不存在，直接使用 frag
				break

			_create_card(context, deck, frag)
		GameEnums.DeckOp.DrawNext:
			if target != null and target.fragment != null:
				_create_card(context, deck, deck.DrawOffset(target.fragment, 1))
		GameEnums.DeckOp.DrawPrevious:
			if target != null and target.fragment != null:
				_create_card(context, deck, deck.DrawOffset(target.fragment, -1))
		GameEnums.DeckOp.Add:
			if target != null and target.fragment != null:
				deck.Add(target.fragment)
			elif target != null and target.cards != null:
				for card_viz in target.cards:
					deck.Add(card_viz.card)
		GameEnums.DeckOp.AddFront:
			if target != null and target.fragment != null:
				deck.AddFront(target.fragment)
			elif target != null and target.cards != null:
				for card_viz in target.cards:
					deck.AddFront(card_viz.card)
		GameEnums.DeckOp.ForwardShift:
			if target != null:
				var target_cards = context.ResolveTargetCards(target, context.scope)
				for card_viz in target_cards:
					_shift_card(card_viz, deck.DrawOffset(card_viz.card, 1))

func _create_card(_context, _deck, drawn_frag) -> void:
	if _context == null or drawn_frag == null:
		return
	# 按项目契约：如果 fragment 是 Card 类型，_context.scope.Add(card) 可用
	if drawn_frag is Object:
		var card = drawn_frag
		var new_card_viz = _context.scope.add_card(card)
		new_card_viz.ShowBack()

		if _deck.tag_on != null:
			for frag in _deck.tag_on:
				if frag != null:
					new_card_viz.frag_tree.add_fragment(frag)
		if _deck.memory_fragment != null:
			new_card_viz.frag_tree.memory_fragment = _deck.memory_fragment

func _shift_card(_card_viz, drawn_frag) -> void:
	if _card_viz != null and drawn_frag is Object:
		_card_viz.Transform(drawn_frag)

func release() -> void:
	op = GameEnums.DeckOp.Draw
	deck = null
	target = null
