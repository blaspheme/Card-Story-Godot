extends Resource
class_name CardModifier

@export var op: GameEnums.CardOp
@export var target: FragmentData
@export var fragment: FragmentData
@export var level: int = 0
@export var ref_fragment: FragmentData

func evaluate(context: Context) -> CardModifierCommand:
	var result = CardModifierCommand.new()
	if context != null and context.scope != null:
		result.op = op
		var tar = context.resolve_target(target)
		result.target_cards = context.resolve_target_cards(tar, context.scope)
		result.what = context.resolve_target(fragment)
		result.level = context.count(ref_fragment, level);
		
	return result
