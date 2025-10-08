# ActModifier - 游戏状态修改器
class_name ActModifier
extends Resource

# 操作类型枚举
enum ActOp {
	ADJUST = 0,			# 调整Fragment/卡牌数量
	GRAB = 20,			# 抓取/移动卡牌
	SET_MEMORY = 40,	# 设置记忆Fragment
	RUN_TRIGGERS = 50	# 触发Fragment的规则
}

@export var op: ActOp							# 操作类型
@export var fragment: Fragment					# 目标Fragment
@export var level: int							# 操作数值或乘数
@export var ref_loc: Test.ReqLoc				# 参考位置
@export var reference: Fragment					# 参考Fragment（用于动态计算level）

# 计算为执行版本
func evaluate(context: Context) -> ActModifierC:
	var computed_level = level
	
	# 如果设置了reference，根据其数量计算实际level
	if reference and context:
		var ref_count = context.count(reference, 0)
		computed_level = level * ref_count
	
	var result = ActModifierC.new()
	result.op = op
	result.fragment = fragment
	result.level = computed_level
	result.context = context
	
	return result

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		ActOp.ADJUST:
			return "调整数量"
		ActOp.GRAB:
			return "抓取移动"
		ActOp.SET_MEMORY:
			return "设置记忆"
		ActOp.RUN_TRIGGERS:
			return "运行触发器"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return fragment != null