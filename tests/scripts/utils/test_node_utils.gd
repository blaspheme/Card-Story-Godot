extends GdUnitTestSuite

## NodeUtils 工具类的单元测试
## 测试所有节点操作相关的工具方法

# 测试用的节点类型
class TestNodeA extends Node:
	pass

class TestNodeB extends Node:
	pass


func before_test() -> void:
	# 每个测试前的准备工作
	pass


func after_test() -> void:
	# 每个测试后的清理工作
	pass


## 测试：获取指定类型的父节点
func test_get_parent_of_type() -> void:
	# 创建混合类型的层级结构
	var root := Node.new()
	var level1 := TestNodeA.new()
	var level2 := Node.new()
	var level3 := TestNodeB.new()
	var level4 := Node.new()
	
	root.add_child(level1)
	level1.add_child(level2)
	level2.add_child(level3)
	level3.add_child(level4)
	
	# 从最深层查找特定类型的父节点
	var found_a := NodeUtils.get_parent_of_type(level4, TestNodeA)
	assert_object(found_a).is_equal(level1)
	
	var found_b := NodeUtils.get_parent_of_type(level4, TestNodeB)
	assert_object(found_b).is_equal(level3)
	
	# 测试找不到的情况
	var not_found := NodeUtils.get_parent_of_type(level1, TestNodeB)
	assert_object(not_found).is_null()
	
	# 清理
	root.queue_free()


## 测试：安全添加子节点
func test_add_child_safe() -> void:
	var parent := Node.new()
	var child := Node.new()
	
	# 正常添加
	NodeUtils.add_child_safe(parent, child)
	# 验证父子关系建立（不依赖场景树）
	assert_object(child.get_parent()).is_equal(parent)
	assert_bool(parent.get_children().has(child)).is_true()
	
	# 测试自定义名称
	var named_child := Node.new()
	NodeUtils.add_child_safe(parent, named_child, "CustomName")
	assert_str(named_child.name).is_equal("CustomName")
	assert_object(named_child.get_parent()).is_equal(parent)
	
	# 测试重复添加（节点已在树中）
	var parent2 := Node.new()
	add_child(parent2)  # 将 parent2 添加到测试场景树
	var child2 := Node.new()
	parent2.add_child(child2)  # child2 现在在场景树中
	
	# 尝试将已在树中的节点添加到另一个父节点（应该发出警告但不报错）
	NodeUtils.add_child_safe(parent, child2)
	# child2 应该仍然在原父节点下
	assert_object(child2.get_parent()).is_equal(parent2)
	
	# 清理
	parent.queue_free()
	parent2.queue_free()


## 测试：安全移除子节点
func test_remove_child_safe() -> void:
	var parent := Node.new()
	var child := Node.new()
	parent.add_child(child)
	
	# 移除子节点
	NodeUtils.remove_child_safe(child)
	assert_object(child.get_parent()).is_null()
	
	# 测试移除 null（不应报错）
	NodeUtils.remove_child_safe(null)
	
	# 测试移除没有父节点的节点（不应报错）
	var orphan := Node.new()
	NodeUtils.remove_child_safe(orphan)
	
	# 清理
	parent.queue_free()
	child.queue_free()
	orphan.queue_free()


## 测试：安全删除节点
func test_delete_node_safe() -> void:
	var node := Node.new()
	
	# 删除节点
	NodeUtils.delete_node_safe(node)
	assert_bool(node.is_queued_for_deletion()).is_true()
	
	# 测试删除 null（不应报错）
	NodeUtils.delete_node_safe(null)
	
	# 测试重复删除（不应报错）
	var node2 := Node.new()
	NodeUtils.delete_node_safe(node2)
	NodeUtils.delete_node_safe(node2)


## 测试：递归查找子节点
func test_find_children_recursive() -> void:
	# 创建深层嵌套结构
	var root := Node.new()
	var level1 := Node.new()
	var level2 := Node.new()
	
	# 在不同层级添加目标类型节点
	var target1 := TestNodeA.new()
	var target2 := TestNodeA.new()
	var target3 := TestNodeA.new()
	var non_target := TestNodeB.new()
	
	root.add_child(level1)
	root.add_child(target1)  # 第一层
	level1.add_child(level2)
	level1.add_child(target2)  # 第二层
	level2.add_child(target3)  # 第三层
	level2.add_child(non_target)
	
	# 递归查找所有 TestNodeA
	var found := NodeUtils.find_children_recursive(root, TestNodeA, true)
	assert_int(found.size()).is_equal(3)
	
	# 确认找到的是正确的节点
	assert_bool(found.has(target1)).is_true()
	assert_bool(found.has(target2)).is_true()
	assert_bool(found.has(target3)).is_true()
	assert_bool(found.has(non_target)).is_false()
	
	# 清理
	root.queue_free()
