# Token - 令牌系统
class_name Token
extends Fragment

# 令牌类型枚举
enum TokenType {
	RESOURCE = 0,		# 资源令牌
	STATUS = 10,		# 状态令牌
	COUNTER = 20,		# 计数令牌
	MARKER = 30,		# 标记令牌
	CURRENCY = 40,		# 货币令牌
}

# 令牌持续性枚举
enum Persistence {
	PERMANENT = 0,		# 永久令牌
	SESSION = 10,		# 会话令牌（游戏结束时清除）
	TURN = 20,			# 回合令牌（回合结束时清除）
	TEMPORARY = 30,		# 临时令牌（使用后清除）
}

@export var token_type: TokenType = TokenType.RESOURCE	# 令牌类型
@export var persistence: Persistence = Persistence.PERMANENT	# 持续性

# 数值相关
@export_group("数值")
@export var value: int = 1							# 令牌数值
@export var max_value: int = -1						# 最大数值（-1表示无限制）
@export var min_value: int = 0						# 最小数值
@export var auto_destroy_at_zero: bool = true		# 数值为0时自动销毁

# 增长和衰减
@export_group("变化")
@export var growth_rate: float = 0.0				# 每回合增长率
@export var decay_rate: float = 0.0					# 每回合衰减率
@export var growth_cap: int = -1					# 增长上限

# 转换相关
@export_group("转换")
@export var conversion_rate: Dictionary = {}		# 转换汇率（其他令牌类型 -> 比率）
@export var can_be_converted: bool = true			# 是否可以被转换
@export var auto_convert_conditions: Array[Test] = []	# 自动转换条件

# 使用相关
@export_group("使用")
@export var consumable: bool = false				# 是否可消耗
@export var use_effects: Array[ActModifier] = []	# 使用效果
@export var on_gain_effects: Array[ActModifier] = []	# 获得时效果
@export var on_lose_effects: Array[ActModifier] = []	# 失去时效果

# 内部状态
var _current_value: int = 1							# 当前数值
var _last_turn_update: int = -1						# 上次更新的回合

func _init():
	super._init()
	_current_value = value

# 数值操作
func get_current_value() -> int:
	return _current_value

func set_current_value(new_value: int, context: Context = null) -> void:
	var old_value = _current_value
	var clamped_value = new_value
	
	# 应用数值限制
	if max_value >= 0:
		clamped_value = min(clamped_value, max_value)
	clamped_value = max(clamped_value, min_value)
	
	if clamped_value != _current_value:
		_current_value = clamped_value
		
		# 触发相应效果
		if context:
			if _current_value > old_value:
				# 数值增加，触发获得效果
				for effect in on_gain_effects:
					if effect:
						var computed_effect = effect.evaluate(context)
						computed_effect.execute()
			elif _current_value < old_value:
				# 数值减少，触发失去效果
				for effect in on_lose_effects:
					if effect:
						var computed_effect = effect.evaluate(context)
						computed_effect.execute()
		
		# 发送事件
		EventBus.emit_signal("token_value_changed", self, old_value, _current_value)
		
		# 检查是否需要自动销毁
		if auto_destroy_at_zero and _current_value <= 0:
			destroy_token(context)

func add_value(amount: int, context: Context = null) -> void:
	set_current_value(_current_value + amount, context)

func subtract_value(amount: int, context: Context = null) -> void:
	set_current_value(_current_value - amount, context)

func multiply_value(multiplier: float, context: Context = null) -> void:
	set_current_value(int(_current_value * multiplier), context)

# 使用令牌
func use(amount: int = 1, context: Context = null) -> bool:
	if not consumable:
		print("警告: 令牌不可消耗: ", get_display_name())
		return false
	
	if _current_value < amount:
		print("警告: 令牌数量不足: ", get_display_name(), " 需要", amount, " 当前", _current_value)
		return false
	
	# 消耗令牌
	subtract_value(amount, context)
	
	# 触发使用效果
	if context:
		for effect in use_effects:
			if effect:
				var computed_effect = effect.evaluate(context)
				computed_effect.execute()
	
	print("使用令牌: ", get_display_name(), " x", amount)
	EventBus.emit_signal("token_used", self, amount)
	
	return true

# 转换令牌
func convert_to(target_token: Token, amount: int = 1, context: Context = null) -> int:
	if not can_be_converted:
		return 0
	
	if not target_token or target_token == self:
		return 0
	
	# 检查转换汇率
	var target_type_name = Token.TokenType.keys()[target_token.token_type]
	var conversion_ratio = 1.0
	
	if target_type_name in conversion_rate:
		conversion_ratio = conversion_rate[target_type_name]
	
	# 计算转换数量
	var max_convertible = min(amount, _current_value)
	var converted_amount = int(max_convertible * conversion_ratio)
	
	if converted_amount <= 0:
		return 0
	
	# 执行转换
	subtract_value(max_convertible, context)
	target_token.add_value(converted_amount, context)
	
	print("令牌转换: ", get_display_name(), " x", max_convertible, " -> ", target_token.get_display_name(), " x", converted_amount)
	EventBus.emit_signal("token_converted", self, target_token, max_convertible, converted_amount)
	
	return converted_amount

# 回合更新
func update_turn(turn_number: int, context: Context = null) -> void:
	if _last_turn_update >= turn_number:
		return  # 已经更新过这个回合
	
	_last_turn_update = turn_number
	
	# 应用增长和衰减
	if growth_rate > 0:
		var growth_amount = int(_current_value * growth_rate)
		if growth_cap > 0:
			growth_amount = min(growth_amount, growth_cap)
		if growth_amount > 0:
			add_value(growth_amount, context)
	
	if decay_rate > 0:
		var decay_amount = int(_current_value * decay_rate)
		if decay_amount > 0:
			subtract_value(decay_amount, context)
	
	# 检查自动转换条件
	check_auto_conversion(context)
	
	# 检查持续性
	check_persistence(turn_number, context)

# 检查自动转换
func check_auto_conversion(context: Context) -> void:
	if not context or auto_convert_conditions.is_empty():
		return
	
	for condition in auto_convert_conditions:
		if condition and condition.test(context):
			# 触发自动转换（这里需要根据具体游戏逻辑实现）
			print("令牌满足自动转换条件: ", get_display_name())
			break

# 检查持续性
func check_persistence(turn_number: int, context: Context) -> void:
	var should_destroy = false
	
	match persistence:
		Persistence.TURN:
			# 回合令牌在回合结束时销毁
			should_destroy = true
		Persistence.TEMPORARY:
			# 临时令牌根据其他条件销毁
			pass
		_:
			# 其他类型不在此处销毁
			pass
	
	if should_destroy:
		destroy_token(context)

# 销毁令牌
func destroy_token(context: Context = null) -> void:
	print("销毁令牌: ", get_display_name())
	EventBus.emit_signal("token_destroyed", self)
	
	# 这里可以添加额外的清理逻辑

# 状态查询
func is_empty() -> bool:
	return _current_value <= 0

func is_full() -> bool:
	return max_value >= 0 and _current_value >= max_value

func can_afford(cost: int) -> bool:
	return _current_value >= cost

# 重写Fragment方法
func get_display_name() -> String:
	var base_name = super.get_display_name()
	if _current_value != 1:
		return base_name + " x" + str(_current_value)
	return base_name

func get_description() -> String:
	var desc = super.get_description()
	
	# 添加令牌特定信息
	desc += "\n类型: " + get_type_description()
	desc += "\n数值: " + str(_current_value)
	
	if max_value >= 0:
		desc += "/" + str(max_value)
	
	if growth_rate > 0:
		desc += "\n增长: +" + str(int(growth_rate * 100)) + "%/回合"
	
	if decay_rate > 0:
		desc += "\n衰减: -" + str(int(decay_rate * 100)) + "%/回合"
	
	if consumable:
		desc += "\n可消耗"
	
	return desc

func get_type_description() -> String:
	match token_type:
		TokenType.RESOURCE:
			return "资源令牌"
		TokenType.STATUS:
			return "状态令牌"
		TokenType.COUNTER:
			return "计数令牌"
		TokenType.MARKER:
			return "标记令牌"
		TokenType.CURRENCY:
			return "货币令牌"
		_:
			return "未知令牌"

func get_persistence_description() -> String:
	match persistence:
		Persistence.PERMANENT:
			return "永久"
		Persistence.SESSION:
			return "会话"
		Persistence.TURN:
			return "回合"
		Persistence.TEMPORARY:
			return "临时"
		_:
			return "未知"

# 验证令牌配置
func is_valid() -> bool:
	return super.is_valid() and min_value >= 0 and (max_value < 0 or max_value >= min_value)

# 调试信息
func get_debug_info() -> Dictionary:
	var info = super.get_debug_info()
	info.merge({
		"token_type": get_type_description(),
		"persistence": get_persistence_description(),
		"current_value": _current_value,
		"value_range": str(min_value) + " - " + (str(max_value) if max_value >= 0 else "∞"),
		"growth_rate": growth_rate,
		"decay_rate": decay_rate,
		"consumable": consumable,
		"last_update_turn": _last_turn_update
	})
	return info
