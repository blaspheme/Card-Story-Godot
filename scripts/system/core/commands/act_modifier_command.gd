extends RefCounted
class_name ActModifierCommand

# Act modifier 命令实现。
# 按 AGENTS.md 原则：使用断言保证前置条件，避免动态容错。所有副作用直接调用目标对象的方法，缺少方法时应当抛出错误以便快速发现问题。

var op = GameEnums.ActOp.Adjust
var target = null
var level: int = 0
var all: bool = false

func setup(...varargs: Array) -> void:
	# 支持签名：setup(op, target, level, all)
	var _op = varargs[0] if varargs.size() > 0 else null
	var _target = varargs[1] if varargs.size() > 1 else null
	var _level = varargs[2] if varargs.size() > 2 else 0
	var _all = varargs[3] if varargs.size() > 3 else false
	op = _op as GameEnums.ActOp
	target = _target
	level = _level
	all = _all

func execute(context) -> void:
	assert(context != null and context.scope != null)
	if target == null:
		return

	match op:
		GameEnums.ActOp.Adjust:
			if typeof(target) == TYPE_OBJECT and "cards" in target and target.cards != null:
				for card_viz in target.cards:
					var count = context.scope.Adjust(card_viz, level)
					if level < 0 and count < 0:
						context.Destroy(card_viz)
			elif typeof(target) == TYPE_OBJECT and "fragment" in target and target.fragment != null and level < 0:
				var cards = context.scope.FindAll(target.fragment)
				var count2 = context.scope.Adjust(target.fragment, level)
				if count2 < 0:
					var to_destroy = -count2
					for i in range(min(to_destroy, cards.size())):
						context.Destroy(cards[i])
			else:
				context.scope.Adjust(target.fragment, level)
		GameEnums.ActOp.Grab:
			var target_cards_y = context.ResolveTargetCards(target, context.scope)
			if target_cards_y != null:
				var target_cards = []
				for card_viz in target_cards_y:
					var target_card = card_viz.stack if card_viz.stack != null else card_viz
					if target_card.game_object.active:
						target_cards.append(target_card)

				var take = target_cards.size() if all else level
				for i in range(min(take, target_cards.size())):
					context.act_logic.token_viz.Grab(target_cards[i])
		GameEnums.ActOp.Expulse:
			var target_cards_y = context.ResolveTargetCards(target, context.scope)
			if target_cards_y != null:
				for card_viz in target_cards_y:
					card_viz.free = true
					card_viz.interactive = true
					card_viz.Show()
					card_viz.transform.position = card_viz.Position(true)
					context.act_logic.table.ReturnToTable(card_viz)
		GameEnums.ActOp.SetMemory:
			if target.fragment != null:
				context.scope.memory_fragment = target.fragment
			elif target.cards != null and target.cards.size() > 0:
				context.scope.memory_fragment = target.cards[0].frag_tree.memory_fragment
			else:
				context.scope.memory_fragment = null
		GameEnums.ActOp.RunTriggers:
			context.act_logic.InjectTriggers(target)

func release() -> void:
	op = GameEnums.ActOp.Adjust
	target = null
	level = 0
	all = false
