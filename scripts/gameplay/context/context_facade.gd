extends RefCounted
class_name ContextFacade

# 上层 Facade：把 ContextData 与服务 (PoolManager, CommandExecutor, FragmentResolver) 组合。
# 该 Facade 提供 acquire/dispose/release 等常用方法。

static var _command_executor: CommandExecutor = CommandExecutor.new()
static var _fragment_resolver: FragmentResolver = FragmentResolver.new()
static var _modifier_evaluator: ModifierEvaluator = ModifierEvaluator.new()

static var POOL_MAX = 128

var _data = null
static var _ContextDataClass = preload("res://scripts/gameplay/context/context_data.gd")
var _pool_manager: PoolManager = null

# ContextFacade 不再保留对旧 Context 的字段代理。
# Facade 仅持有 ContextData（_data），所有服务直接作用于 ContextData。
# 如需访问内部数据，请调用 get_data() 并遵循静态契约（assert _data != null）。

func get_data():
	assert(_data != null)
	return _data

static func acquire_from_act_logic(act_logic_arg, keep_matches: bool=false, pool: PoolManager = null) -> ContextFacade:
	# 创建新的 ContextFacade，直接构造 ContextData 并遵循静态契约
	var facade: ContextFacade = ContextFacade.new()
	var data = _ContextDataClass.new()
	data.act_logic = act_logic_arg
	if act_logic_arg != null:
		# 要求传入的 act_logic 必须提供 fragTree（静态契约）
		assert(typeof(act_logic_arg) == TYPE_OBJECT and act_logic_arg.has("fragTree"))
		data.scope = act_logic_arg.fragTree
	else:
		data.scope = null
	data._clear_for_pool()
	facade._data = data
	# 如果调用方提供了 pool，则注入；否则保持 null（调用方决定是否共享池）
	facade._pool_manager = pool
	_fragment_resolver.init_matches(data, keep_matches)
	return facade

## Note: acquire_from_context 已移除（不再兼容旧 Context 对象）。

static func acquire_from_frag_tree(frag_tree, keep_matches: bool=false, pool: PoolManager = null) -> ContextFacade:
	var facade: ContextFacade = ContextFacade.new()
	var data = _ContextDataClass.new()
	data.act_logic = null
	# 要求调用者保证 frag_tree 为合法的 frag tree 对象
	assert(frag_tree != null)
	data.scope = frag_tree
	data._clear_for_pool()
	facade._data = data
	facade._pool_manager = pool
	_fragment_resolver.init_matches(data, keep_matches)
	return facade

static func acquire_from_card_viz(card_viz, keep_matches: bool=false, pool: PoolManager = null) -> ContextFacade:
	var facade: ContextFacade = ContextFacade.new()
	var data = _ContextDataClass.new()
	data.act_logic = null
	# 要求 card_viz 提供 frag_tree
	assert(card_viz != null and typeof(card_viz) == TYPE_OBJECT and card_viz.has("frag_tree"))
	data.scope = card_viz.frag_tree
	data._clear_for_pool()
	facade._data = data
	facade._pool_manager = pool
	_fragment_resolver.init_matches(data, keep_matches)
	return facade

func _init() -> void:
	_data = null

func _ensure_data() -> void:
	# 强制契约：如果 _data 缺失则断言失败，按照 AGENTS.md 的静态设计要求尽早暴露问题
	assert(_data != null)

# 备注：原来的字段代理与 setget 已移除以删除兼容性代码。

func dispose() -> void:
	if _data == null:
		return
	# 防止重复 dispose
	if _data.is_disposed():
		return
	_data.mark_disposed()
	# 若存在 evaluator 的需求，调用 evaluator 以把 ActData 中的 Resource modifiers 评估成命令队列。
	# 注意：上层逻辑（例如 ActLogic）也可在需要时手动调用 evaluate_* 方法。
	if _modifier_evaluator != null:
		# 如果当前 data 包含 act_logic 且其 ActData 可用，则评估之（非强制）
		if _data != null and _data.act_logic != null and _data.act_logic.act_data != null:
			_modifier_evaluator.evaluate_all_from_actdata(_data.act_logic.act_data, _data, _pool_manager)

	# 执行收集到的 modifier，传入 pool 以便自动回收命令对象
	_command_executor.execute_and_release(_data.act_modifiers, _data, _pool_manager)
	_command_executor.execute_and_release(_data.card_modifiers, _data, _pool_manager)
	_command_executor.execute_and_release(_data.table_modifiers, _data, _pool_manager)
	_command_executor.execute_and_release(_data.path_modifiers, _data, _pool_manager)
	_command_executor.execute_and_release(_data.deck_modifiers, _data, _pool_manager)
	# 清理 queued visuals：按静态契约要求存在 destroy() 或为 Node
	for cv in _data._to_destroy:
		assert(cv != null)
		if cv is Node:
			cv.queue_free()
		else:
			# 要求对象实现 destroy()（按 AGENTS.md 通过断言暴露问题）
			assert(typeof(cv) == TYPE_OBJECT and cv.has_method("destroy"))
			cv.destroy()
	_data._to_destroy.clear()
	# 回收 data
	_data._clear_for_pool()
	_data = null

func release() -> void:
	# 直接清理，不执行命令
	if _data != null:
		_data._clear_for_pool()
		_data = null

func destroy(card_viz) -> void:
	if _data != null:
		_data.destroy(card_viz)
