extends Node
class_name GameManager

var fixed_dt := 1.0 / 60.0
var accumulator := 0.0

var behavior_system: BehaviorSystem
var card_states: Array = []
# 持有所有活动的 FSM（ActStateMachine 实例）
var act_fsms: Array = []

func _ready() -> void:
	_init_behavior_system()


func _process(delta: float) -> void:
	_fixed_update(delta)

func _update_render_only(delta: float) -> void:
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
