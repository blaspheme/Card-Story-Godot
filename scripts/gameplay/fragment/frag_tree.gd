extends Node
class_name FragTree

# ===============================
# 层级化的 Fragment 和 Card 容器系统，用于管理游戏中的资源、卡牌集合和它们之间的关系
# ===============================
## 本地碎片列表：当前节点直接持有的碎片（不包括子节点）
@export var local_fragments: Array[HeldFragmentData] = []
## 本地卡牌：当前节点直接关联的单张卡牌（特殊用途）
@export var local_card: NodePath
## 匹配卡牌列表：满足某些条件的卡牌引用
@export var matches: Array[CardViz] = []
## 记忆碎片：保存上一次操作的碎片引用
@export var memory_fragment: FragmentData = null
## 自由标记：标记当前容器是否"可用/自由"
@export var free: bool = false
## 暂停标记：控制子卡牌的衰变计时器
@export var pause: bool = false
## Unity迁移而来的兼容字段
var enabled :bool = true

@onready var _local_card_node: CardViz = get_node(local_card) if (local_card != null and str(local_card) != "") else null

# ===============================
# 信号
# ===============================
signal on_create_card(card_viz)
signal change_event()

# ===============================
# 实际方法
# ===============================

## 返回包含本节点及所有 CardViz（递归）
func cards() -> Array[CardViz]: return _get_all_cards(true)

## 仅返回作为直接子节点的 CardViz（非递归）
func direct_cards() -> Array[CardViz]: return _get_all_cards(false)

## 返回仅 free 的 CardViz
func free_cards() -> Array:
	var all = cards()
	return all.filter(func(c:CardViz): return c.free)

## fragments 与 free_fragments：合并所有子 FragTree 的 local_fragments
func fragments() -> Array: return _get_fragments(false)

## 自由碎片：只统计 free=true 的 FragTree 中的碎片
func free_fragments() -> Array: return _get_fragments(true)

func clear() -> void:
	matches.clear()
	local_fragments.clear()
	on_change()

# 简单封装的方法（保持与原 API 接口一致）
func add_fragment(fragment) -> void:
	assert(fragment != null)
	# 期望 fragment 提供 AddToTree(self) 或我们直接把 fragment 加入 local_fragments
	if typeof(fragment) == TYPE_OBJECT and fragment.has_method("AddToTree"):
		fragment.AddToTree(self)
	else:
		local_fragments.append(fragment)
		emit_signal("change_event")

func remove_fragment(fragment) -> void:
	if typeof(fragment) == TYPE_OBJECT and fragment.has_method("RemoveFromTree"):
		fragment.RemoveFromTree(self)
	else:
		# 尝试从 local_fragments 中移除
		for i in range(local_fragments.size()-1, -1, -1):
			if local_fragments[i] == fragment:
				local_fragments.remove_at(i)
				emit_signal("change_event")
				return

func adjust(fragment, level: int) -> int:
	# 若 fragment 提供 AdjustInTree，委托给它
	if typeof(fragment) == TYPE_OBJECT and fragment.has_method("AdjustInTree"):
		return fragment.AdjustInTree(self, level)
	# 否则在 local_fragments 做简单计数逻辑
	if fragment == null:
		return 0
	if level > 0:
		for i in range(level):
			local_fragments.append(fragment)
		emit_signal("change_event")
		return level
	elif level < 0:
		var removed = 0
		for i in range(abs(level)):
			for j in range(local_fragments.size()-1, -1, -1):
				if local_fragments[j] == fragment:
					local_fragments.remove_at(j)
					removed += 1
					break
		if removed > 0:
			emit_signal("change_event")
		return -removed
	return 0

# Card/Target 相关 API（简化实现，保留签名）
func add_card(card) -> Node:
	# 期望存在 GameManager.create_card(card) 工厂
	assert(card != null)
	if Engine.has_singleton("GameManager"):
		var gm = Engine.get_singleton("GameManager")
		assert(gm != null and gm.has_method("create_card"))
		var card_viz = gm.create_card(card)
		if card_viz != null:
			add_child(card_viz)
			emit_signal("on_create_card", card_viz)
			emit_signal("change_event")
			return card_viz
	return null

func remove_card(card_viz) -> Node:
	if card_viz != null and card_viz.get_parent() == self:
		remove_child(card_viz)
		matches.erase(card_viz)
		emit_signal("change_event")
		return card_viz
	return null

func adjust_card_viz(_card_viz, _level: int) -> int:
	# 占位：复制/删除逻辑依赖 CardViz. Duplicate() 等
	return 0

func adjust_card(card, level: int) -> int:
	# 占位实现
	if card == null:
		return 0
	if level > 0:
		var cnt = 0
		for i in range(level):
			if add_card(card) != null:
				cnt += 1
			else:
				break
		return cnt
	elif level < 0:
		var removed = 0
		for i in range(abs(level)):
			# 尝试移除一个匹配的 child
			for child in get_children():
				if child.get_class() == "CardViz" and child.card == card:
					remove_card(child)
					removed += 1
					break
		return -removed
	return 0

func adjust_target(target, level: int) -> int:
	if target == null:
		return 0
	if target.cards != null:
		for card_viz in target.cards:
			adjust_card_viz(card_viz, level)
		return 0
	elif target.fragment != null:
		return adjust(target.fragment, level)
	return 0

func count_target(target) -> int:
	if target == null:
		return 0
	if target.fragment != null:
		return count(target.fragment)
	return 0

func find(aspect) -> Variant:
	for h in fragments():
		if h.fragment == aspect:
			return h
	return null

func find_all_by_card(card) -> Array:
	return cards().filter(func(c): return c.card == card)

func find_all_by_aspect(aspect) -> Array:
	var out = []
	for c in cards():
		if c.frag_tree.count(aspect) > 0:
			out.append(c)
	return out

func count_aspect(aspect, only_free: bool=false) -> int:
	var frags = free_fragments() if only_free else fragments()
	for h in frags:
		if h.fragment == aspect:
			return h.count
	return 0

func count_card(card, only_free: bool=false) -> int:
	if only_free:
		return free_cards().filter(func(c): return c.card == card).size()
	return cards().filter(func(c): return c.card == card).size()

func count(item, only_free: bool=false) -> int:
	if item == null:
		return 0
	# 字符串名查找
	if typeof(item) == TYPE_STRING:
		for h in fragments():
			if h.fragment != null and str(h.fragment.name) == item:
				return h.count
		for c in cards():
			if c.card != null and str(c.card.name) == item:
				return count_card(c.card, only_free)
		return 0

	# 先尝试作为 Aspect 计数
	var a = count_aspect(item, only_free)
	if a > 0:
		return a
	# 再尝试作为 Card 计数
	var c = count_card(item, only_free)
	if c > 0:
		return c
	# HeldFragment 风格的字典
	if typeof(item) == TYPE_DICTIONARY and item.has("fragment"):
		return count_aspect(item.fragment, only_free)

	return 0


func on_change() -> void:
	emit_signal("change_event")
	if get_parent() != null and get_parent().get_class() == "FragTree":
		get_parent().on_change()

func on_add_card(card_viz: Node) -> void:
	# 控制卡片的 decay/pause
	for c in card_viz.get_children():
		if pause:
			if c.has_method("pause"):
				c.pause()
		else:
			if c.has_method("unpause"):
				c.unpause()

func interpolate_string(source: String) -> String:
	# 留空实现：复杂的字符串插值可稍后实现
	return source


# ===============================
# 内部方法
# ===============================
## 获取全部卡
func _get_all_cards(recursive: bool) -> Array[CardViz]:
	var out: Array[CardViz] = NodeUtils.find_children_recursive(self, "CardViz", recursive)
	if _local_card_node != null:
		out.append(_local_card_node)
	return out

## 获取所有的 FragTree
func _get_fragments(only_free: bool) -> Array[HeldFragmentData]:
	var out: Array[HeldFragmentData] = []
	var results: Array[FragTree] = NodeUtils.find_children_recursive(self, "FragTree", true)
	for fragtree in results:
		if not fragtree.enabled:
			continue
		if not only_free or fragtree.free:
				for l in fragtree.local_fragments:
					HeldFragmentData.adjust_in_list(out, l.fragment, l.count)
	return out
