# Act - 行动/动作系统
class_name Act
extends Resource

# 行动类型枚举
enum ActType {
	IMMEDIATE = 0,		# 立即执行
	DELAYED = 10,		# 延迟执行
	CONDITIONAL = 20,	# 条件执行
	RECURRING = 30,		# 重复执行
}

# 执行状态枚举
enum ExecutionState {
	PENDING = 0,		# 等待执行
	EXECUTING = 10,		# 正在执行
	COMPLETED = 20,		# 执行完成
	FAILED = 30,		# 执行失败
	CANCELLED = 40,		# 已取消
}

@export var act_type: ActType = ActType.IMMEDIATE		# 行动类型
@export var label: String = ""							# 显示标签
@export var description: String = ""					# 描述文本
@export var icon: Texture2D								# 行动图标

# 执行条件
@export_group("执行条件")
@export var requirements: Array[Test] = []				# 前置条件
@export var target_fragment: Fragment					# 目标Fragment
@export var cost_requirements: Dictionary = {}			# 消耗要求（Fragment -> 数量）

# 效果相关
@export_group("效果")
@export var modifiers: Array[ActModifier] = []			# 行动修改器
@export var card_mutations: Array[CardModifier] = []	# 卡牌突变
@export var table_effects: Array[TableModifier] = []	# 桌面效果
@export var deck_operations: Array[DeckModifier] = []	# 牌库操作

# 时间和重复
@export_group("时间控制")
@export var delay_turns: int = 0						# 延迟回合数
@export var max_executions: int = 1					# 最大执行次数
@export var cooldown_turns: int = 0					# 冷却回合数

# 内部状态
var _execution_state: ExecutionState = ExecutionState.PENDING
var _execution_count: int = 0
var _last_execution_turn: int = -1
var _creation_turn: int = 0

# 检查是否可以执行
func can_execute(context: Context) -> bool:
	if not context:
		return false
	
	# 检查执行状态
	if _execution_state == ExecutionState.EXECUTING:
		return false
	
	if _execution_state == ExecutionState.COMPLETED and max_executions > 0:
		if _execution_count >= max_executions:
			return false
	
	if _execution_state == ExecutionState.CANCELLED or _execution_state == ExecutionState.FAILED:
		return false
	
	# 检查延迟
	var current_turn = context.get_turn_count()
	if delay_turns > 0 and (current_turn - _creation_turn) < delay_turns:
		return false
	
	# 检查冷却
	if cooldown_turns > 0 and _last_execution_turn >= 0:
		if (current_turn - _last_execution_turn) < cooldown_turns:
			return false
	
	# 检查前置条件
	for requirement in requirements:
		if requirement and not requirement.test(context):
			return false
	
	# 检查消耗要求
	if not check_cost_requirements(context):
		return false
	
	return true

# 执行行动
func execute(context: Context) -> bool:
	if not can_execute(context):
		return false
	
	_execution_state = ExecutionState.EXECUTING
	var success = true
	
	print("执行行动: ", get_display_name())
	
	try:
		# 消耗资源
		consume_costs(context)
		
		# 执行所有修改器
		for modifier in modifiers:
			if modifier:
				var computed = modifier.evaluate(context)
				computed.execute()
		
		# 执行卡牌突变
		for mutation in card_mutations:
			if mutation:
				var computed = mutation.evaluate(context)
				computed.execute()
		
		# 执行桌面效果
		for table_effect in table_effects:
			if table_effect:
				var computed = table_effect.evaluate(context)
				computed.execute()
		
		# 执行牌库操作
		for deck_op in deck_operations:
			if deck_op:
				var computed = deck_op.evaluate(context)
				computed.execute()
		
		# 更新执行状态
		_execution_count += 1
		_last_execution_turn = context.get_turn_count()
		
		# 检查是否完成
		if max_executions > 0 and _execution_count >= max_executions:
			_execution_state = ExecutionState.COMPLETED
		else:
			_execution_state = ExecutionState.PENDING
		
		EventBus.emit_signal("act_executed", self, context)
		
	except:
		_execution_state = ExecutionState.FAILED
		success = false
		print("行动执行失败: ", get_display_name())
		EventBus.emit_signal("act_failed", self, context)
	
	return success

# 检查消耗要求
func check_cost_requirements(context: Context) -> bool:
	for fragment in cost_requirements:
		var required_count = cost_requirements[fragment]
		var available_count = context.count(fragment, 0)
		
		if available_count < required_count:
			return false
	
	return true

# 消耗资源
func consume_costs(context: Context) -> void:
	for fragment in cost_requirements:
		var cost_count = cost_requirements[fragment]
		
		# 这里需要实际的消耗逻辑
		# 暂时只是记录消耗，具体实现需要根据游戏机制
		print("消耗资源: ", fragment.get_display_name(), " x", cost_count)

# 取消行动
func cancel(context: Context = null) -> void:
	_execution_state = ExecutionState.CANCELLED
	
	print("取消行动: ", get_display_name())
	EventBus.emit_signal("act_cancelled", self, context)

# 重置行动状态
func reset() -> void:
	_execution_state = ExecutionState.PENDING
	_execution_count = 0
	_last_execution_turn = -1
	_creation_turn = 0

# 设置创建回合
func set_creation_turn(turn: int) -> void:
	_creation_turn = turn

# 获取显示信息
func get_display_name() -> String:
	if label:
		return label
	return "Act_" + str(get_instance_id())

func get_execution_description() -> String:
	var desc = "执行次数: " + str(_execution_count)
	if max_executions > 0:
		desc += "/" + str(max_executions)
	
	if delay_turns > 0:
		desc += "\n延迟: " + str(delay_turns) + " 回合"
	
	if cooldown_turns > 0:
		desc += "\n冷却: " + str(cooldown_turns) + " 回合"
	
	return desc

func get_state_description() -> String:
	match _execution_state:
		ExecutionState.PENDING:
			return "等待执行"
		ExecutionState.EXECUTING:
			return "正在执行"
		ExecutionState.COMPLETED:
			return "执行完成"
		ExecutionState.FAILED:
			return "执行失败"
		ExecutionState.CANCELLED:
			return "已取消"
		_:
			return "未知状态"

func get_type_description() -> String:
	match act_type:
		ActType.IMMEDIATE:
			return "立即执行"
		ActType.DELAYED:
			return "延迟执行"
		ActType.CONDITIONAL:
			return "条件执行"
		ActType.RECURRING:
			return "重复执行"
		_:
			return "未知类型"

# 状态查询
func is_pending() -> bool:
	return _execution_state == ExecutionState.PENDING

func is_executing() -> bool:
	return _execution_state == ExecutionState.EXECUTING

func is_completed() -> bool:
	return _execution_state == ExecutionState.COMPLETED

func is_failed() -> bool:
	return _execution_state == ExecutionState.FAILED

func is_cancelled() -> bool:
	return _execution_state == ExecutionState.CANCELLED

func can_execute_more() -> bool:
	return max_executions <= 0 or _execution_count < max_executions

# 验证行动配置
func is_valid() -> bool:
	return not modifiers.is_empty() or not card_mutations.is_empty() or not table_effects.is_empty() or not deck_operations.is_empty()

# 调试信息
func get_debug_info() -> Dictionary:
	return {
		"label": label,
		"type": get_type_description(),
		"state": get_state_description(),
		"execution_count": _execution_count,
		"max_executions": max_executions,
		"creation_turn": _creation_turn,
		"last_execution_turn": _last_execution_turn,
		"delay_turns": delay_turns,
		"cooldown_turns": cooldown_turns,
		"requirements": requirements.size(),
		"modifiers": modifiers.size(),
		"cost_requirements": cost_requirements.size()
	}