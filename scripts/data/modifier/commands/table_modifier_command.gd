extends RefCounted
class_name TableModifierCommand

# Table 相关 modifier 命令实现。

var op = GameEnums.TableOp.SpawnAct
var act = null

func setup(...varargs: Array) -> void:
	# 支持签名：setup(op, act)
	var _op = varargs[0] if varargs.size() > 0 else null
	var _act = varargs[1] if varargs.size() > 1 else null
	op = _op as GameEnums.TableOp
	act = _act

func execute(context) -> void:
	assert(context != null and context.act_logic != null)
	match op:
		GameEnums.TableOp.SpawnAct:
			context.act_logic.SpawnAct(act, context.scope, context.act_logic.token_viz)
		GameEnums.TableOp.SpawnToken:
			context.act_logic.SpawnToken(act.token, context.scope, context.act_logic.token_viz)

func release() -> void:
	op = GameEnums.TableOp.SpawnAct
	act = null
