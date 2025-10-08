# DeckModifier - 牌库修改器
class_name DeckModifier
extends Resource

# 牌库操作类型枚举
enum DeckOp {
	DRAW = 0,			# 抽牌
	DRAW_NEXT = 10,		# 抽取下一张卡牌
	DRAW_PREVIOUS = 20,	# 抽取上一张卡牌
	ADD = 50,			# 添加卡牌到牌库
	FORWARD_SHIFT = 100	# 向前移动
}

@export var op: DeckOp							# 操作类型
@export var deck: Deck							# 目标牌库
@export var deck_from: Fragment					# 牌库来源Fragment
@export var fragment: Fragment					# 操作的Fragment

# 执行牌库修改器
func execute(context: Context) -> void:
	if not context or not context.scope:
		return
	
	var resolved_deck = deck
	if deck == null and deck_from != null:
		var frag = context.resolve_fragment(deck_from)
		if frag == GameManager.instance.matched_cards and context.matches != null and context.matches.size() > 0:
			frag = context.matches[0].card
		resolved_deck = frag.deck
	
	if not resolved_deck:
		return
	
	var target_obj = context.resolve_target(fragment)
	
	if op == DeckOp.DRAW:
		_create_card(context, resolved_deck, resolved_deck.draw())
	elif target_obj != null:
		if target_obj.fragment != null:
			match op:
				DeckOp.DRAW_NEXT:
					_create_card(context, resolved_deck, resolved_deck.draw_offset(target_obj.fragment, 1))
				DeckOp.DRAW_PREVIOUS:
					_create_card(context, resolved_deck, resolved_deck.draw_offset(target_obj.fragment, -1))
				DeckOp.ADD:
					resolved_deck.add(target_obj.fragment)
				DeckOp.FORWARD_SHIFT:
					var target_cards = context.resolve_target_cards(target_obj, context.scope)
					for card_viz in target_cards:
						_shift_card(card_viz, resolved_deck.draw_offset(card_viz.card, 1))
		elif target_obj.cards != null:
			for card_viz in target_obj.cards:
				match op:
					DeckOp.DRAW_NEXT:
						_create_card(context, resolved_deck, resolved_deck.draw_offset(card_viz.card, 1))
					DeckOp.DRAW_PREVIOUS:
						_create_card(context, resolved_deck, resolved_deck.draw_offset(card_viz.card, -1))
					DeckOp.ADD:
						resolved_deck.add(card_viz.card)
					DeckOp.FORWARD_SHIFT:
						_shift_card(card_viz, resolved_deck.draw_offset(card_viz.card, 1))

# 创建卡牌的私有方法
func _create_card(context: Context, deck_obj: Deck, drawn_frag: Fragment) -> void:
	if context and drawn_frag is Card:
		var new_card_viz = context.scope.add(drawn_frag as Card)
		new_card_viz.show_back()
		
		for frag in deck_obj.tag_on:
			if frag != null:
				new_card_viz.frag_tree.add(frag)
		
		if deck_obj.memory_fragment != null:
			new_card_viz.frag_tree.memory_fragment = deck_obj.memory_fragment

# 移动卡牌的私有方法
func _shift_card(card_viz: CardViz, drawn_frag: Fragment) -> void:
	if card_viz and drawn_frag is Card:
		card_viz.transform(drawn_frag as Card)

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		DeckOp.DRAW_CARDS:
			return "抽牌"
		DeckOp.SHUFFLE_DECK:
			return "洗牌"
		DeckOp.ADD_TO_DECK:
			return "添加到牌库"
		DeckOp.REMOVE_FROM_DECK:
			return "从牌库移除"
		DeckOp.SET_DECK_SIZE:
			return "设置牌库大小"
		DeckOp.PEEK_DECK:
			return "查看牌库"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return level > 0 or op == DeckOp.SHUFFLE_DECK