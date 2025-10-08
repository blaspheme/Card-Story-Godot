# TableModifier - 桌面修改器
class_name TableModifier
extends Resource

# 桌面操作类型枚举
enum TableOp {
	SPAWN_ACT = 0,		# 生成行动
	SPAWN_TOKEN = 10,	# 生成令牌
}

@export var op: TableOp							# 操作类型
@export var act: Act							# 操作的行动

# 执行桌面修改器
func execute(context: Context) -> void:
	if not context or not context.act_logic:
		return
	
	match op:
		TableOp.SPAWN_ACT:
			GameManager.instance.spawn_act(act, context.scope, context.act_logic.token_viz)
		TableOp.SPAWN_TOKEN:
			GameManager.instance.spawn_token(act.token, context.scope, context.act_logic.token_viz)

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