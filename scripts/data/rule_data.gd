class_name RuleData
extends Resource

#region 属性定义
@export var invert : bool
## 所有 TestData 都必须通过
@export var tests : Array[TestData]
## 所有 RuleData 都必须通过
@export var and_rules : Array[RuleData]
## 任一 RuleData 通过
@export var or_rules : Array[RuleData]

@export_category("Modifiers")
@export var act_modifiers: Array[ActModifier]
@export var card_modifiers: Array[CardModifier]
@export var table_modifiers: Array[TableModifier]
@export var path_modifiers: Array[PathModifier]
@export var deck_modifiers: Array[DeckModifier]
@export_category("Furthermore")
@export var furthermore: Array[RuleData]

@export_category("Texts")
@export var text: TextData
#endregion

#region 公开方法
func evaluate(context: Context) -> bool:
	return RuleData.evaluate_all(context, tests, and_rules, or_rules, invert)

func execute(context: Context) -> void:
	RuleData.execute_all(context, act_modifiers, card_modifiers, table_modifiers, path_modifiers, deck_modifiers, furthermore)

func run(context: Context) -> bool:
	if context == null:
		return false
	if not evaluate(context):
		return false
	else:
		execute(context)
		return true
#endregion

#region 静态方法
static func evaluate_all(context: Context, 
						_tests: Array[TestData], 
						_and_rules: Array[RuleData], 
						_or_rules: Array[RuleData], 
						_invert: bool, 
						_force: bool = false) -> bool:
	if _invert and not _force:
		return not RuleData.evaluate_all(context, _tests, _and_rules, _or_rules, false)

	# 运行 tests
	for test in _tests:
		var r = test.attempt(context)
		if not _force and (not test.can_fail) and r == false:
			return false
	
	# force 仅用于强制保存匹配等场景
	if _force:
		return true

	# and 规则：每个必须通过（在独立 Context 副本中评估）
	for rule in _and_rules:
		if rule == null:
			continue
		var context2 = Context.acquire_from_context(context)
		if rule.evaluate(context2):
			context2.dispose()
			return false
		context2.dispose()

	# or 规则：任一通过则通过
	for rule in _or_rules:
		if rule == null:
			continue
		var context2 = Context.acquire_from_context(context)
		if rule.evaluate(context2):
			context2.dispose()
			return true
		context2.dispose()

	return _or_rules.size() == 0

static func execute_all(context: Context, 
						act_mods: Array[ActModifier], 
						card_mods: Array[CardModifier], 
						table_mods: Array[TableModifier], 
						path_mods: Array[PathModifier], 
						deck_mods: Array[DeckModifier], 
						furthermore_rules: Array[RuleData]) -> void:
	if context == null:
		if context:
			context.reset_matches()
		return

	# 将评估过的运行时 modifier 放入 context 的集合中（期待 Context 中字段名与 C# 保持一致）
	for act_mod in act_mods:
		context.act_modifiers.append(act_mod.evaluate(context))

	for card_mod in card_mods:
		context.card_modifiers.append(card_mod.evaluate(context))

	for table_mod in table_mods:
		context.table_modifiers.append(table_mod.evaluate(context))

	for path_mod in path_mods:
		context.path_modifiers.append(path_mod.evaluate(context))

	for deck_mod in deck_mods:
		context.deck_modifiers.append(deck_mod.evaluate(context))

	# furthermore：在运行每条规则前重置 matches 并运行
	for rule in furthermore_rules:
		if rule == null:
			continue
		context.reset_matches()
		rule.run(context)

#endregion
