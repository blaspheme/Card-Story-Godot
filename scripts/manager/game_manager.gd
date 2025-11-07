extends Node

# Autoload 单例 GameManager

# ===============================
# 实例化scene
# ===============================
const card_viz = preload("res://scenes/gameplay/viz/card_viz.tscn")


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

# 时间缩放相关
var time_scale: float = 1.0

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	_init_behavior_system()
	# 初始化全局 PoolManager，用于跨 ActLogic 实例共享命令对象池
	pool_manager = preload("res://scripts/manager/pool_manager.gd").new()

	# 在启动时注入已存在的 ActLogic 节点
	_inject_existing_actlogic_nodes()

	# 监听后续节点加入（动态实例化场景 / 工厂创建），自动注入 pool
	get_tree().connect("node_added", Callable(self, "_on_node_added"))
	# 监听节点移除以便注销 ActLogic（避免悬挂的引用）
	get_tree().connect("node_removed", Callable(self, "_on_node_removed"))
	
	# 订阅卡片衰败相关事件
	_subscribe_decay_events()


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
	behavior_system = preload("res://scripts/gameplay/behavior/behavior_system.gd").new()
	## 注册 handlers（每个 handler 单独文件）
	var decay_handler = preload("res://scripts/gameplay/behavior/decay_handle.gd").new()
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

# ===============================
# 卡片衰败管理
# ===============================

## 订阅卡片衰败相关事件
func _subscribe_decay_events() -> void:
	EventBus.subscribe("card_decay_completed", _on_card_decay_completed)
	EventBus.subscribe("card_decay_started", _on_card_decay_started)
	EventBus.subscribe("card_decay_stopped", _on_card_decay_stopped)

## 处理卡片衰败完成
func _on_card_decay_completed(card: CardViz, decay_to: CardData) -> void:
	print("GameManager: 处理卡片衰败完成 - %s -> %s" % [card.card_data.label, decay_to.label])
	
	# 执行 on_decay_complete 规则（如果存在）
	if card.card_data.on_decay_complete:
		_execute_decay_rule(card, card.card_data.on_decay_complete)
	
	# 转换卡片
	_transform_card(card, decay_to)

## 处理卡片衰败开始
func _on_card_decay_started(card: CardViz, duration: float, _decay_to: CardData) -> void:
	print("GameManager: 卡片开始衰败 - %s (持续 %s 秒)" % [card.card_data.label, duration])

## 处理卡片衰败停止
func _on_card_decay_stopped(card: CardViz) -> void:
	print("GameManager: 卡片衰败已停止 - %s" % card.card_data.label)

## 执行衰败规则
func _execute_decay_rule(_card: CardViz, rule: RuleData) -> void:
	if rule:
		print("执行衰败规则: %s" % rule.resource_path)
		# TODO: 在这里调用规则系统执行规则
		# RuleSystem.execute_rule(rule, card)

## 卡片转换逻辑
func _transform_card(original_card: CardViz, new_card_data: CardData) -> void:
	print("转换卡片: %s -> %s" % [original_card.card_data.label, new_card_data.label])
	
	# 保存原卡片的状态
	var position = original_card.global_position
	var parent = original_card.get_parent()
	var z_index = original_card.z_index
	
	# 如果原卡片在堆叠中，需要特殊处理
	if original_card.stack != null:
		_transform_stacked_card(original_card, new_card_data)
		return
	
	# 创建新卡片
	var new_card = create_card(new_card_data)
	new_card.global_position = position
	new_card.z_index = z_index
	
	# 执行 on_decay_into 规则（如果新卡片有此规则）
	if new_card_data.on_decay_into:
		_execute_decay_rule(new_card, new_card_data.on_decay_into)
	
	# 添加到场景
	parent.add_child(new_card)
	
	# 播放转换特效
	_play_transform_effect(position)
	
	# 移除原卡片
	original_card.queue_free()

## 处理堆叠中卡片的转换
func _transform_stacked_card(stacked_card: CardViz, new_card_data: CardData) -> void:
	# 从堆叠中移除
	var _stack_owner = stacked_card.stack
	var _new_card = create_card(new_card_data)
	
	# TODO: 需要实现堆叠中卡片的替换逻辑
	print("堆叠中的卡片转换暂未完全实现")

## 创建新卡片
func create_card(card_data: CardData) -> CardViz:
	var card_instance = card_viz.instantiate() as CardViz
	card_instance.card_data = card_data
	# 如果卡片已经在场景中，需要手动调用setup_card
	if card_instance.is_inside_tree():
		card_instance.setup_card()
	return card_instance

## 播放转换特效
func _play_transform_effect(position: Vector2) -> void:
	print("在位置 %s 播放转换特效" % position)
	# TODO: 添加粒子特效、闪光等
	# var effect = preload("res://scenes/effects/transform_effect.tscn").instantiate()
	# effect.global_position = position
	# get_tree().current_scene.add_child(effect)
