# PathModifier - 路径修改器
class_name PathModifier
extends Resource

# 路径操作类型枚举
enum PathOp {
	BRANCH_OUT = 0,
	FORCE_ACT = 20,
	SET_CALLBACK = 40,
	CALLBACK = 41,
	GAME_OVER = 80,
}

@export var op: PathOp							# 操作类型
@export var act: Act							# 操作的行动

# 执行路径修改器
func execute(context: Context) -> void:
	if not context or not context.act_logic:
		return
	
	match op:
		PathOp.BRANCH_OUT:
			context.act_logic.branch_out(act)
		PathOp.FORCE_ACT:
			context.act_logic.set_force_act(act)
		PathOp.SET_CALLBACK:
			context.act_logic.set_callback(act)
		PathOp.CALLBACK:
			context.act_logic.do_callback()
		PathOp.GAME_OVER:
			GameManager.instance.reset()
			GameManager.instance.spawn_act(act, null, null)

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