extends Resource
class_name DeckModifier

@export var op: GameEnums.DeckOp
@export var deck: DeckData
@export var deck_from: FragmentData
@export var fragment: FragmentData

# 返回运行时已解析的 DeckModifierC
func evaluate(context: Context) -> DeckModifierCommand:
	var result = DeckModifierCommand.new()
	if context != null:
		result.op = op
		# 解析 deck（如果 deck 为空且 deck_from 有值，通过 context.resolve_fragment 获取）
		if deck == null and deck_from != null:
			var frag = context.resolve_fragment(deck_from)
			if frag == Manager.GM.matched_card and context.matches != null and context.matches.size() > 0:
				frag = context.matches[0].card_data
			result.deck = frag.deck
		else:
			result.deck = deck
	result.target = context.resolve_target(fragment)

	return result
