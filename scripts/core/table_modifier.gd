# TableModifier - 桌面修改器
class_name TableModifier
extends Resource

# 桌面操作类型枚举
enum TableOp {
	SITUATION_CREATE = 0,	# 创建情境
	SITUATION_DESTROY = 10,	# 销毁情境
	SET_VERB = 50,			# 设置动作动词
}

@export var op: TableOp							# 操作类型
@export var target: Fragment					# 目标Fragment
@export var fragment: Fragment					# 操作的Fragment
@export var level: int							# 操作强度
@export var reference: Fragment					# 参考Fragment（用于动态计算level）

# 计算为执行版本
func evaluate(context: Context) -> TableModifierC:
	var computed_level = level
	
	# 如果设置了reference，根据其数量计算实际level
	if reference and context:
		var ref_count = context.count(reference, 0)
		computed_level = level * ref_count
	
	var result = TableModifierC.new()
	result.op = op
	result.target = target
	result.fragment = fragment
	result.level = computed_level
	result.context = context
	
	return result

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		TableOp.SITUATION_CREATE:
			return "创建情境"
		TableOp.SITUATION_DESTROY:
			return "销毁情境"
		TableOp.SET_VERB:
			return "设置动作"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return fragment != null