extends Resource
class_name ActModifier

@export var op: GameEnums.ActOp
@export var fragment: FragmentData
@export var level: int = 0
@export var ref_loc: GameEnums.ReqLoc
@export var ref_fragment: FragmentData

func evaluate(context) -> ActModifierCommand:
	# 返回格式等同于 C# 的 ActModifierC：{ "op", "target", "level", "all" }
	var result = ActModifierCommand.new()
	
	if context != null and context.scope != null:
		result.op = op
		result.target = context.resolve_target(fragment)
		var frag = context.resolve_fragment(reference)
		if frag != null:
			result.level = level * TestData.get_count(context, ref_loc, frag)
		else:
			result.level = level
		# only for Grab: all 当 level == 0
		result.all = (level == 0)
	return result
