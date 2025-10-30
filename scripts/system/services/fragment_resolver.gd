extends RefCounted
class_name FragmentResolver

# 负责 fragment/target 的解析与计数逻辑，直接操作 ContextData（静态契约）

func resolve_scope(loc, data) -> Object:
	# 按照静态契约直接访问 data.scope 或 data.act_logic 中的 fragTree
	match loc:
		GameEnums.ReqLoc.Scope:
			return data.scope
		GameEnums.ReqLoc.Slots:
			# 根据 AGENTS.md：断言需求而不是静默回退
			assert(data.act_logic != null)
			return data.act_logic.slotsFragTree
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
			return data.scope

func count(frag, level: int, data) -> int:
	# 静态契约：对 data 的访问必须明确
	if frag == null:
		return level
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if frag == gm.thisAspect:
			assert(data.scope != null)
			return level * data.scope.Count(data.this_aspect)
		elif frag == gm.thisCard:
			assert(data.scope != null and data.this_card != null)
			return level * data.scope.Count(data.this_card.card)
		elif frag == gm.matchedCards:
			return level * data.matches.size()
		elif frag == gm.memoryFragment:
			assert(data.scope != null)
			return level * data.scope.Count(data.scope.memoryFragment)
	# default
	assert(data.scope != null)
	return level * data.scope.Count(frag)

func resolve_fragment(frag, data):
	if frag == null:
		return null
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if frag == gm.thisAspect:
			return data.this_aspect
		if frag == gm.thisCard:
			assert(data.this_card != null)
			return data.this_card.card
		if frag == gm.memoryFragment:
			assert(data.scope != null)
			return data.scope.memoryFragment
	return frag

func resolve_target(frag, data):
	if frag == null:
		return null
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		if frag == gm.thisAspect:
			return Target.new(data.this_aspect)
		if frag == gm.thisCard:
			return Target.new(data.this_card)
		if frag == gm.matchedCards:
			return Target.new(data.matches)
		if frag == gm.memoryFragment:
			assert(data.scope != null)
			return Target.new(data.scope.memoryFragment)
	# fallback
	return Target.new(frag)

func resolve_target_cards(target, _scope) -> Array:
	# 保持行为：若 target 为 Target，使用其解析；否则解析 fragment
	if target == null:
		return []
	if typeof(target) == TYPE_OBJECT and target is Target:
		return target.resolve_cards(_scope)
	if typeof(target) == TYPE_DICTIONARY:
		var frag = target.get("fragment", null)
		if frag != null:
			assert(_scope != null)
			return _scope.FindAll(frag)
	# 若 target 为自带 cards 的容器，则直接返回
	if typeof(target) == TYPE_OBJECT and target.has("cards"):
		return target.cards
	return []

func init_matches(data, keep_matches: bool) -> void:
	# Initialize or clear data.matches based on data.scope. 使用断言保证契约。
	data.matches.clear()
	var sc = data.scope
	if sc == null:
		return
	if keep_matches:
		# 需要外部保证 scope 提供 matches
		assert(typeof(sc) == TYPE_OBJECT and sc.has("matches"))
		data.matches.append_array(sc.matches)
		return
	# not keeping matches: 期望 scope 有 cards
	assert(typeof(sc) == TYPE_OBJECT and sc.has("cards"))
	data.matches.append_array(sc.cards)
