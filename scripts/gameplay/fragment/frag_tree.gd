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

#region 信号定义
signal on_create_card(card_viz)
signal change_event()
#endregion

#region 实际方法
## 返回包含本节点及所有 CardViz（递归）
func cards() -> Array[CardViz]: return _get_all_cards(true)

## 仅返回作为直接子节点的 CardViz（非递归）
func direct_cards() -> Array[CardViz]: return _get_all_cards(false)

## 返回仅 free 的 CardViz
func free_cards() -> Array[CardViz]:
	var all = cards()
	return all.filter(func(c:CardViz): return c.free)

## fragments 与 free_fragments：合并所有子 FragTree 的 local_fragments
func fragments() -> Array[HeldFragmentData]: return _get_fragments(false)

## 自由碎片：只统计 free=true 的 FragTree 中的碎片
func free_fragments() -> Array[HeldFragmentData]: return _get_fragments(true)

## 清除 matches 和 local_fragments 数据
func clear() -> void:
	matches.clear()
	local_fragments.clear()
	on_change()

#region Fragment 增删改查
func add_fragment(_frag: FragmentData) -> void: _frag.add_to_tree(self)

func remove_fragment(_frag: FragmentData) -> void: _frag.remove_from_tree(self)

func adjust_fragment(_frag: FragmentData, _level: int) -> int: return _frag.adjust_in_tree(self, _level)

func count_fragment(_frag: FragmentData, _only_free: bool=false) -> int: return _frag.count_in_tree(self, _only_free)

func add_held_fragment(_frag: HeldFragmentData) -> void: adjust_fragment(_frag.fragment, _frag.count)

func remove_held_fragment(_frag: HeldFragmentData) -> void: adjust_fragment(_frag.fragment, -_frag.count)

#endregion

#region Aspect 增删改查
func add_aspect(_aspect: AspectData) -> void: adjust_aspect(_aspect, 1)

func remove_aspect(_aspect: AspectData) -> void: adjust_aspect(_aspect, -1)

func adjust_aspect(_aspect: AspectData, _level: int) -> int:
	if _aspect != null:
		_aspect.adjust_in_list(local_fragments, _level)
		on_change()
		# 返回调整后的总计数
		var found = local_fragments.filter(func(hf): return hf.fragment == _aspect)
		return found[0].count if found.size() > 0 else 0
	else:
		return 0

func count_aspect(_aspect: AspectData, only_free: bool=false) -> int:
	var frags = free_fragments() if only_free else fragments()
	var _matches = frags.filter(func(hf): return hf.fragment == _aspect)
	var h_frag = _matches[0] if _matches.size() > 0 else null
	if h_frag != null:
		return h_frag.count
	else:
		return 0

#endregion

#region Card 增删改查
# Card/Target 相关 API（简化实现，保留签名）
func add_card(card: CardData) -> CardViz:
	if card != null:
		var card_viz = Manager.GM.create_card(card)
		add_viz(card_viz)
		emit_signal("on_create_card", card_viz)
		return card_viz
	return null

func remove_card_viz(card_viz: CardViz) -> CardViz:
	if card_viz != null and card_viz.get_parent() == self:
		remove_child(card_viz)
		matches.erase(card_viz)
		on_change()
		return card_viz
	return null

func remove_card(card: CardData):
	if card == null:
		return null
	for i in range(get_child_count()):
		var child = get_child(i)
		if child is CardViz:
			if child.card == card:
				return remove_card_viz(child)
		var found_nodes = NodeUtils.find_children_recursive(child, CardViz, true)
		if found_nodes.size() > 0:
			return remove_card_viz(found_nodes[0])
	return null

func adjust_card_viz(_card_viz: CardViz, level: int) -> int:
	if _card_viz == null:
		return 0

	if level > 0:
		var _count := 0
		for i in range(level):
			var new_card_viz = _card_viz.duplicate()
			add_viz(new_card_viz)
			emit_signal("on_create_card", new_card_viz)
			_count += 1
		emit_signal("change_event")
		return _count
	elif level < 0:
		if remove_card_viz(_card_viz) != null:
			emit_signal("change_event")
			return -1
		else:
			return 0

	return 0

func adjust_card(card, level: int) -> int:
	if card == null:
		return 0

	if level > 0:
		var _count := 0
		for i in range(level):
			if add_card(card) != null:
				_count += 1
	elif level < 0:
		var _count := 0
		# 与 C# 等价：在 level 增到 0 之前尝试移除，每移除一次 count--
		while level < 0:
			if remove_card(card) != null:
				_count -= 1
				level += 1
			else:
				break
		return _count

	return 0

func count_card(card, only_free: bool=false) -> int:
	if only_free:
		return free_cards().filter(func(c): return c.card == card).size()
	return cards().filter(func(c): return c.card == card).size()
#endregion

#region Node操作，没有验证
func add_node(_node: Node) -> void:
	# 等价于 mono?.transform.SetParent(transform);
	if _node == null:
		return
	# 如果已经有父节点则自动从旧父移除并加入新父
	if _node.get_parent() != null:
		_node.get_parent().remove_child(_node)
	add_child(_node)
	# 在编辑器场景保存时保持所属关系（可选）
	if get_tree().edited_scene_root != null:
		_node.owner = owner
	emit_signal("change_event")

func add_viz(viz) -> void:
	if viz == null:
		return
	if viz.has_method("parent"):
		viz.parent(self)
	else:
		if viz.get_parent() != null:
			viz.get_parent().remove_child(viz)
		add_child(viz)
#endregion

#region Target
func adjust_target(target: Target, level: int) -> int:
	if target == null:
		return 0
	if target.cards != null:
		for card_viz in target.cards:
			adjust_card_viz(card_viz, level)
		return 0
	elif target.fragment != null:
		return adjust_fragment(target.fragment, level)
	return 0

func count_target(target) -> int:
	if target == null:
		return 0
	if target.fragment != null:
		return count_fragment(target.fragment)
	return 0
#endregion

#region Find
func find_fragment_by_aspect(_aspect: AspectData) -> HeldFragmentData:
	for h in fragments():
		if h.fragment == _aspect:
			return h
	return null

func find_all_by_card(card: CardData) -> Array[CardViz]:
	return cards().filter(func(c): return c.card == card)

func find_all_by_aspect(aspect: AspectData) -> Array[CardViz]:
	var out = []
	for c in cards():
		if c.frag_tree.count(aspect) > 0:
			out.append(c)
	return out
#endregion

#endregion

#region 信号 notify
## 当改变的时候触发的事件和信号
func on_change() -> void:
	emit_signal("change_event")
	var _parent : FragTree = NodeUtils.get_parent_of_type(self, FragTree)
	if _parent != null :
		_parent.on_change()

func on_add_card(card_viz: CardViz) -> void:
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
#endregion

#region 内部方法
## 获取全部卡
func _get_all_cards(recursive: bool) -> Array[CardViz]:
	var out: Array[CardViz] = []
	var raw_results = NodeUtils.find_children_recursive(self, CardViz, recursive)
	for node in raw_results:
		if node is CardViz:
			out.append(node)
	if _local_card_node != null:
		out.append(_local_card_node)
	return out

## 获取所有的 FragTree
func _get_fragments(only_free: bool) -> Array[HeldFragmentData]:
	var out: Array[HeldFragmentData] = []
	
	# Unity 的 GetComponentsInChildren 包含自身，所以先处理自己的 local_fragments
	if enabled and (not only_free or free):
		for l in local_fragments:
			HeldFragmentData.adjust_in_list(out, l.fragment, l.count)
	
	# 然后递归处理子 FragTree
	var raw_results = NodeUtils.find_children_recursive(self, FragTree, true)
	for node in raw_results:
		if node is FragTree:
			var fragtree := node as FragTree
			if not fragtree.enabled:
				continue
			if not only_free or fragtree.free:
				for l in fragtree.local_fragments:
					HeldFragmentData.adjust_in_list(out, l.fragment, l.count)
	return out
#endregion
