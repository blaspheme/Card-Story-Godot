extends Node
class_name ActLogic

# ActLogic ：负责 Act 生命周期与场景节点交互。
#
# 设计原则：
# - 通过 ContextFacade / ModifierEvaluator / CommandExecutor 等 system 服务实现规则与 modifier 的评估和执行。
# - 保持职责单一：不在此处实现 fragment 计数或 modifier 细节。

@export var frag_tree_path: NodePath
@export var timer_path: NodePath

@onready var frag_tree = get_node(frag_tree_path)
@onready var _timer = get_node(timer_path)

var _fsm_logic : ActFSMLogic= null

# Signals for UI/display layer to connect to. ActLogic only emits lifecycle/events.
# UI code should live in a separate script (e.g. act_logic_ui.gd) that listens and
# drives the actual `ActWindow` node. This keeps flow logic independent from display.
signal act_started(act)
signal act_status_changed(status)
signal act_update()
signal act_results_ready(frag_tree, active_act)
signal act_setup_result_cards(direct_cards)
signal act_end_text_changed(text)
signal act_timer_started(time)
signal act_timer_stopped()

var _active_act = null
var _alt_act = null
var _pool_manager: PoolManager = PoolManager.new()
var _modifier_evaluator: ModifierEvaluator = ModifierEvaluator.new()
var _command_executor: CommandExecutor = CommandExecutor.new()

func inject_pool_manager(pool: PoolManager) -> void:
	# 允许上层（例如 GameManager）注入全局 PoolManager
	assert(pool != null)
	_pool_manager = pool

func _ready() -> void:
	# 静态契约：节点依赖必须在启动时存在，否则立刻失败以便尽快修复
	assert(frag_tree != null)
	assert(_timer != null)
	_timer.timeout.connect(Callable(self, "_on_time_up"))
	# 若存在 GameManager 单例且其提供 pool_manager，则请求注入全局池以实现跨 ActLogic 共享
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		# 按 AGENTS.md 的静态契约风格：断言 GameManager 提供 pool_manager 字段与注入接口
		assert(gm != null)
		# 强制性契约：GameManager 必须提供 pool_manager 与注入接口，若不存在则尽早失败
		assert(gm.pool_manager != null)
		# 直接调用注入接口（若不存在，将在运行时报错，遵循 AGENTS.md 的快速失败策略）
		gm.inject_pool_to_act_logic(self)

func run_act(act) -> void:
	# 启动并运行一个 Act（等价于 C# RunAct）
	assert(act != null)
	_active_act = act
	_alt_act = null

	# 在需要时，Act 可能通过 forceRule 被强制执行；保留调用方式以兼容上层逻辑
	if act.force_rule != null:
		var fctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
		# 期望 act.force_rule 提供 Run(context) 接口（按项目契约）
		act.force_rule.Run(fctx)
		fctx.dispose()

	# 通知 UI 层 Act 已开始并切换到运行状态
	emit_signal("act_started", act)
	emit_signal("act_status_changed", "Running")
	emit_signal("act_update")

	_populate_act_list(act.alt_acts, "_alt_acts_holder", act.randomAlt) # 占位：C# 使用外部容器，这里仅保持接口风格

	_attempt_alt_acts()

	if act.time > 0:
		_timer.start(act.time)
		emit_signal("act_timer_started", act.time)
		emit_signal("act_status_changed", "Running")
	else:
		# 立即使用 FSM 处理无计时的 Act
		if _fsm_logic == null:
			_fsm_logic = ActFSMLogic.new()
			add_child(_fsm_logic)
			# 构造显式 services 字典并传入 FSM_Logic，遵循静态契约而非运行时 has_method 检查
			var services = {
				"context_factory": Callable(self, "_make_fsm_context"),
				"frag_tree": frag_tree,
				"inject_triggers": Callable(self, "inject_triggers"),
				"modifier_evaluator": _modifier_evaluator,
				"command_executor": _command_executor,
				"pool_manager": _pool_manager,
				"signal_target": self
			}
			_fsm_logic.start(act, services)
			# 将新创建的 FSM 注册到 GameManager，便于中央调度
			if Engine.has_singleton("GameManager"):
				var gm = Engine.get_singleton("GameManager")
				gm.register_fsm(_fsm_logic)
		# 让节点的 _process 驱动 FSM 的进展（frame-driven）
		# 返回以避免继续原有同步流，处理将由 FSM 在随后帧推进完成
		return

func _on_time_up() -> void:
	_timer.stop()
	# 始终使用 FSM 处理计时完成的 Act
	if _fsm_logic == null:
		_fsm_logic = ActFSMLogic.new()
		add_child(_fsm_logic)
		var services = {
			"context_factory": Callable(self, "_make_fsm_context"),
			"frag_tree": frag_tree,
			"inject_triggers": Callable(self, "inject_triggers"),
			"modifier_evaluator": _modifier_evaluator,
			"command_executor": _command_executor,
			"pool_manager": _pool_manager,
			"signal_target": self
		}
		_fsm_logic.start(_active_act, services)
		if Engine.has_singleton("GameManager"):
			var gm = Engine.get_singleton("GameManager")
			gm.register_fsm(_fsm_logic)
	# 将让 _process 在随后的帧驱动 FSM
	emit_signal("act_timer_stopped")
	return

func _setup_act_results() -> void:
	# 在 Act 完成点处理 fragments、triggers、modifiers 与后续 Act
	if _alt_act != null:
		_active_act = _alt_act

	# 将 fragments 添加到 frag_tree
	for frag in _active_act.fragments:
		frag_tree.add_fragment(frag)

	_apply_triggers()

	# 使用 ContextFacade 创建上下文并评估/执行 modifiers（建议 ActLogic 控制时机）
	var facade = ContextFacade.acquire_from_act_logic(self, true, _pool_manager)
	# 先由 evaluator 将 ActData 的 resource modifiers 转成命令队列
	_modifier_evaluator.evaluate_all_from_actdata(_active_act, facade.get_data(), _pool_manager)
	# 执行命令并传入 PoolManager 以便自动回收
	_command_executor.execute_and_release(facade.get_data().act_modifiers, facade.get_data(), _pool_manager)
	_command_executor.execute_and_release(facade.get_data().card_modifiers, facade.get_data(), _pool_manager)
	_command_executor.execute_and_release(facade.get_data().table_modifiers, facade.get_data(), _pool_manager)
	_command_executor.execute_and_release(facade.get_data().path_modifiers, facade.get_data(), _pool_manager)
	_command_executor.execute_and_release(facade.get_data().deck_modifiers, facade.get_data(), _pool_manager)
	facade.dispose()

	# 生成/刷新的 Acts 列表与 Spawn
	# 注意：GameManager 作为 autoload 单例存在于项目中（按契约），直接调用其 SpawnAct 接口
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		for link in _active_act.spawned_acts:
			gm.SpawnAct(link.act, frag_tree, null)

	var end_text = _get_end_text(_active_act)
	if end_text != "":
		# 存储并在 UI 展示
		_active_act.end_text = end_text
		emit_signal("act_end_text_changed", end_text)

	# 分支/下一步逻辑（简化版）
	if _active_act.next_acts != null and _active_act.next_acts.size() > 0:
		var next_act = _attempt_next_acts(_active_act.next_acts)
		if next_act != null:
			run_act(next_act)
			return

	_setup_final_results()

func _setup_final_results() -> void:
	# 通知 UI 层生成/刷新结果卡片并标记完成状态
	emit_signal("act_setup_result_cards", frag_tree.direct_cards())
	emit_signal("act_status_changed", "Finished")
	emit_signal("act_results_ready", frag_tree, _active_act)

func _attempt_next_acts(acts: Array) -> Object:
	# 简化的 AttemptActs：遍历 acts 并返回第一个 Attempt 成功的 Act
	for actlink in acts:
		if actlink.act != null:
			var ctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
			var passed = actlink.act.Attempt(ctx)
			ctx.dispose()
			if passed:
				return actlink.act
	return null

func _attempt_alt_acts() -> void:
	# Evaluate alt acts and set _alt_act
	for link in _active_act.alt_acts:
		var ctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
		var passed = link.act.Attempt(ctx)
		ctx.dispose()
		if passed:
			_alt_act = link.act
			return

func _populate_act_list(_source: Array, _target_name: String, _random_order: bool=false) -> void:
	# 占位：保留接口以便将来实现更复杂的列表填充逻辑
	return

func attempt_act(act, force: bool=false) -> bool:
	var ctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
	var res = act.Attempt(ctx, force)
	if res:
		ctx.get_data().save_matches()
	ctx.dispose()
	return res

func attempt_acts(acts: Array, _match_token: bool=false) -> Object:
	var ctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
	for actlink in acts:
		if actlink.act != null:
			var ok = actlink.act.Attempt(ctx)
			if ok:
				ctx.dispose()
				return actlink.act
	ctx.dispose()
	return null

func inject_triggers(target) -> void:
	if target == null:
		return
	var ctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
	if target.fragment != null:
		_apply_aspect_triggers(ctx, target.fragment)
	else:
		for cardViz in target.cards:
			_apply_card_triggers(ctx, cardViz)
	ctx.dispose()

func _apply_card_triggers(ctx, cardViz) -> void:
	if cardViz == null:
		return
	ctx.get_data().this_card = cardViz
	ctx.get_data().this_aspect = cardViz.card
	for rule in cardViz.card.rules:
		rule.Run(ctx)
	ctx.get_data().this_card = null

func _apply_aspect_triggers(ctx, fragment) -> void:
	if fragment == null:
		return
	ctx.get_data().this_aspect = fragment
	for rule in fragment.rules:
		rule.Run(ctx)
	ctx.get_data().this_aspect = null

func _apply_triggers() -> void:
	var ctx = ContextFacade.acquire_from_act_logic(self, false, _pool_manager)
	for cardViz in ctx.get_data().scope.cards:
		_apply_card_triggers(ctx, cardViz)
	for frag in ctx.get_data().scope.fragments:
		_apply_aspect_triggers(ctx, frag.fragment)
	ctx.dispose()

func reset() -> void:
	_active_act = null
	_alt_act = null
	frag_tree.clear()
	if _fsm_logic != null:
		# 清理并移除 FSM_Logic 实例
		# 从 GameManager 注销
		if Engine.has_singleton("GameManager"):
			var gm = Engine.get_singleton("GameManager")
			gm.unregister_fsm(_fsm_logic)
		_fsm_logic.dispose()
		_fsm_logic.queue_free()
		_fsm_logic = null
	emit_signal("act_update")

func _make_fsm_context() -> Object:
	# 为 FSM 提供与原有 ActLogic 等价的 ContextFactory
	return ContextFacade.acquire_from_act_logic(self, true, _pool_manager)

func tick(delta: float) -> void:
	# 由 GameManager 驱动的每帧更新入口（替代 _process）
	# GameManager 应在其主循环中调用 act_logic.tick(delta) 来推进 FSM
	if _fsm_logic != null and _fsm_logic.is_running():
		_fsm_logic.tick(delta)

func save() -> Dictionary:
	var out = {
		"fragSave": frag_tree.save(),
		"activeAct": _active_act,
		"altAct": _alt_act
	}
	return out

func load(save_data: Dictionary) -> void:
	frag_tree.load(save_data.get("fragSave"))
	_active_act = save_data.get("activeAct", null)
	_alt_act = save_data.get("altAct", null)

func _get_end_text(act) -> String:
	if act == null:
		return ""
	var et = ""
	if act.end_text != null:
		et = act.end_text
	return et
