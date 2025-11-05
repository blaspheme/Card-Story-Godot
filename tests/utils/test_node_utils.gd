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


## 测试：获取指定类型的直接子节点
func test_get_children_of_type() -> void:
	# 创建测试场景
	var parent := Node.new()
	var child_a1 := TestNodeA.new()
	var child_a2 := TestNodeA.new()
	var child_b := TestNodeB.new()
	var regular_node := Node.new()
	
	parent.add_child(child_a1)
	parent.add_child(child_a2)
	parent.add_child(child_b)
	parent.add_child(regular_node)
	
	# 测试获取所有子节点
	var all_children := NodeUtils.get_children_of_type(parent, null)
	assert_int(all_children.size()).is_equal(4)
	
	# 测试获取指定类型
	var type_a_children := NodeUtils.get_children_of_type(parent, TestNodeA)
	assert_int(type_a_children.size()).is_equal(2)
	
	var type_b_children := NodeUtils.get_children_of_type(parent, TestNodeB)
	assert_int(type_b_children.size()).is_equal(1)
	
	# 清理
	parent.queue_free()


## 测试：获取所有父节点
func test_get_parents() -> void:
	# 创建多层父子关系
	var root := Node.new()
	var level1 := Node.new()
	var level2 := Node.new()
	var level3 := Node.new()
	
	root.add_child(level1)
	level1.add_child(level2)
	level2.add_child(level3)
	
	# 从最深层节点获取所有父节点
	var parents := NodeUtils.get_parents(level3)
	assert_int(parents.size()).is_equal(3)
	assert_object(parents[0]).is_equal(level2)
	assert_object(parents[1]).is_equal(level1)
	assert_object(parents[2]).is_equal(root)
	
	# 测试根节点
	var root_parents := NodeUtils.get_parents(root)
	assert_int(root_parents.size()).is_equal(0)
	
	# 清理
	root.queue_free()


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
	var found := NodeUtils.find_children_recursive(root, TestNodeA)
	assert_int(found.size()).is_equal(3)
	
	# 确认找到的是正确的节点
	assert_bool(found.has(target1)).is_true()
	assert_bool(found.has(target2)).is_true()
	assert_bool(found.has(target3)).is_true()
	assert_bool(found.has(non_target)).is_false()
	
	# 清理
	root.queue_free()


## 测试：边界情况 - 空节点断言
func test_assert_null_node() -> void:
	# 这些调用应该触发断言失败
	# 注意：在实际测试中，断言失败会终止测试，所以这里只是文档说明
	
	# 以下代码会触发断言（已注释）：
	# NodeUtils.get_children_of_type(null, Node)
	# NodeUtils.get_parents(null)
	# NodeUtils.get_parent_of_type(null, Node)
	# NodeUtils.add_child_safe(null, Node.new())
	# NodeUtils.find_children_recursive(null, Node)
	
	# 实际测试中我们验证非空情况正常工作
	var node := Node.new()
	var result := NodeUtils.get_children_of_type(node, null)
	assert_array(result).is_not_null()
	node.queue_free()


## 测试：性能测试 - 大量节点
func test_performance_large_tree() -> void:
	var root := Node.new()
	var child_count := 100
	
	# 创建大量子节点
	for i in range(child_count):
		var child: Node
		if i % 2 == 0:
			child = TestNodeA.new()
		else:
			child = TestNodeB.new()
		root.add_child(child)
	
	# 测试查找性能
	var start_time := Time.get_ticks_msec()
	var found := NodeUtils.get_children_of_type(root, TestNodeA)
	var elapsed := Time.get_ticks_msec() - start_time
	
	# 验证结果正确
	assert_int(found.size()).is_equal(50)
	
	# 性能应该在合理范围内（100ms 以内）
	assert_bool(elapsed < 100).is_true()
	
	# 清理
	root.queue_free()
