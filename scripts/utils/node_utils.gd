class_name NodeUtils
extends Object

## 递归查找某类型的所有子节点（深层）
## @param node: 起始节点
## @param type_class: 要查找的类型
## @param recursive: 是否递归
## @return: 所有匹配的子节点数组（深度优先）
static func find_children_recursive(node: Node, type_class: Variant, recursive:bool = false) -> Array:
	# 返回一个通用数组；数组元素在运行时会是由 `type_class` 指定的类型
	var result: Array = []
	for child in node.get_children():
		if is_instance_of(child, type_class):
			result.append(child)
		if recursive:
			result.append_array(find_children_recursive(child, type_class, recursive))
	return result


## 获取指定节点的所有祖先节点（包括 parent、grandparent...）
## @param node: 起始节点
## @return: 所有父节点数组（从近到远）
static func get_parents(node: Node) -> Array[Node]:
	assert(node != null, "node_utils.get_parents: node 不能为 null")
	
	var result: Array[Node] = []
	var current = node.get_parent()
	while current:
		result.append(current)
		current = current.get_parent()
	return result


## 获取第一个符合类型的父节点（类似 Unity 的 GetComponentInParent<T>）
## @param node: 起始节点
## @param type_class: 要查找的类型
## @return: 第一个匹配的父节点，未找到返回 null
static func get_parent_of_type(node: Node, type_class: Variant) -> Node:
	var current = node.get_parent()
	while current:
		if is_instance_of(current, type_class):
			return current
		current = current.get_parent()
	return null


## 添加一个子节点（带检查与可选名称）
## @param parent: 父节点
## @param child: 要添加的子节点
## @param custom_name: 自定义节点名称（可选）
static func add_child_safe(parent: Node, child: Node, custom_name: String = "") -> void:
	assert(parent != null, "node_utils.add_child_safe: parent 不能为 null")
	assert(child != null, "node_utils.add_child_safe: child 不能为 null")
	
	if custom_name != "":
		child.name = custom_name
	if not child.is_inside_tree():
		parent.add_child(child)
	else:
		push_warning("NodeUtils.add_child_safe: 节点已在场景树中: %s" % child.name)


## 从父节点安全删除（不报错）
## @param node: 要移除的节点
static func remove_child_safe(node: Node) -> void:
	if node == null:
		return
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)


## 销毁节点（延迟删除，防止报错）
## @param node: 要销毁的节点
static func delete_node_safe(node: Node) -> void:
	if node == null:
		return
	if not node.is_queued_for_deletion():
		node.queue_free()
