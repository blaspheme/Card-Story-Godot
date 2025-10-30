extends Node

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
	#for fsm in act_fsms:
		#if fsm and fsm.is_active():
			#fsm.tick(dt)
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
