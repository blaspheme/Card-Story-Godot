# CardModifier - 卡牌修改器
class_name CardModifier
extends Resource

# 操作类型枚举
enum CardOp {
	FRAGMENT_ADDITIVE = 0,	# 添加/移除Fragment到卡牌
	TRANSFORM = 10,			# 变形为其他卡牌
	DECAY = 100,			# 开始衰变过程
	SET_MEMORY = 140,		# 设置卡牌记忆
}

@export var op: CardOp						# 操作类型
@export var target: Fragment				# 目标Fragment（决定作用于哪些卡牌）
@export var fragment: Fragment				# 操作的Fragment或卡牌
@export var level: int						# 操作数量
@export var reference: Fragment				# 参考Fragment（用于动态计算level）

# 计算为执行版本
func evaluate(context: Context) -> CardModifierC:
	var computed_level = level
	
	# 如果设置了reference，根据其数量计算实际level
	if reference and context:
		var ref_count = context.count(reference, 0)
		computed_level = level * ref_count
	
	var result = CardModifierC.new()
	result.op = op
	result.target = target
	result.fragment = fragment
	result.level = computed_level
	result.context = context
	
	return result

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		CardOp.FRAGMENT_ADDITIVE:
			return "添加/移除Fragment"
		CardOp.TRANSFORM:
			return "变形"
		CardOp.DECAY:
			return "衰变"
		CardOp.SET_MEMORY:
			return "设置记忆"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return target != null and fragment != null