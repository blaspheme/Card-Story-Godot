extends GdUnitTestSuite

## FragTree 层级化碎片和卡牌管理系统的单元测试
## 参考 Unity 版本的 FragTree.cs 实现

# ===============================
# 测试用的 Mock 数据类
# ===============================
class MockAspect extends AspectData:
	var aspect_name: String
	
	func _init(name: String):
		aspect_name = name
		resource_name = name
	
	func _to_string() -> String:
		return "MockAspect(%s)" % aspect_name

class MockCard extends CardData:
	var card_name: String
	
	func _init(name: String):
		card_name = name
		resource_name = name
	
	func _to_string() -> String:
		return "MockCard(%s)" % card_name

class MockCardViz:
	var card: MockCard
	var free: bool = true
	
	func _init(card_data: MockCard = null):
		card = card_data

# ===============================
# 测试生命周期
# ===============================
var test_tree: FragTree
var aspect_a: MockAspect
var aspect_b: MockAspect
var card_1: MockCard
var card_2: MockCard

func before_test() -> void:
	# 每个测试前创建干净的 FragTree 和测试数据
	test_tree = FragTree.new()
	add_child(test_tree)  # 添加到场景树以支持信号和父子查询
	
	aspect_a = MockAspect.new("AspectA")
	aspect_b = MockAspect.new("AspectB")
	card_1 = MockCard.new("Card1")
	card_2 = MockCard.new("Card2")

func after_test() -> void:
	# 清理测试节点
	if test_tree:
		test_tree.queue_free()
		test_tree = null

# ===============================
# Fragment/Aspect 相关测试
# ===============================

## 测试：添加和计数 Aspect
func test_add_aspect_and_count() -> void:
	# 初始计数为 0
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(0)
	
	# 添加一次
	test_tree.add_aspect(aspect_a)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(1)
	
	# 再添加一次（累加）
	test_tree.add_aspect(aspect_a)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(2)
	
	# 添加不同的 Aspect
	test_tree.add_aspect(aspect_b)
	assert_int(test_tree.count_aspect(aspect_b)).is_equal(1)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(2)  # 不影响 A

## 测试：移除 Aspect
func test_remove_aspect() -> void:
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_a)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(3)
	
	# 移除一次
	test_tree.remove_aspect(aspect_a)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(2)
	
	# 移除到 0
	test_tree.remove_aspect(aspect_a)
	test_tree.remove_aspect(aspect_a)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(0)

## 测试：adjust_aspect（批量增减）
func test_adjust_aspect() -> void:
	# 增加 5 个
	var result = test_tree.adjust_aspect(aspect_a, 5)
	assert_int(result).is_equal(5)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(5)
	
	# 减少 2 个
	result = test_tree.adjust_aspect(aspect_a, -2)
	assert_int(result).is_equal(3)
	assert_int(test_tree.count_aspect(aspect_a)).is_equal(3)
	
	# null 安全测试
	result = test_tree.adjust_aspect(null, 10)
	assert_int(result).is_equal(0)

## 测试：fragments() 返回所有碎片
func test_fragments_aggregation() -> void:
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_b)
	
	var frags = test_tree.fragments()
	# 应该有 2 种碎片（AspectA 和 AspectB）
	assert_int(frags.size()).is_equal(2)
	
	# 验证 AspectA 的计数
	var found_a = frags.filter(func(h): return h.fragment == aspect_a)
	assert_int(found_a.size()).is_equal(1)
	assert_int(found_a[0].count).is_equal(2)

## 测试：递归收集子 FragTree 的碎片
func test_fragments_recursive() -> void:
	# 创建子 FragTree
	var child_tree = FragTree.new()
	test_tree.add_child(child_tree)
	
	# 父节点添加碎片
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_a)
	
	# 子节点添加碎片
	child_tree.add_aspect(aspect_a)
	child_tree.add_aspect(aspect_b)
	
	# fragments() 应该合并父子的碎片
	var frags = test_tree.fragments()
	var found_a = frags.filter(func(h): return h.fragment == aspect_a)
	assert_int(found_a[0].count).is_equal(3)  # 2 (parent) + 1 (child)
	
	var found_b = frags.filter(func(h): return h.fragment == aspect_b)
	assert_int(found_b[0].count).is_equal(1)

## 测试：free_fragments 只统计 free=true 的节点
func test_free_fragments() -> void:
	# 父节点需要设置为 free 才能被 free_fragments 收集
	test_tree.free = true
	
	# 创建子节点，设置为非 free
	var child_tree = FragTree.new()
	child_tree.free = false
	test_tree.add_child(child_tree)
	
	test_tree.add_aspect(aspect_a)
	child_tree.add_aspect(aspect_b)
	
	# free_fragments 应该只返回父节点的碎片（父节点 free=true）
	var free_frags = test_tree.free_fragments()
	var found_a = free_frags.filter(func(h): return h.fragment == aspect_a)
	assert_int(found_a.size()).is_equal(1)
	
	# aspect_b 在非 free 的子节点中，不应出现
	var found_b = free_frags.filter(func(h): return h.fragment == aspect_b)
	assert_int(found_b.size()).is_equal(0)
	
	# 设置子节点为 free 后应该包含
	child_tree.free = true
	free_frags = test_tree.free_fragments()
	found_b = free_frags.filter(func(h): return h.fragment == aspect_b)
	assert_int(found_b.size()).is_equal(1)

## 测试：enabled 标志影响碎片收集
func test_enabled_flag() -> void:
	var child_tree = FragTree.new()
	test_tree.add_child(child_tree)
	child_tree.add_aspect(aspect_a)
	
	# 默认 enabled=true，应该收集到
	var frags = test_tree.fragments()
	assert_int(frags.size()).is_equal(1)
	
	# 设置 enabled=false 后不应收集
	child_tree.enabled = false
	frags = test_tree.fragments()
	assert_int(frags.size()).is_equal(0)

## 测试：clear() 方法
func test_clear() -> void:
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_b)
	# 注意：matches 是 Array[CardViz] 类型，测试中不添加 mock
	
	assert_int(test_tree.local_fragments.size()).is_greater(0)
	
	test_tree.clear()
	
	assert_int(test_tree.local_fragments.size()).is_equal(0)
	assert_int(test_tree.matches.size()).is_equal(0)  # clear() 会清空 matches

# ===============================
# Card 相关测试（使用真实场景实例）
# ===============================

## 测试：remove_card_viz 移除子 CardViz
func test_remove_card_viz() -> void:
	# 加载真实的 CardViz 场景
	var card_scene = load("res://scenes/gameplay/viz/card_viz.tscn")
	var card_viz = card_scene.instantiate()
	
	test_tree.add_child(card_viz)
	
	# 验证已添加
	assert_bool(test_tree.get_children().has(card_viz)).is_true()
	
	# 移除卡牌
	var removed = test_tree.remove_card_viz(card_viz)
	assert_object(removed).is_equal(card_viz)
	assert_bool(test_tree.get_children().has(card_viz)).is_false()
	
	# 清理
	card_viz.queue_free()

## 测试：remove_card_viz 从 matches 中移除
func test_remove_card_viz_from_matches() -> void:
	# 使用真实场景
	var card_scene = load("res://scenes/gameplay/viz/card_viz.tscn")
	var card_viz = card_scene.instantiate()
	
	test_tree.add_child(card_viz)
	test_tree.matches.append(card_viz)
	
	test_tree.remove_card_viz(card_viz)
	
	assert_int(test_tree.matches.size()).is_equal(0)
	
	card_viz.queue_free()

## 测试：remove_card_viz 返回 null（当节点不是子节点时）
func test_remove_card_viz_not_child() -> void:
	# 使用真实场景
	var card_scene = load("res://scenes/gameplay/viz/card_viz.tscn")
	var card_viz = card_scene.instantiate()
	
	# 不添加到 test_tree，直接尝试移除
	var removed = test_tree.remove_card_viz(card_viz)
	assert_object(removed).is_null()
	
	# 清理（需要先加到场景树才能 queue_free，否则直接 free）
	card_viz.free()

## 测试：count_card 计数功能（使用 find_all_by_card）
func test_count_and_find_cards() -> void:
	# 由于 cards() 依赖真实的场景树查询，这里测试 find_all_by_card
	# 它同样调用 cards()，但我们可以验证过滤逻辑
	
	# 创建测试卡牌数据
	var test_card_data_1 = MockCard.new("TestCard1")
	
	# find_all_by_card 应该返回空数组（没有真实的 CardViz 子节点）
	var found = test_tree.find_all_by_card(test_card_data_1)
	assert_int(found.size()).is_equal(0)

## 测试：find_fragment_by_aspect（已在其他测试中验证，这里测试边界情况）
func test_find_fragment_edge_cases() -> void:
	# 未找到应该返回 null
	var not_found = test_tree.find_fragment_by_aspect(aspect_a)
	assert_object(not_found).is_null()
	
	# 添加后应该找到
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_a)
	
	var found = test_tree.find_fragment_by_aspect(aspect_a)
	assert_object(found).is_not_null()
	assert_int(found.count).is_equal(2)
	assert_object(found.fragment).is_equal(aspect_a)

## 测试：add_viz 方法（添加可视化组件）
func test_add_viz() -> void:
	var test_node = Node2D.new()
	test_node.name = "TestViz"
	
	# add_viz 会将节点添加为子节点
	test_tree.add_viz(test_node)
	
	assert_bool(test_tree.get_children().has(test_node)).is_true()
	
	test_node.queue_free()

## 测试：add_viz 处理已有父节点的情况
func test_add_viz_with_parent() -> void:
	var other_parent = Node.new()
	var test_node = Node2D.new()
	
	other_parent.add_child(test_node)
	assert_object(test_node.get_parent()).is_equal(other_parent)
	
	# add_viz 应该自动从旧父节点移除并添加到新父节点
	test_tree.add_viz(test_node)
	
	assert_object(test_node.get_parent()).is_equal(test_tree)
	assert_bool(other_parent.get_children().has(test_node)).is_false()
	
	other_parent.queue_free()
	test_node.queue_free()

## 测试：add_viz null 安全
func test_add_viz_null_safety() -> void:
	# 不应该崩溃
	test_tree.add_viz(null)
	
## 测试：add_node 方法
func test_add_node() -> void:
	var test_node = Node.new()
	test_node.name = "TestNode"
	
	test_tree.add_node(test_node)
	
	assert_bool(test_tree.get_children().has(test_node)).is_true()
	
	test_node.queue_free()

## 测试：add_node 触发 change_event
func test_add_node_triggers_change() -> void:
	var signal_received = [false]
	test_tree.change_event.connect(func(): signal_received[0] = true)
	
	var test_node = Node.new()
	test_tree.add_node(test_node)
	
	assert_bool(signal_received[0]).is_true()
	
	test_node.queue_free()

## 测试：local_card 字段
func test_local_card() -> void:
	# local_card 是 NodePath 类型，可以直接赋值测试
	# 实际使用中会指向场景中的 CardViz 节点
	var dummy_path = NodePath("SomePath/ToCard")
	test_tree.local_card = dummy_path
	
	# 验证路径设置成功
	assert_object(test_tree.local_card).is_equal(dummy_path)

# ===============================
# 信号和事件测试
# ===============================

## 测试：change_event 信号在修改时触发
func test_change_event_signal() -> void:
	var signal_received = [false]  # 使用数组包装以支持 lambda 修改
	test_tree.change_event.connect(func(): signal_received[0] = true)
	
	# add_aspect 应该触发 change_event
	test_tree.add_aspect(aspect_a)
	assert_bool(signal_received[0]).is_true()
	
	# clear 也应该触发
	signal_received[0] = false
	test_tree.clear()
	assert_bool(signal_received[0]).is_true()

## 测试：change_event 级联传播到父节点
func test_change_event_propagation() -> void:
	var parent_signal_received = [false]
	var child_tree = FragTree.new()
	test_tree.add_child(child_tree)
	
	test_tree.change_event.connect(func(): parent_signal_received[0] = true)
	
	# 子节点修改应该触发父节点的 change_event
	child_tree.add_aspect(aspect_a)
	assert_bool(parent_signal_received[0]).is_true()

# ===============================
# Find 相关测试
# ===============================

## 测试：find_fragment_by_aspect
func test_find_fragment_by_aspect() -> void:
	test_tree.add_aspect(aspect_a)
	test_tree.add_aspect(aspect_a)
	
	var found = test_tree.find_fragment_by_aspect(aspect_a)
	assert_object(found).is_not_null()
	assert_int(found.count).is_equal(2)
	
	# 未添加的 Aspect 应该返回 null
	var not_found = test_tree.find_fragment_by_aspect(aspect_b)
	assert_object(not_found).is_null()

# ===============================
# 边界条件和健壮性测试
# ===============================

## 测试：null 输入的安全处理
func test_null_safety() -> void:
	# 各种 null 输入不应崩溃
	test_tree.add_aspect(null)
	test_tree.remove_aspect(null)
	assert_int(test_tree.adjust_aspect(null, 5)).is_equal(0)
	assert_int(test_tree.count_aspect(null)).is_equal(0)
	
	test_tree.add_node(null)
	test_tree.add_viz(null)

## 测试：空树的查询
func test_empty_tree_queries() -> void:
	assert_int(test_tree.fragments().size()).is_equal(0)
	assert_int(test_tree.free_fragments().size()).is_equal(0)
	assert_int(test_tree.cards().size()).is_equal(0)
	assert_int(test_tree.direct_cards().size()).is_equal(0)
	assert_int(test_tree.free_cards().size()).is_equal(0)
