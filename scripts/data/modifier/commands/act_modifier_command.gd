extends RefCounted
class_name ActModifierCommand

# ActModifier
var op = GameEnums.ActOp.Adjust
var target: Target
var level: int = 0
var all: bool = false

func execute(context: Context) -> void:
	if target == null:
		return

	match op:
		GameEnums.ActOp.Adjust:
			if target.cards != null:
				for card_viz in target.cards:
					var count = context.scope.adjust_card_viz(card_viz, level)
					if level < 0 and count < 0:
						context.destroy(card_viz)
			elif target.fragment != null and target.fragment is CardData and level < 0:
				var cards = context.scope.find_all_by_card(target.fragment)
				var count = context.scope.adjust_card(target.fragment, level)
				if count < 0:
					var to_destroy = -count
					for i in range(min(to_destroy, cards.size())):
						context.destroy(cards[i])
			else:
				context.scope.adjust_fragment(target.fragment, level)
		GameEnums.ActOp.Grab:
			var target_cards_y = context.resolve_target_cards(target, context.scope)
			if target_cards_y != null:
				var target_cards :Array[CardViz] = []
				for card_viz in target_cards_y:
					var target_card = card_viz.stack if card_viz.stack != null else card_viz
					#TODO
					if target_card.is_visible_in_tree():
						target_cards.append(target_card)
				var take = target_cards.size() if all else level
				for i in range(min(take, target_cards.size())):
					context.act_logic.token_viz.Grab(target_cards[i])
		GameEnums.ActOp.Expulse:
			var target_cards_y = context.resolve_target_cards(target, context.scope)
			if target_cards_y != null:
				for card_viz in target_cards_y:
					card_viz.free = true
					card_viz.interactive = true
					card_viz.Show()
					card_viz.transform.position = card_viz.Position(true)
		GameEnums.ActOp.SetMemory:
			if target.fragment != null:
				context.scope.memory_fragment = target.fragment
			elif target.cards != null and target.cards.size() > 0:
				context.scope.memory_fragment = target.cards[0].frag_tree.memory_fragment
			else:
				context.scope.memory_fragment = null
		GameEnums.ActOp.RunTriggers:
			context.act_logic.inject_triggers(target)

func release() -> void:
	op = GameEnums.ActOp.Adjust
	target = null
	level = 0
	all = false
