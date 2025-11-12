extends RefCounted
class_name Context

# ===============================
# Context：Rule 执行上下文，管理 modifiers 并在 dispose 时应用它们
# ===============================
#region 属性
# 核心字段
var act_logic: ActLogic = null
var scope: FragTree = null
var this_aspect: FragmentData = null
var this_card: CardViz = null
var matches: Array[CardViz] = []

# Modifier 列表
var act_modifiers: Array[ActModifierCommand]
var card_modifiers: Array = [CardModifierCommand]
var table_modifiers: Array = [TableModifierCommand]
var path_modifiers: Array = [PathModifierCommand]
var deck_modifiers: Array = [DeckModifierCommand]

# 待销毁的卡牌列表
var _to_destroy: Array[CardViz] = []
var _disposed: bool = false
#endregion


#region 构造函数

## 从另一个 Context 复制
func _init_from_context(context: Context, keep_matches: bool = false) -> void:
	if context != null:
		_init_from_act_logic(context.act_logic, keep_matches)

## 从 FragTree 构造
func _init_from_frag_tree(fragments: FragTree, keep_matches: bool = false) -> void:
	if fragments != null:
		scope = fragments
		_init_matches(keep_matches)

## 从 ActLogic 构造
func _init_from_act_logic(act_logic_arg: ActLogic, keep_matches: bool = false) -> void:
	_init_from_frag_tree(act_logic_arg.frag_tree, keep_matches)
	if act_logic_arg != null:
		act_logic = act_logic_arg

## 从 CardViz 构造
func _init_from_card_viz(card_viz: CardViz, keep_matches: bool = false) -> void:
	_init_from_frag_tree(card_viz.frag_tree, keep_matches)
	if card_viz != null:
		this_card = card_viz


## 初始化 matches
func _init_matches(keep_matches: bool) -> void:
	if scope == null:
		return
	matches.clear()
	if keep_matches:
		if scope.matches != null:
			matches.assign(scope.matches)
	else:
		matches.assign(scope.cards())

#endregion

#region 静态工厂方法

## 从 ActLogic 获取 Context
static func acquire_from_act_logic(act_logic_arg: ActLogic, keep_matches: bool = false) -> Context:
	var ctx = Context.new()
	ctx._init_from_act_logic(act_logic_arg, keep_matches)
	return ctx

## 从 FragTree 获取 Context
static func acquire_from_frag_tree(frag_tree: FragTree, keep_matches: bool = false) -> Context:
	var ctx = Context.new()
	ctx._init_from_frag_tree(frag_tree, keep_matches)
	return ctx

## 从 CardViz 获取 Context
static func acquire_from_card_viz(card_viz: CardViz, keep_matches: bool = false) -> Context:
	var ctx = Context.new()
	ctx._init_from_card_viz(card_viz, keep_matches)
	return ctx

## 从另一个 Context 复制
static func acquire_from_context(context: Context, keep_matches: bool = false) -> Context:
	var ctx = Context.new()
	ctx._init_from_context(context, keep_matches)
	return ctx

#endregion

#region Dispose 模式

## 执行所有 modifiers 并销毁待销毁的卡牌
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	
	# 执行所有 modifiers
	for act_modifier in act_modifiers:
		act_modifier.execute(self)
	
	for card_modifier in card_modifiers:
		card_modifier.execute(self)
	
	for table_modifier in table_modifiers:
		table_modifier.execute(self)
	
	for path_modifier in path_modifiers:
		path_modifier.execute(self)
	
	for deck_modifier in deck_modifiers:
		deck_modifier.execute(self)
	
	# 销毁待销毁的卡牌
	for card_viz in _to_destroy:
		card_viz.destroy()

## 释放资源（不执行 modifiers）
func release() -> void:
	act_modifiers.clear()
	card_modifiers.clear()
	table_modifiers.clear()
	path_modifiers.clear()
	deck_modifiers.clear()
	_to_destroy.clear()
	_disposed = true

#endregion

#region 操作方法

## 标记卡牌待销毁
func destroy(card_viz: CardViz) -> void:
	if card_viz != null:
		_to_destroy.append(card_viz)

## 重置 matches 为 scope 中的所有卡牌
func reset_matches() -> void:
	matches.clear()
	if scope != null:
		matches.assign(scope.cards())

## 保存 matches 到 scope
func save_matches() -> void:
	if scope != null:
		scope.matches = matches

#endregion

#region 解析方法

## 根据 ReqLoc 解析 scope
func resolve_scope(loc: GameEnums.ReqLoc) -> FragTree:
	match loc:
		GameEnums.ReqLoc.Scope:
			return scope
		GameEnums.ReqLoc.Slots:
			return act_logic.slots_frag_tree if act_logic else null
		# 目前不需要Table
		GameEnums.ReqLoc.Table:
			return null
		GameEnums.ReqLoc.Heap:
			return Manager.GM.heap if Manager.GM else null
		GameEnums.ReqLoc.Free, GameEnums.ReqLoc.Anywhere:
			return Manager.GM.root if Manager.GM else null
		_:
			return scope

## 计算 fragment 的数量（支持特殊 fragment）
func count(frag: FragmentData, level: int) -> int:
	if frag == null:
		return level
	
	if Manager.GM == null:
		return level * scope.count_fragment(frag) if scope else level
	
	# 处理特殊 fragments
	if frag == Manager.GM.this_aspect:
		return level * scope.count_fragment(this_aspect)
	elif frag == Manager.GM.this_card:
		return level * scope.count_card(this_card.card)
	elif frag == Manager.GM.matched_card:
		return level * matches.size()
	elif frag == Manager.GM.memory_fragment:
		return level * scope.count_fragment(scope.memory_fragment)
	else:
		return level * scope.count_fragment(frag)

## 解析 Fragment（处理特殊 fragment）
func resolve_fragment(frag: FragmentData) -> FragmentData:
	if frag == null:
		return null
	
	if Manager.GM == null:
		return frag
	
	# 处理特殊 fragments
	if frag == Manager.GM.this_aspect:
		return this_aspect
	elif frag == Manager.GM.this_card:
		return this_card.card_data
	elif frag == Manager.GM.memory_fragment:
		return scope.memory_fragment
	else:
		return frag

## 解析 Target（处理特殊 fragment）
func resolve_target(frag: FragmentData) -> Target:
	if frag == null:
		return null

	# 处理特殊 fragments
	if frag == Manager.GM.this_aspect:
		return Target.acquire_from_fragment(this_aspect)
	elif frag == Manager.GM.this_card:
		return Target.acquire_from_card_viz(this_card)
	elif frag == Manager.GM.matched_card:
		return Target.acquire_from_cards(matches)
	elif frag == Manager.GM.memory_fragment:
		return Target.acquire_from_fragment(scope.memory_fragment)
	else:
		return Target.acquire_from_fragment(frag)

## 解析 Target 为 CardViz 列表
func resolve_target_cards(target: Target, target_scope: FragTree) -> Array[CardViz]:
	if target == null:
		return []
	
	if target.cards != null:
		return target.cards
	elif target.fragment != null:
		if target_scope == null:
			return []

		if target.fragment is CardData:
			return target_scope.find_all_by_card(target.fragment)
		elif target.fragment is AspectData:
			return target_scope.find_all_by_aspect(target.fragment)
	
	return []

#endregion
