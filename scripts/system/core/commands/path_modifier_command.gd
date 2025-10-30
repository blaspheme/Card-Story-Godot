extends RefCounted
class_name PathModifierCommand

# 路径（Path）modifier 的命令实现。

var op = GameEnums.PathOp.BranchOut
var act = null

func setup(...varargs: Array) -> void:
	# 支持签名：setup(op, act)
	var _op = varargs[0] if varargs.size() > 0 else null
	var _act = varargs[1] if varargs.size() > 1 else null
	op = _op as GameEnums.PathOp
	act = _act

func execute(context) -> void:
	assert(context != null and context.act_logic != null)
	match op:
		GameEnums.PathOp.BranchOut:
			context.act_logic.BranchOut(act)
		GameEnums.PathOp.ForceAct:
			context.act_logic.SetForceAct(act)
		GameEnums.PathOp.SetCallback:
			context.act_logic.SetCallback(act)
		GameEnums.PathOp.Callback:
			context.act_logic.DoCallback()
		GameEnums.PathOp.GameOver:
			# 按静态契约：期望存在能执行重置与.spawn 的管理器；这里直接调用 act_logic 的接口，缺失将导致尽早失败以便修复
			assert(context.act_logic != null)
			context.act_logic.Reset()
			context.act_logic.SpawnAct(act, null, null)

func release() -> void:
	op = GameEnums.PathOp.BranchOut
	act = null
