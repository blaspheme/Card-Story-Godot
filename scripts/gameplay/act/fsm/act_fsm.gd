extends RefCounted
class_name ActFSM

# 可复用的 Act 状态机（轻量级）
# 目标：尽量与具体项目解耦，只通过注入的服务（callable/对象）完成工作。
# - 使用 tabs 缩进（遵循 AGENTS.md）
# - 断言契约：对必须存在的服务使用 assert，避免动态容错

signal state_changed(old_state, new_state)
signal finished(result)
signal log(msg)

enum State {
	IDLE,
	PREPARING,
	RUNNING,
	RESOLVING,
	EXECUTING_MODIFIERS,
	FINALIZING,
	FINISHED,
	CANCELLED,
	TIMEOUT
}

var _state: int = State.IDLE
var _act_data = null		# Act Resource / Dictionary
var _services: Dictionary = {} # 必须包含 context_factory, modifier_evaluator, command_executor, pool_manager（按需）
var _result = null
var _running: bool = false

func _ensure_services() -> void:
	# 检查必要服务；允许按需扩展
	assert(_services.has("context_factory"))
	assert(_services["context_factory"] != null)
	# evaluator 和 executor 可选，但若缺失会在执行阶段断言

func start(act_data, services: Dictionary) -> void:
	"""
	启动 FSM：注入 act_data 与服务字典。
	act_data: 任意表示 Act 的对象（Resource/Dictionary），FSM 不解析内部细节，交由 evaluator/logic 处理。
	services: {
		"context_factory": Callable 或 函数, # signature: () -> Context
		"modifier_evaluator": Object (可选),
		"command_executor": Object (可选),
		"pool_manager": Object (可选),
		其他按需扩展
	}
	"""
	assert(act_data != null)
	assert(services != null and typeof(services) == TYPE_DICTIONARY)
	_services = services
	_act_data = act_data
	_running = true
	_goto_state(State.PREPARING)

	# 支持同步推进（用于测试或工具）
	if services.has("advance_immediately") and services["advance_immediately"]:
		# 轻量推进若干步，允许 evaluator/executor 运行同步路径
		_tick_for_immediate_advance()

func tick(delta: float) -> void:
	# 驱动函数，外层（GameLoop / ActLogic）应在 fixed-step 调用
	if not _running:
		return
	match _state:
		State.PREPARING:
			_perform_prepare()
		State.RUNNING:
			_perform_run(delta)
		State.RESOLVING:
			_perform_resolve()
		State.EXECUTING_MODIFIERS:
			_perform_execute_modifiers()
		State.FINALIZING:
			_perform_finalize()
		# 其他状态不在 tick 中执行主动逻辑

func handle_event(ev: String, _payload: Variant = null) -> void:
	# 外部事件驱动接口：可由 ActLogic/UI 调用
	assert(ev != "")
	# 简单事件示例："force_finish", "cancel", "timeout"
	match ev:
		"force_finish": force_finish()
		"cancel": _goto_state(State.CANCELLED)
		"timeout": _goto_state(State.TIMEOUT)
		_:
			emit_signal("log", "Unhandled event: %s" % ev)

func force_finish() -> void:
	# 立即结束（会触发 finished 信号）
	_goto_state(State.FINALIZING)

func is_running() -> bool:
	return _running

func current_state() -> int:
	return _state

func _goto_state(new_state: int) -> void:
	var old = _state
	_state = new_state
	emit_signal("state_changed", old, new_state)
	# 进入新状态的即时动作
	match new_state:
		State.PREPARING:
			# nothing immediate; tick will call _perform_prepare
			pass
		State.FINALIZING:
			# 直接 finalize
			_perform_finalize()
		State.FINISHED:
			_running = false
			emit_signal("finished", _result)

# --- 状态实现占位（保持简单，注释说明如何扩展） ---
func _perform_prepare() -> void:
	# 准备阶段：可以在这里创建 context、注入 fragments、做预评估。
	# 例：var ctx = _services.context_factory()
	# 本方法不做具体规则评估，具体逻辑应由外部注入的 evaluator/logic 执行。
	# 在准备完成后切换到 RUNNING
	_goto_state(State.RUNNING)

func _perform_run(_delta: float) -> void:
	# 运行阶段：等待 Act 的运行时（例如计时器），或立即进入 RESOLVING。
	# 默认直接推进到解析（可由 ActFSMLogic 控制定时）
	_goto_state(State.RESOLVING)

func _perform_resolve() -> void:
	# 解析阶段：评估 modifiers -> 生成命令队列
	assert(_services.has("modifier_evaluator"))
	var evaluator = _services["modifier_evaluator"]
	assert(evaluator != null)
	# evaluator 需要提供 evaluate_all_from_actdata(act_data, data, pool) 或类似接口
	# 这里我们只做约束调用，具体语义交由 evaluator 实现
	# 进入下个状态
	_goto_state(State.EXECUTING_MODIFIERS)

func _perform_execute_modifiers() -> void:
	# 执行命令队列
	assert(_services.has("command_executor"))
	var executor = _services["command_executor"]
	assert(executor != null)
	# executor.execute_and_release(commands, data, pool_manager)
	# TODO: 真实实现会从 context/facade 中取出命令队列并交给 executor
	_goto_state(State.FINALIZING)

func _tick_for_immediate_advance() -> void:
	# 尝试以 0 delta 推进有限步数，直到进入 RESOLVING 或达到上限
	var attempts = 0
	while attempts < 5 and _state < State.RESOLVING:
		_tick_once(0)
		attempts += 1

func _tick_once(_delta: float) -> void:
	# 内部一步推进，避免外部直接调用不安全API
	match _state:
		State.PREPARING:
			_perform_prepare()
		State.RUNNING:
			_perform_run(0)
		State.RESOLVING:
			_perform_resolve()
		State.EXECUTING_MODIFIERS:
			_perform_execute_modifiers()
		State.FINALIZING:
			_perform_finalize()

func _perform_finalize() -> void:
	# 收尾：保存结果、触发 spawn 等。设置 _result 并进入 FINISHED
	_result = {"status":"ok"}
	_goto_state(State.FINISHED)

# 可被外部调用的辅助 API
func abort(reason: String) -> void:
	_result = {"status":"aborted", "reason": reason}
	_goto_state(State.CANCELLED)

func dispose() -> void:
	# 清理内部引用，便于回收或池化
	_act_data = null
	_services.clear()
	_running = false
