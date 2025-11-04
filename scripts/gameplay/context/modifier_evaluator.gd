extends RefCounted
class_name ModifierEvaluator

# Modifier Evaluator 服务：将 Resource 形式的 modifiers（ActModifier / CardModifier / ...）
# 评估为可执行的命令对象（ModifierCommand），并把命令追加到 ContextData 的相应队列中。
#
# 设计要点：
# - 使用 FragmentResolver 提供的解析/计数工具来计算目标与数量。
# - 对命令对象使用可选的 PoolManager 池（若提供则从池中获取/回收）。
# - 按 AGENTS.md：使用断言暴露契约问题，禁止静默回退。

var _fragment_resolver: FragmentResolver = FragmentResolver.new()

var _ActCmdClass = preload("res://scripts/system/core/commands/act_modifier_command.gd")
var _CardCmdClass = preload("res://scripts/system/core/commands/card_modifier_command.gd")
var _DeckCmdClass = preload("res://scripts/system/core/commands/deck_modifier_command.gd")
var _PathCmdClass = preload("res://scripts/system/core/commands/path_modifier_command.gd")
var _TableCmdClass = preload("res://scripts/system/core/commands/table_modifier_command.gd")

func _acquire_cmd(class_ref, pool: PoolManager) -> Object:
	# 从池中获取命令对象（若提供 pool），否则直接 new
	if pool != null:
		return pool.acquire(class_ref)
	return class_ref.new()

func evaluate_act_modifiers(mods: Array, data, pool: PoolManager = null) -> void:
	assert(mods != null and data != null)
	for mod in mods:
		assert(mod != null)
		# 解析目标与数量
		var target = _fragment_resolver.resolve_target(mod.fragment, data)
		var level = _fragment_resolver.count(mod.fragment, mod.level, data)
		# 约定：若 level < 0 则视为 all 标志（Grab 操作使用）
		var all_flag = mod.level < 0
		var cmd = _acquire_cmd(_ActCmdClass, pool)
		cmd.setup(mod.op, target, level, all_flag)
		data.act_modifiers.append(cmd)

func evaluate_card_modifiers(mods: Array, data, pool: PoolManager = null) -> void:
	assert(mods != null and data != null)
	for mod in mods:
		assert(mod != null)
		var target = _fragment_resolver.resolve_target(mod.target, data)
		var target_cards = _fragment_resolver.resolve_target_cards(target, data.scope)
		# what 可为 fragment 或 cards 容器；按 CardModifierCommand 的期望构造对应结构
		var what = null
		if mod.fragment != null:
			var frag = _fragment_resolver.resolve_fragment(mod.fragment, data)
			what = {"fragment": frag}
		elif mod.reference != null:
			var ref_frag = _fragment_resolver.resolve_fragment(mod.reference, data)
			what = {"fragment": ref_frag}
		# 计算 level（允许倍数关系）
		var level = _fragment_resolver.count(mod.fragment, mod.level, data)
		var cmd = _acquire_cmd(_CardCmdClass, pool)
		cmd.setup(mod.op, target_cards, what, level)
		data.card_modifiers.append(cmd)

func evaluate_deck_modifiers(mods: Array, data, pool: PoolManager = null) -> void:
	assert(mods != null and data != null)
	for mod in mods:
		assert(mod != null)
		var deck = mod.deck
		var target = null
		if mod.deck_from != null:
			target = _fragment_resolver.resolve_target(mod.deck_from, data)
		elif mod.fragment != null:
			target = _fragment_resolver.resolve_target(mod.fragment, data)
		var cmd = _acquire_cmd(_DeckCmdClass, pool)
		cmd.setup(mod.op, deck, target)
		data.deck_modifiers.append(cmd)

func evaluate_path_modifiers(mods: Array, data, pool: PoolManager = null) -> void:
	assert(mods != null and data != null)
	for mod in mods:
		assert(mod != null)
		var cmd = _acquire_cmd(_PathCmdClass, pool)
		cmd.setup(mod.op, mod.act)
		data.path_modifiers.append(cmd)

func evaluate_table_modifiers(mods: Array, data, pool: PoolManager = null) -> void:
	assert(mods != null and data != null)
	for mod in mods:
		assert(mod != null)
		var cmd = _acquire_cmd(_TableCmdClass, pool)
		cmd.setup(mod.op, mod.act)
		data.table_modifiers.append(cmd)

func evaluate_all_from_actdata(act_data, data, pool: PoolManager = null) -> void:
	# Convenience helper：把一个 ActData 的所有 modifier 评估并追加到 ContextData
	assert(act_data != null and data != null)
	if act_data.act_modifiers != null:
		evaluate_act_modifiers(act_data.act_modifiers, data, pool)
	if act_data.card_modifiers != null:
		evaluate_card_modifiers(act_data.card_modifiers, data, pool)
	if act_data.table_modifiers != null:
		evaluate_table_modifiers(act_data.table_modifiers, data, pool)
	if act_data.path_modifiers != null:
		evaluate_path_modifiers(act_data.path_modifiers, data, pool)
	if act_data.deck_modifiers != null:
		evaluate_deck_modifiers(act_data.deck_modifiers, data, pool)
