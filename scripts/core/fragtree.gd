# FragTree - Fragment层次管理系统
class_name FragTree
extends RefCounted

# Fragment节点类
class FragNode extends RefCounted:
	var fragment: Fragment						# 关联的Fragment
	var parent: FragNode						# 父节点
	var children: Array[FragNode] = []			# 子节点列表
	var level: int = 0							# 层级深度
	var metadata: Dictionary = {}				# 元数据
	
	func _init(frag: Fragment = null, parent_node: FragNode = null):
		fragment = frag
		parent = parent_node
		if parent:
			level = parent.level + 1
	
	# 添加子节点
	func add_child(child_node: FragNode) -> void:
		if child_node and child_node not in children:
			child_node.parent = self
			child_node.level = level + 1
			children.append(child_node)
	
	# 移除子节点
	func remove_child(child_node: FragNode) -> void:
		if child_node in children:
			child_node.parent = null
			children.erase(child_node)
	
	# 查找子节点
	func find_child(frag: Fragment) -> FragNode:
		for child in children:
			if child.fragment == frag:
				return child
		return null
	
	# 获取所有后代
	func get_descendants() -> Array[FragNode]:
		var result: Array[FragNode] = []
		for child in children:
			result.append(child)
			result.append_array(child.get_descendants())
		return result
	
	# 获取路径
	func get_path() -> Array[Fragment]:
		var path: Array[Fragment] = []
		var current = self
		while current:
			if current.fragment:
				path.push_front(current.fragment)
			current = current.parent
		return path

# 根节点
var _root: FragNode
var _fragment_to_node: Dictionary = {}			# Fragment到节点的映射
var _total_nodes: int = 0						# 总节点数

func _init():
	_root = FragNode.new()

# 添加Fragment到树中
func add_fragment(fragment: Fragment, parent_fragment: Fragment = null) -> FragNode:
	if not fragment:
		return null
	
	# 检查是否已存在
	if fragment in _fragment_to_node:
		print("警告: Fragment已存在于树中: ", fragment.get_display_name())
		return _fragment_to_node[fragment]
	
	var parent_node = _root
	
	# 查找父节点
	if parent_fragment:
		if parent_fragment in _fragment_to_node:
			parent_node = _fragment_to_node[parent_fragment]
		else:
			print("警告: 父Fragment不存在，添加到根节点: ", parent_fragment.get_display_name())
	
	# 创建新节点
	var new_node = FragNode.new(fragment, parent_node)
	parent_node.add_child(new_node)
	
	# 更新映射
	_fragment_to_node[fragment] = new_node
	_total_nodes += 1
	
	print("添加Fragment到树: ", fragment.get_display_name(), " (层级 ", new_node.level, ")")
	return new_node

# 移除Fragment
func remove_fragment(fragment: Fragment) -> bool:
	if not fragment or fragment not in _fragment_to_node:
		return false
	
	var node = _fragment_to_node[fragment]
	
	# 将子节点重新分配给父节点
	if node.parent:
		for child in node.children:
			node.parent.add_child(child)
	
	# 从父节点移除
	if node.parent:
		node.parent.remove_child(node)
	
	# 更新映射
	_fragment_to_node.erase(fragment)
	_total_nodes -= 1
	
	print("从树中移除Fragment: ", fragment.get_display_name())
	return true

# 查找Fragment节点
func find_node(fragment: Fragment) -> FragNode:
	if fragment in _fragment_to_node:
		return _fragment_to_node[fragment]
	return null

# 获取Fragment的父级
func get_parent(fragment: Fragment) -> Fragment:
	var node = find_node(fragment)
	if node and node.parent and node.parent.fragment:
		return node.parent.fragment
	return null

# 获取Fragment的子级
func get_children(fragment: Fragment) -> Array[Fragment]:
	var result: Array[Fragment] = []
	var node = find_node(fragment)
	
	if node:
		for child_node in node.children:
			if child_node.fragment:
				result.append(child_node.fragment)
	
	return result

# 获取Fragment的所有后代
func get_descendants(fragment: Fragment) -> Array[Fragment]:
	var result: Array[Fragment] = []
	var node = find_node(fragment)
	
	if node:
		for descendant_node in node.get_descendants():
			if descendant_node.fragment:
				result.append(descendant_node.fragment)
	
	return result

# 获取Fragment的祖先路径
func get_path(fragment: Fragment) -> Array[Fragment]:
	var node = find_node(fragment)
	if node:
		return node.get_path()
	return []

# 检查是否为祖先关系
func is_ancestor(ancestor: Fragment, descendant: Fragment) -> bool:
	var path = get_path(descendant)
	return ancestor in path

# 检查是否为直接子级
func is_direct_child(parent: Fragment, child: Fragment) -> bool:
	var child_parent = get_parent(child)
	return child_parent == parent

# 获取同级Fragment
func get_siblings(fragment: Fragment) -> Array[Fragment]:
	var parent = get_parent(fragment)
	if parent:
		var siblings = get_children(parent)
		siblings.erase(fragment)
		return siblings
	else:
		# 根级别的同级
		var result: Array[Fragment] = []
		for child_node in _root.children:
			if child_node.fragment and child_node.fragment != fragment:
				result.append(child_node.fragment)
		return result

# 获取Fragment的层级深度
func get_level(fragment: Fragment) -> int:
	var node = find_node(fragment)
	if node:
		return node.level
	return -1

# 按层级获取所有Fragment
func get_fragments_by_level(level: int) -> Array[Fragment]:
	var result: Array[Fragment] = []
	
	for fragment in _fragment_to_node:
		var node = _fragment_to_node[fragment]
		if node.level == level:
			result.append(fragment)
	
	return result

# 获取所有根级Fragment
func get_root_fragments() -> Array[Fragment]:
	return get_fragments_by_level(1)  # 根节点是level 0，其子节点是level 1

# 获取树的最大深度
func get_max_depth() -> int:
	var max_depth = 0
	
	for fragment in _fragment_to_node:
		var node = _fragment_to_node[fragment]
		max_depth = max(max_depth, node.level)
	
	return max_depth

# 设置节点元数据
func set_metadata(fragment: Fragment, key: String, value) -> void:
	var node = find_node(fragment)
	if node:
		node.metadata[key] = value

# 获取节点元数据
func get_metadata(fragment: Fragment, key: String, default_value = null):
	var node = find_node(fragment)
	if node and key in node.metadata:
		return node.metadata[key]
	return default_value

# 遍历树（深度优先）
func traverse_depth_first(callback: Callable, start_fragment: Fragment = null) -> void:
	var start_node = _root
	
	if start_fragment:
		start_node = find_node(start_fragment)
		if not start_node:
			return
	
	_traverse_node_depth_first(start_node, callback)

func _traverse_node_depth_first(node: FragNode, callback: Callable) -> void:
	if node.fragment:
		callback.call(node.fragment)
	
	for child in node.children:
		_traverse_node_depth_first(child, callback)

# 遍历树（广度优先）
func traverse_breadth_first(callback: Callable, start_fragment: Fragment = null) -> void:
	var start_node = _root
	
	if start_fragment:
		start_node = find_node(start_fragment)
		if not start_node:
			return
	
	var queue: Array[FragNode] = [start_node]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		if current.fragment:
			callback.call(current.fragment)
		
		for child in current.children:
			queue.append(child)

# 搜索Fragment
func search(predicate: Callable) -> Array[Fragment]:
	var result: Array[Fragment] = []
	
	traverse_depth_first(func(fragment):
		if predicate.call(fragment):
			result.append(fragment)
	)
	
	return result

# 清空树
func clear() -> void:
	_fragment_to_node.clear()
	_total_nodes = 0
	_root = FragNode.new()
	print("FragTree已清空")

# 获取统计信息
func get_stats() -> Dictionary:
	return {
		"total_nodes": _total_nodes,
		"max_depth": get_max_depth(),
		"root_fragments": get_root_fragments().size(),
		"memory_usage": _fragment_to_node.size()
	}

# 验证树的完整性
func validate() -> bool:
	var valid = true
	
	# 检查映射一致性
	for fragment in _fragment_to_node:
		var node = _fragment_to_node[fragment]
		if node.fragment != fragment:
			print("错误: 映射不一致 - ", fragment.get_display_name())
			valid = false
	
	# 检查父子关系
	traverse_depth_first(func(fragment):
		var node = find_node(fragment)
		if node:
			for child_node in node.children:
				if child_node.parent != node:
					print("错误: 父子关系不一致 - ", fragment.get_display_name())
					valid = false
	)
	
	return valid

# 打印树结构
func print_tree(start_fragment: Fragment = null, max_depth: int = -1) -> void:
	print("=== FragTree 结构 ===")
	
	var start_node = _root
	if start_fragment:
		start_node = find_node(start_fragment)
		if not start_node:
			print("未找到起始Fragment")
			return
	
	_print_node(start_node, 0, max_depth)
	print("=====================")

func _print_node(node: FragNode, current_depth: int, max_depth: int) -> void:
	if max_depth >= 0 and current_depth > max_depth:
		return
	
	var indent = "  ".repeat(current_depth)
	var name = "ROOT" if not node.fragment else node.fragment.get_display_name()
	
	print(indent + "- " + name + " (level " + str(node.level) + ")")
	
	for child in node.children:
		_print_node(child, current_depth + 1, max_depth)