extends RefCounted
class_name Context

# 池化配置
static var POOL_MAX = 128
static var _pool: Array = []

# 运行时上下文（池化）
var act_logic = null
var scope = null

var this_aspect = null
var this_card = null
var matches: Array = []

# 已评估的可执行命令（命令对象应实现 execute(context) 并提供 release()/dispose()）
var act_modifiers: Array = []
var card_modifiers: Array = []
var table_modifiers: Array = []
var path_modifiers: Array = []
var deck_modifiers: Array = []

# 待销毁的 CardViz 列表（由命令或系统加入）
var _to_destroy: Array = []

# 池管理标记
var _disposed: bool = false
var _pooled: bool = false
var _in_pool: bool = false

# ----------------- Acquire / Init -----------------
static func acquire_from_act_logic(act_logic_arg, keep_matches: bool=false) -> Context:
	var c: Context = _pool.pop_back() if _pool.size() > 0 else Context.new()
	c._in_pool = false
	c._pooled = true
	c._disposed = false
	c._init_from_act_logic(act_logic_arg, keep_matches)
	return c

static func acquire_from_context(src: Context, keep_matches: bool=false) -> Context:
	var c: Context = _pool.pop_back() if _pool.size() > 0 else Context.new()
	c._in_pool = false
	c._pooled = true
	c._disposed = false
	c._init_from_context(src, keep_matches)
	return c

static func acquire_from_frag_tree(frag_tree, keep_matches: bool=false) -> Context:
	var c: Context = _pool.pop_back() if _pool.size() > 0 else Context.new()
	c._in_pool = false
	c._pooled = true
	c._disposed = false
	c._init_from_frag_tree(frag_tree, keep_matches)
	return c

static func acquire_from_card_viz(card_viz, keep_matches: bool=false) -> Context:
	var c: Context = _pool.pop_back() if _pool.size() > 0 else Context.new()
	c._in_pool = false
	c._pooled = true
	c._disposed = false
	c._init_from_card_viz(card_viz, keep_matches)
	return c

func _init_from_act_logic(act_logic_arg, keep_matches: bool=false) -> void:
	act_logic = act_logic_arg
	scope = act_logic_arg.fragTree if act_logic_arg != null and "fragTree" in act_logic_arg else null
	this_aspect = null
	this_card = null
	_matches_init(keep_matches)
	_clear_modifier_lists()
	_to_destroy.clear()

func _init_from_context(src: Context, keep_matches: bool=false) -> void:
	if src == null:
		_init_from_act_logic(null, keep_matches)
		return
	act_logic = src.act_logic
	scope = src.scope
	this_aspect = src.this_aspect
	this_card = src.this_card
	_matches_init(keep_matches)
	_clear_modifier_lists()
	_to_destroy.clear()

func _init_from_frag_tree(frag_tree, keep_matches: bool=false) -> void:
	act_logic = null
	scope = frag_tree
	this_aspect = null
	this_card = null
	_matches_init(keep_matches)
	_clear_modifier_lists()
	_to_destroy.clear()

func _init_from_card_viz(card_viz, keep_matches: bool=false) -> void:
	act_logic = null
	scope = card_viz.frag_tree if card_viz != null and "frag_tree" in card_viz else null
	this_card = card_viz
	this_aspect = null
	_matches_init(keep_matches)
	_clear_modifier_lists()
	_to_destroy.clear()

func _matches_init(keep_matches: bool) -> void:
	if matches == null:
		matches = []
	else:
		matches.clear()
	if scope != null:
		if keep_matches and "matches" in scope:
			matches.append_array(scope.matches)
		elif "cards" in scope:
			matches.append_array(scope.cards)

func _clear_modifier_lists() -> void:
	if act_modifiers == null:
		act_modifiers = []
	else:
		act_modifiers.clear()
	if card_modifiers == null:
		card_modifiers = []
	else:
		card_modifiers.clear()
	if table_modifiers == null:
		table_modifiers = []
	else:
		table_modifiers.clear()
	if path_modifiers == null:
		path_modifiers = []
	else:
		path_modifiers.clear()
	if deck_modifiers == null:
		deck_modifiers = []
	else:
		deck_modifiers.clear()

# ----------------- Release / Dispose -----------------
# release(): 不执行命令，仅清理并回池（若实例来自池）
func release() -> void:
	_clear_for_pool()
	if _pooled and not _in_pool and _pool.size() < POOL_MAX:
		_pool.append(self)
		_in_pool = true
	_pooled = false

# dispose(): 执行收集的命令并回池（或清理）
func dispose() -> void:
	if _disposed:
		return
	_disposed = true

	# 1) 执行收集到的 modifier command（使用 while-pop_back 以避免 duplicate 分配）
	_execute_and_release_list(act_modifiers)
	_execute_and_release_list(card_modifiers)
	_execute_and_release_list(table_modifiers)
	_execute_and_release_list(path_modifiers)
	_execute_and_release_list(deck_modifiers)

	# 2) 销毁 queued card viz（防御式）
	for cv in _to_destroy:
		if cv == null:
			continue
		if typeof(cv) == TYPE_OBJECT:
			if cv.has_method("destroy"):
				cv.destroy()
			elif cv.has_method("Destroy"):
				cv.Destroy()
			elif cv is Node:
				cv.queue_free()
	_to_destroy.clear()

	# 3) 回池或彻底清理
	_dispose_final()

# 以 PascalCase 兼容旧代码
func Dispose() -> void:
	dispose()

func _execute_and_release_list(list_ref: Array) -> void:
	if list_ref == null:
		return
	# 使用 pop_back 回收，避免额外分配
	while list_ref.size() > 0:
		var cmd = list_ref.pop_back()
		if cmd == null:
			continue
		if cmd.has_method("execute"):
			cmd.execute(self)
		# 回收优先调用 release()
		if cmd.has_method("release"):
			cmd.release()
		elif cmd.has_method("dispose"):
			cmd.dispose()
	# 确保空
	list_ref.clear()

func _dispose_final() -> void:
	_clear_for_pool()
	# 池化策略：若为池化实例，回池；否则由 GC 回收
	if _pooled and not _in_pool and _pool.size() < POOL_MAX:
		_pool.append(self)
		_in_pool = true
	else:
		# allow GC: nothing to do
		pass
	# reset flags
	_disposed = false
	_pooled = false

func _clear_for_pool() -> void:
	act_logic = null
	scope = null
	this_aspect = null
	this_card = null
	if matches != null: matches.clear()
	if act_modifiers != null: act_modifiers.clear()
	if card_modifiers != null: card_modifiers.clear()
	if table_modifiers != null: table_modifiers.clear()
	if path_modifiers != null: path_modifiers.clear()
	if deck_modifiers != null: deck_modifiers.clear()
	_to_destroy.clear()

# ----------------- Utility -----------------
func destroy(card_viz) -> void:
	if card_viz != null:
		_to_destroy.append(card_viz)

func Destroy(card_viz) -> void:
	destroy(card_viz)

func reset_matches() -> void:
	if scope != null and "cards" in scope:
		matches.clear()
		matches.append_array(scope.cards)
	else:
		matches.clear()

func save_matches() -> void:
	if scope != null:
		scope.matches = matches

# ----------------- Resolve / Count helpers (兼容原实现) -----------------
func resolve_scope(loc):
	match loc:
		GameEnums.ReqLoc.Scope:
			return scope
		GameEnums.ReqLoc.Slots:
			return act_logic.slotsFragTree if (act_logic != null and ("slotsFragTree" in act_logic)) else null
		GameEnums.ReqLoc.Table:
			if Engine.has_singleton("GameManager"):
				return Engine.get_singleton("GameManager").table.fragTree
			return null
		GameEnums.ReqLoc.Heap:
			if Engine.has_singleton("GameManager"):
				return Engine.get_singleton("GameManager").heap
			return null
		GameEnums.ReqLoc.Free, GameEnums.ReqLoc.Anywhere:
			if Engine.has_singleton("GameManager"):
				return Engine.get_singleton("GameManager").root
			return null
		_:
			return scope

func count(frag, level: int) -> int:
	if frag == null:
		return level
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if frag == gm.thisAspect:
			return level * (scope.Count(this_aspect) if scope and scope.has_method("Count") else 0)
		elif frag == gm.thisCard:
			return level * (scope.Count(this_card.card) if scope and scope.has_method("Count") and this_card != null else 0)
		elif frag == gm.matchedCards:
			return level * matches.size()
		elif frag == gm.memoryFragment:
			return level * (scope.Count(scope.memoryFragment) if scope and scope.has_method("Count") else 0)
	# default
	return level * (scope.Count(frag) if scope and scope.has_method("Count") else 0)

func resolve_fragment(frag):
	if frag == null:
		return null
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if frag == gm.thisAspect:
			return this_aspect
		if frag == gm.thisCard:
			return this_card.card if this_card != null else null
		if frag == gm.memoryFragment:
			return scope.memoryFragment if scope != null and "memoryFragment" in scope else null
	return frag

func resolve_target(frag):
	if frag == null:
		return null
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if frag == gm.thisAspect:
			return Target.new(this_aspect)
		if frag == gm.thisCard:
			return Target.new(this_card)
		if frag == gm.matchedCards:
			return Target.new(matches)
		if frag == gm.memoryFragment:
			return Target.new(scope.memoryFragment if scope != null and "memoryFragment" in scope else null)
	# fallback: return Target with fragment
	return Target.new(frag)

func resolve_target_cards(target, _scope) -> Array:
	if target == null:
		return []
	if typeof(target) == TYPE_OBJECT and target is Target:
		return target.resolve_cards(_scope)
	if "cards" in target and target.cards != null:
		return target.cards
	var frag = null
	if typeof(target) == TYPE_DICTIONARY:
		frag = target.get("fragment", null)
	elif typeof(target) == TYPE_OBJECT and target.has("fragment"):
		frag = target.fragment
	if frag != null and _scope != null and _scope.has_method("FindAll"):
		return _scope.FindAll(frag)
	return []
