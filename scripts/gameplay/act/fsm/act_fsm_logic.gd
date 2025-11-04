extends Node
class_name ActFSMLogic

# Application-level FSM 桥接：将通用 ActFSM 与项目内的 ActLogic 结合。
# - 通过注入 ActLogic（或至少满足部分契约的 Node）来驱动具体流程。
# - 在状态转变到 RESOLVING 时，执行与原有 ActLogic._setup_act_results 相同的评估/执行流程。

signal started(act)
signal status_changed(status)
signal results_ready(frag_tree, act)

var _fsm: ActFSM = null
var _services: Dictionary = {}
var _act = null


func start(act, services: Dictionary) -> void:
	"""
	Start the FSM with an explicit services dictionary.
	Required keys: "context_factory" (Callable), "frag_tree" (Node), "inject_triggers" (Callable),
	"modifier_evaluator", "command_executor", "pool_manager".
	Optional: "advance_immediately": bool
	"""
	assert(act != null)
	assert(services != null and typeof(services) == TYPE_DICTIONARY)
	# 验证必需服务（静态契约风格，尽量断言而非动态容错）
	assert(services.has("context_factory"))
	assert(services.has("frag_tree"))
	assert(services.has("inject_triggers"))
	assert(services.has("modifier_evaluator"))
	assert(services.has("command_executor"))
	assert(services.has("pool_manager"))

	_act = act
	_services = services

	# 创建并启动 FSM
	_fsm = ActFSM.new()
	# 使用 Callable 连接，便于后续 disconnect
	_fsm.connect("state_changed", Callable(self, "_on_fsm_state_changed"))
	_fsm.connect("finished", Callable(self, "_on_fsm_finished"))
	_fsm.start(act, _services)
	# 触发开始信号，供 UI 监听
	emit_signal("started", act)
	emit_signal("status_changed", "Running")

func tick(delta: float) -> void:
	if _fsm != null and _fsm.is_running():
		_fsm.tick(delta)

func _make_context() -> Object:
	# 使用注入的 context_factory 创建上下文
	assert(_services.has("context_factory"))
	var cf = _services["context_factory"]
	assert(cf != null)
	return cf.call()

func _on_fsm_state_changed(_old_state, new_state) -> void:
	# 当 FSM 进入解析阶段，执行原 ActLogic 的结果设置流程
	if new_state == ActFSM.State.RESOLVING:
		_perform_setup_results()

func _on_fsm_finished(_result) -> void:
	# FSM 完成后的收尾通知
	# 将完成状态通过 services 的 signal_target 回传给 ActLogic（若提供）
	if _services.has("signal_target"):
		var target = _services["signal_target"]
		if target != null and target.has_signal("act_status_changed"):
			target.emit_signal("act_status_changed", "Finished")
	emit_signal("status_changed", "Finished")
	# 将 FSM 以及内部引用清理
	dispose()

func _perform_setup_results() -> void:
	# 与 ActLogic._setup_act_results 对齐的实现，使用注入服务而非直接依赖 owner
	assert(_services.has("frag_tree"))
	assert(_services.has("inject_triggers"))
	assert(_services.has("modifier_evaluator"))
	assert(_services.has("command_executor"))
	assert(_services.has("pool_manager"))
	var active_act = _act

	# 将 fragments 添加到 frag_tree
	var frag_tree = _services["frag_tree"]
	for frag in active_act.fragments:
		frag_tree.add_fragment(frag)

	# 注入 triggers
	var inject_tr = _services["inject_triggers"]
	inject_tr.call(_act)

	# 使用注入的 context_factory 创建上下文并评估/执行 modifiers
	var facade = _services["context_factory"].call()
	_services["modifier_evaluator"].evaluate_all_from_actdata(active_act, facade.get_data(), _services["pool_manager"])
	var cmd_exec = _services["command_executor"]
	cmd_exec.execute_and_release(facade.get_data().act_modifiers, facade.get_data(), _services["pool_manager"])
	cmd_exec.execute_and_release(facade.get_data().card_modifiers, facade.get_data(), _services["pool_manager"])
	cmd_exec.execute_and_release(facade.get_data().table_modifiers, facade.get_data(), _services["pool_manager"])
	cmd_exec.execute_and_release(facade.get_data().path_modifiers, facade.get_data(), _services["pool_manager"])
	cmd_exec.execute_and_release(facade.get_data().deck_modifiers, facade.get_data(), _services["pool_manager"])
	facade.dispose()

	# Spawn acts
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		for link in active_act.spawned_acts:
			gm.SpawnAct(link.act, frag_tree, null)

	# end text
	var end_text = ""
	if active_act.end_text != null:
		end_text = active_act.end_text
	if end_text != "":
		active_act.end_text = end_text
		# 将结束文本通过 services 的 signal_target（如果提供）传出
		if _services.has("signal_target"):
			var target = _services["signal_target"]
			if target != null and target.has_signal("act_end_text_changed"):
				target.emit_signal("act_end_text_changed", end_text)

	# 最终结果通知，通过 services 的 signal_target 转发
	if _services.has("signal_target"):
		var target = _services["signal_target"]
		if target != null:
			if target.has_signal("act_setup_result_cards"):
				target.emit_signal("act_setup_result_cards", frag_tree.direct_cards())
			if target.has_signal("act_results_ready"):
				target.emit_signal("act_results_ready", frag_tree, active_act)

	emit_signal("results_ready", frag_tree, active_act)

func stop() -> void:
	if _fsm != null:
		_fsm.force_finish()

func dispose() -> void:
	if _fsm != null:
		# 断开已连接的信号，避免悬挂回调
		_fsm.disconnect("state_changed", Callable(self, "_on_fsm_state_changed"))
		_fsm.disconnect("finished", Callable(self, "_on_fsm_finished"))
		_fsm.dispose()
	_fsm = null
	_services.clear()
	_act = null

func is_running() -> bool:
	# 外部轮询接口：返回 FSM 是否处于运行态
	return _fsm != null and _fsm.is_running()
