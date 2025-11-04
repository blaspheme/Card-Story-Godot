extends RefCounted
class_name Target

# 目标类型
enum Kind { NONE, FRAGMENT, CARDVIZ, CARD_LIST }

# Public fields (轻量数据表示，不做深拷贝)
var kind: int = Kind.NONE
var fragment = null    # Resource / Fragment
var card = null        # CardViz
var cards: Array = []

# 可选构造参数：Fragment / CardViz / Array[CardViz]
func _init(value = null) -> void:
	if value == null:
		kind = Kind.NONE
		return

	if typeof(value) == TYPE_OBJECT:
		# CardViz or Fragment (Resource)
		# 区分规则：CardViz 通常是 Node / Object，Fragment 通常是 Resource / ScriptableObject 转换后为 Resource
		if value.has_method("frag_tree") or value.has("card"): # heuristic for CardViz
			card = value
			kind = Kind.CARDVIZ
		else:
			fragment = value
			kind = Kind.FRAGMENT
	elif typeof(value) == TYPE_ARRAY:
		cards = value
		kind = Kind.CARD_LIST
	else:
		# fallback treat as fragment reference (e.g. int id) 
		fragment = value
		kind = Kind.FRAGMENT

# 工具判断
func is_none() -> bool:
	return kind == Kind.NONE

func is_fragment() -> bool:
	return kind == Kind.FRAGMENT and fragment != null

func is_cardviz() -> bool:
	return kind == Kind.CARDVIZ and card != null

func is_card_list() -> bool:
	return kind == Kind.CARD_LIST and cards != null and cards.size() > 0

# 返回实际 CardViz 列表（不会复制缓存，调用者若要持久化请自行复制）
# scope: FragTree（必须提供以便通过 fragment 查找）
func resolve_cards(scope) -> Array:
	# 优先已有 cards 或单张 card
	if is_card_list():
		return cards
	if is_cardviz():
		return [card]
	# fragment -> 查询 scope 中匹配的卡
	if is_fragment() and scope != null:
		# 支持几种可能的查找接口，优先使用新的 find_all_by_aspect
		if scope.has_method("find_all_by_aspect"):
			return scope.find_all_by_aspect(fragment)
		elif scope.has_method("FindAll"):
			return scope.FindAll(fragment)
		elif scope.has_method("find_all"):
			return scope.find_all(fragment)
	# 返回空数组而非 null 以便调用方少做判空
	return []

# 为调试输出友好字符串
func to_str() -> String:
	match kind:
		Kind.NONE:
			return "Target(None)"
		Kind.FRAGMENT:
			return "Target(Fragment: %s)" % (str(fragment) if fragment != null else "null")
		Kind.CARDVIZ:
			return "Target(CardViz: %s)" % (str(card) if card != null else "null")
		Kind.CARD_LIST:
			return "Target(CardList count=%d)" % (cards.size() if cards != null else 0)
	return "Target(Unknown)"

# 清理（若需要与对象池配合）
func reset() -> void:
	kind = Kind.NONE
	fragment = null
	card = null
	if cards != null:
		cards.clear()
