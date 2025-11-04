extends Node
class_name GameManager

# ===============================
# 实例化scene
# ===============================
const card_viz = preload("res://scenes/gameplay/widgets/viz2d/card_viz_2d.tscn")


# ===============================
# 其他参数
# ===============================
var fixed_dt := 1.0 / 60.0
var accumulator := 0.0

var behavior_system: BehaviorSystem
var card_states: Array = []
# 持有所有活动的 FSM（ActStateMachine 实例）
var act_fsms: Array = []
var pool_manager: PoolManager = null

func _ready() -> void:
	_init_behavior_system()
	# 初始化全局 PoolManager，用于跨 ActLogic 实例共享命令对象池
	pool_manager = preload("res://scripts/system/core/pool_manager.gd").new()

	# 在启动时注入已存在的 ActLogic 节点
	_inject_existing_actlogic_nodes()

	# 监听后续节点加入（动态实例化场景 / 工厂创建），自动注入 pool
	get_tree().connect("node_added", Callable(self, "_on_node_added"))
	# 监听节点移除以便注销 ActLogic（避免悬挂的引用）
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))


func _process(delta: float) -> void:
	_fixed_update(delta)

func _update_render_only(_delta: float) -> void:
	# UI 更新等
	pass

func _fixed_update(dt: float) -> void:
	pass
	## 1) Behaviors（热路径）
	if behavior_system != null:
		behavior_system.apply_behaviors(card_states, dt)
	## 2) Tick FSMs（切换/计时/触发规则）
	for fsm_obj in act_fsms:
		# 若被注册的是 ActLogic 节点或任何实现了 tick(delta) 的对象，则调用其 tick
		if fsm_obj != null and typeof(fsm_obj) == TYPE_OBJECT and fsm_obj.has_method("tick"):
			# 安全调用：如果对象提供 is_running() 可优先检查
			if fsm_obj.has_method("is_running"):
				if fsm_obj.is_running():
					fsm_obj.tick(dt)
			else:
				# 未实现 is_running，直接调用 tick
				fsm_obj.tick(dt)
	## 3) 可选：RuleSystem 轮询或响应式调用由 FSM 调用
	## 4) 清理/回收
	#_cleanup_expired_states()

func register_card_state(state) -> void:
	if not card_states.has(state):
		card_states.append(state)

func unregister_card_state(state) -> void:
	card_states.erase(state)

func register_fsm(fsm) -> void:
	if not act_fsms.has(fsm):
		act_fsms.append(fsm)

func unregister_fsm(fsm) -> void:
	act_fsms.erase(fsm)

func _cleanup_expired_states() -> void:
	# 处理 expired 卡片等
	pass

# ===============================
# 构建初始化系统
# ===============================
func _init_behavior_system() -> void:
	# 创建 BehaviorSystem 实例
	behavior_system = preload("res://scripts/system/behavior/behavior_system.gd").new()
	## 注册 handlers（每个 handler 单独文件）
	var decay_handler = preload("res://scripts/system/behavior/decay_handle.gd").new()
	behavior_system.register_handler("decay", decay_handler)

func inject_pool_to_act_logic(act_logic) -> void:
	# 将全局 pool 注入到 ActLogic 实例，按静态契约要求 act_logic 提供 inject_pool_manager 方法
	assert(act_logic != null)
	assert(typeof(act_logic) == TYPE_OBJECT)
	assert(act_logic.has_method("inject_pool_manager"), "ActLogic must implement inject_pool_manager(pool)")
	assert(pool_manager != null)
	act_logic.inject_pool_manager(pool_manager)
	# 将 ActLogic 注册到每帧驱动列表，由 GameManager 调用 tick(delta)
	register_fsm(act_logic)

func _inject_existing_actlogic_nodes() -> void:
	# 遍历当前场景树，寻找所有 ActLogic 节点并注入 pool
	var root = get_tree().get_root()
	_inject_recursive(root)

func _inject_recursive(node: Node) -> void:
	for child in node.get_children():
		# 若 child 是 ActLogic，则注入
		if typeof(child) == TYPE_OBJECT and child is ActLogic:
			inject_pool_to_act_logic(child)
		# 递归检查子节点
		_inject_recursive(child)

func _on_node_added(node: Node) -> void:
	# 当新节点加入树时，如果是 ActLogic，立即注入 pool
	if node is ActLogic:
		inject_pool_to_act_logic(node)

func _on_node_removed(node: Node) -> void:
	# 当节点从场景树移除时，如果是 ActLogic，则注销以清理 act_fsms 列表
	if node is ActLogic:
		unregister_fsm(node)
