# Context - 游戏执行上下文
class_name Context
extends RefCounted

# 上下文引用
var scope: Node								# 作用域节点（通常是游戏主界面或卡桌）
var matches: Array = []						# 匹配的对象列表

# 游戏状态
var _warmth: int = 0						# 当前热度值
var _turn_count: int = 0					# 回合计数
var _fragments_created: Dictionary = {}		# 本回合创建的Fragment计数
var _rules_executed: Array[Rule] = []		# 本回合执行的规则

# 延迟执行队列
var _deferred_modifiers: Array = []			# 延迟执行的修改器
var _deferred_rules: Array = []				# 延迟执行的规则

# 构造函数
func _init(scope_node: Node = null):
	scope = scope_node

# 热度系统
func get_warmth() -> int:
	return _warmth

func set_warmth(value: int) -> void:
	var old_warmth = _warmth
	_warmth = max(0, value)
	
	if _warmth != old_warmth:
		EventBus.emit_signal("warmth_changed", _warmth, old_warmth)

func add_warmth(amount: int) -> void:
	set_warmth(_warmth + amount)

func spend_warmth(amount: int) -> bool:
	if _warmth >= amount:
		set_warmth(_warmth - amount)
		return true
	return false

# 回合系统
func get_turn_count() -> int:
	return _turn_count

func advance_turn() -> void:
	_turn_count += 1
	_fragments_created.clear()
	_rules_executed.clear()
	
	# 执行回合开始的延迟操作
	execute_deferred_actions()
	
	EventBus.emit_signal("turn_advanced", _turn_count)

# Fragment计数和创建
func count(fragment: Fragment, location: int = 0) -> int:
	if not fragment or not scope:
		return 0
	
	var count = 0
	
	# 根据location查找不同位置的Fragment
	match location:
		0:  # 所有位置
			count += count_in_all_locations(fragment)
		1:  # 手牌
			count += count_in_hand(fragment)
		2:  # 桌面
			count += count_on_table(fragment)
		3:  # 牌库
			count += count_in_deck(fragment)
		_:
			print("警告: 未知的location值: ", location)
	
	return count

func count_in_all_locations(fragment: Fragment) -> int:
	return count_in_hand(fragment) + count_on_table(fragment) + count_in_deck(fragment)

func count_in_hand(fragment: Fragment) -> int:
	var count = 0
	if scope.has_method("get_hand_cards"):
		var hand_cards = scope.get_hand_cards()
		for card_viz in hand_cards:
			if card_viz and card_viz.card and card_viz.card.contains_fragment(fragment):
				count += 1
	return count

func count_on_table(fragment: Fragment) -> int:
	var count = 0
	if scope.has_method("get_table_cards"):
		var table_cards = scope.get_table_cards()
		for card_viz in table_cards:
			if card_viz and card_viz.card and card_viz.card.contains_fragment(fragment):
				count += 1
	return count

func count_in_deck(fragment: Fragment) -> int:
	var count = 0
	if scope.has_method("get_deck_cards"):
		var deck_cards = scope.get_deck_cards()
		for card in deck_cards:
			if card and card.contains_fragment(fragment):
				count += 1
	return count

# Fragment创建
func create_fragment(fragment: Fragment, location: int = 2) -> bool:
	if not fragment or not scope:
		return false
	
	# 记录创建统计
	var fragment_id = fragment.get_instance_id()
	if fragment_id in _fragments_created:
		_fragments_created[fragment_id] += 1
	else:
		_fragments_created[fragment_id] = 1
	
	print("创建Fragment: ", fragment.get_display_name(), " 在位置 ", location)
	
	# 根据location创建到不同位置
	match location:
		1:  # 手牌
			return create_to_hand(fragment)
		2:  # 桌面
			return create_to_table(fragment)
		3:  # 牌库
			return create_to_deck(fragment)
		_:
			print("错误: 无效的创建位置: ", location)
			return false

func create_to_hand(fragment: Fragment) -> bool:
	if scope.has_method("add_to_hand"):
		scope.add_to_hand(fragment)
		return true
	return false

func create_to_table(fragment: Fragment) -> bool:
	if scope.has_method("add_to_table"):
		scope.add_to_table(fragment)
		return true
	return false

func create_to_deck(fragment: Fragment) -> bool:
	if scope.has_method("add_to_deck"):
		scope.add_to_deck(fragment)
		return true
	return false

# 规则执行跟踪
func record_rule_execution(rule: Rule) -> void:
	if rule and rule not in _rules_executed:
		_rules_executed.append(rule)

func was_rule_executed(rule: Rule) -> bool:
	return rule in _rules_executed

func get_executed_rules() -> Array[Rule]:
	return _rules_executed.duplicate()

# 延迟执行系统
func defer_modifier(modifier: ActModifier) -> void:
	if modifier:
		_deferred_modifiers.append(modifier)

func defer_rule(rule: Rule) -> void:
	if rule:
		_deferred_rules.append(rule)

func execute_deferred_actions() -> void:
	# 执行延迟的修改器
	for modifier in _deferred_modifiers:
		if modifier:
			var computed = modifier.evaluate(self)
			computed.execute()
	_deferred_modifiers.clear()
	
	# 执行延迟的规则
	for rule in _deferred_rules:
		if rule and rule.can_execute(self):
			rule.execute(self)
			record_rule_execution(rule)
	_deferred_rules.clear()

# 匹配系统
func set_matches(new_matches: Array) -> void:
	matches = new_matches.duplicate()

func add_match(match_object) -> void:
	if match_object not in matches:
		matches.append(match_object)

func clear_matches() -> void:
	matches.clear()

func has_matches() -> bool:
	return not matches.is_empty()

# 查询方法
func get_cards_with_aspect(aspect: Aspect) -> Array:
	var result = []
	
	if scope and scope.has_method("get_all_cards"):
		var all_cards = scope.get_all_cards()
		for card_viz in all_cards:
			if card_viz and card_viz.card and card_viz.card.has_aspect(aspect):
				result.append(card_viz)
	
	return result

func get_cards_matching_test(test: Test) -> Array:
	var result = []
	
	if scope and scope.has_method("get_all_cards"):
		var all_cards = scope.get_all_cards()
		for card_viz in all_cards:
			if card_viz and card_viz.card:
				# 创建临时上下文用于测试
				var temp_context = Context.new(scope)
				temp_context.matches = [card_viz]
				
				if test.test(temp_context):
					result.append(card_viz)
	
	return result

# 状态重置
func reset() -> void:
	_warmth = 0
	_turn_count = 0
	_fragments_created.clear()
	_rules_executed.clear()
	_deferred_modifiers.clear()
	_deferred_rules.clear()
	matches.clear()

# 调试信息
func get_debug_info() -> Dictionary:
	return {
		"warmth": _warmth,
		"turn_count": _turn_count,
		"fragments_created_this_turn": _fragments_created.size(),
		"rules_executed_this_turn": _rules_executed.size(),
		"deferred_modifiers": _deferred_modifiers.size(),
		"deferred_rules": _deferred_rules.size(),
		"matches": matches.size(),
		"scope_valid": scope != null
	}

func print_debug_info() -> void:
	var info = get_debug_info()
	print("=== Context Debug Info ===")
	for key in info:
		print(key, ": ", info[key])
	print("==========================")
