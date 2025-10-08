# PathModifier - 路径修改器
class_name PathModifier
extends Resource

# 路径操作类型枚举
enum PathOp {
	OPEN_PATH = 0,			# 开启路径
	CLOSE_PATH = 10,		# 关闭路径
	SET_PATH_CONDITION = 20,	# 设置路径条件
	TRIGGER_PATH = 30,		# 触发路径
}

@export var op: PathOp							# 操作类型
@export var target: Fragment					# 目标路径Fragment
@export var fragment: Fragment					# 操作的Fragment
@export var level: int							# 操作参数
@export var reference: Fragment					# 参考Fragment（用于动态计算level）

# 路径相关属性
@export_group("路径属性")
@export var path_id: String = ""				# 路径ID
@export var destination_scene: String = ""		# 目标场景路径
@export var condition_text: String = ""		# 条件描述文本

# 计算为执行版本
func evaluate(context: Context) -> PathModifierC:
	var computed_level = level
	
	# 如果设置了reference，根据其数量计算实际level
	if reference and context:
		var ref_count = context.count(reference, 0)
		computed_level = level * ref_count
	
	var result = PathModifierC.new()
	result.op = op
	result.target = target
	result.fragment = fragment
	result.level = computed_level
	result.context = context
	result.path_id = path_id
	result.destination_scene = destination_scene
	result.condition_text = condition_text
	
	return result

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		PathOp.OPEN_PATH:
			return "开启路径"
		PathOp.CLOSE_PATH:
			return "关闭路径"
		PathOp.SET_PATH_CONDITION:
			return "设置路径条件"
		PathOp.TRIGGER_PATH:
			return "触发路径"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return path_id != "" or target != null