extends GdUnitTestSuite

## SArray 单元测试
## 测试二维数组包装类的所有功能

#region 测试：构造函数和基本属性
func test_constructor_empty() -> void:
	var arr := SArray.new(5, 3)
	
	assert_int(arr.w).is_equal(5)
	assert_int(arr.h).is_equal(3)
	assert_int(arr.array.size()).is_equal(15)
	
	# 默认值应该为 null
	for i in range(arr.array.size()):
		assert_object(arr.array[i]).is_null()

func test_constructor_with_default_value() -> void:
	var arr := SArray.new(3, 2, "default")
	
	assert_int(arr.w).is_equal(3)
	assert_int(arr.h).is_equal(2)
	assert_int(arr.array.size()).is_equal(6)
	
	# 所有元素应该是默认值
	for i in range(arr.array.size()):
		assert_str(arr.array[i]).is_equal("default")
#endregion

#region 测试：索引访问（x, y）
func test_get_set_cell_xy() -> void:
	var arr := SArray.new(4, 3)
	
	# 设置值
	arr.set_cell(0, 0, "A")
	arr.set_cell(3, 2, "B")
	arr.set_cell(1, 1, "C")
	
	# 获取值
	assert_str(arr.get_cell(0, 0)).is_equal("A")
	assert_str(arr.get_cell(3, 2)).is_equal("B")
	assert_str(arr.get_cell(1, 1)).is_equal("C")
	
	# 未设置的位置应该为 null
	assert_object(arr.get_cell(2, 2)).is_null()

func test_xy_indexing_calculation() -> void:
	var arr := SArray.new(4, 3)
	
	# 测试坐标到一维索引的计算
	# (0, 0) -> index 0
	# (1, 0) -> index 1
	# (0, 1) -> index 4 (w * y + x = 4 * 1 + 0)
	# (3, 2) -> index 11 (4 * 2 + 3)
	
	arr.set_cell(0, 0, 0)
	arr.set_cell(1, 0, 1)
	arr.set_cell(0, 1, 2)
	arr.set_cell(3, 2, 3)
	
	assert_int(arr.array[0]).is_equal(0)
	assert_int(arr.array[1]).is_equal(1)
	assert_int(arr.array[4]).is_equal(2)
	assert_int(arr.array[11]).is_equal(3)
#endregion

#region 测试：索引访问（Vector2i）
func test_get_set_cell_vector2i() -> void:
	var arr := SArray.new(4, 3)
	
	# 设置值
	arr.set_cell_v(Vector2i(0, 0), "A")
	arr.set_cell_v(Vector2i(3, 2), "B")
	arr.set_cell_v(Vector2i(1, 1), "C")
	
	# 获取值
	assert_str(arr.get_cell_v(Vector2i(0, 0))).is_equal("A")
	assert_str(arr.get_cell_v(Vector2i(3, 2))).is_equal("B")
	assert_str(arr.get_cell_v(Vector2i(1, 1))).is_equal("C")

func test_vector2i_same_as_xy() -> void:
	var arr := SArray.new(5, 5)
	
	# Vector2i 和 x,y 访问应该等价
	arr.set_cell(2, 3, "test")
	assert_str(arr.get_cell_v(Vector2i(2, 3))).is_equal("test")
	
	arr.set_cell_v(Vector2i(4, 1), "test2")
	assert_str(arr.get_cell(4, 1)).is_equal("test2")
#endregion

#region 测试：边界检查
func test_within_bounds_valid() -> void:
	var arr := SArray.new(5, 3)
	
	assert_bool(arr.within_bounds(Vector2i(0, 0))).is_true()
	assert_bool(arr.within_bounds(Vector2i(4, 2))).is_true()
	assert_bool(arr.within_bounds(Vector2i(2, 1))).is_true()

func test_within_bounds_invalid() -> void:
	var arr := SArray.new(5, 3)
	
	# 负坐标
	assert_bool(arr.within_bounds(Vector2i(-1, 0))).is_false()
	assert_bool(arr.within_bounds(Vector2i(0, -1))).is_false()
	
	# 超出边界
	assert_bool(arr.within_bounds(Vector2i(5, 0))).is_false()
	assert_bool(arr.within_bounds(Vector2i(0, 3))).is_false()
	assert_bool(arr.within_bounds(Vector2i(10, 10))).is_false()
#endregion

#region 测试：动态扩展（Grow）
func test_grow_preserves_data() -> void:
	var arr := SArray.new(3, 3)
	
	# 设置一些数据
	arr.set_cell(0, 0, "A")
	arr.set_cell(1, 1, "B")
	arr.set_cell(2, 2, "C")
	
	# 扩展 1 格
	var grown := arr.grow(1, null)
	
	assert_int(grown.w).is_equal(5)
	assert_int(grown.h).is_equal(5)
	
	# 原始数据应该在偏移 1 的位置
	assert_str(grown.get_cell(1, 1)).is_equal("A")
	assert_str(grown.get_cell(2, 2)).is_equal("B")
	assert_str(grown.get_cell(3, 3)).is_equal("C")

func test_grow_with_default_value() -> void:
	var arr := SArray.new(2, 2, "old")
	
	# 扩展并填充新区域
	var grown := arr.grow(1, "new")
	
	assert_int(grown.w).is_equal(4)
	assert_int(grown.h).is_equal(4)
	
	# 边缘应该是新值
	assert_str(grown.get_cell(0, 0)).is_equal("new")
	assert_str(grown.get_cell(3, 0)).is_equal("new")
	assert_str(grown.get_cell(0, 3)).is_equal("new")
	
	# 中心应该是旧值
	assert_str(grown.get_cell(1, 1)).is_equal("old")
	assert_str(grown.get_cell(2, 2)).is_equal("old")

func test_grow_multiple_times() -> void:
	var arr := SArray.new(1, 1)
	arr.set_cell(0, 0, "center")
	
	var grown1 := arr.grow(1, "layer1")
	assert_int(grown1.w).is_equal(3)
	assert_str(grown1.get_cell(1, 1)).is_equal("center")
	
	var grown2 := grown1.grow(1, "layer2")
	assert_int(grown2.w).is_equal(5)
	assert_str(grown2.get_cell(2, 2)).is_equal("center")
#endregion

#region 测试：区域操作 - ForV
func test_for_v_basic() -> void:
	var arr := SArray.new(5, 5, 0)
	
	# 在 (2, 2) 周围半径 1 的区域内，将所有值 +10
	arr.for_v(Vector2i(2, 2), Vector2i(1, 1), func(val): return val + 10)
	
	# 中心 3x3 区域应该是 10
	assert_int(arr.get_cell(1, 1)).is_equal(10)
	assert_int(arr.get_cell(2, 2)).is_equal(10)
	assert_int(arr.get_cell(3, 3)).is_equal(10)
	
	# 外围应该还是 0
	assert_int(arr.get_cell(0, 0)).is_equal(0)
	assert_int(arr.get_cell(4, 4)).is_equal(0)

func test_for_v_edge_clamping() -> void:
	var arr := SArray.new(3, 3, 0)
	
	# 在 (0, 0) 周围半径 1，部分区域超出边界
	arr.for_v(Vector2i(0, 0), Vector2i(1, 1), func(val): return val + 1)
	
	# 只有在边界内的部分被修改
	assert_int(arr.get_cell(0, 0)).is_equal(1)
	assert_int(arr.get_cell(1, 0)).is_equal(1)
	assert_int(arr.get_cell(0, 1)).is_equal(1)
	assert_int(arr.get_cell(1, 1)).is_equal(1)
	
	# 其他位置未修改
	assert_int(arr.get_cell(2, 2)).is_equal(0)
#endregion

#region 测试：区域操作 - AllV
func test_all_v_all_true() -> void:
	var arr := SArray.new(5, 5, 10)
	
	# 中心 3x3 区域所有值都 >= 5
	var result := arr.all_v(Vector2i(2, 2), Vector2i(1, 1), func(val): return val >= 5)
	
	assert_bool(result).is_true()

func test_all_v_some_false() -> void:
	var arr := SArray.new(5, 5, 10)
	arr.set_cell(2, 2, 0)  # 中心设为 0
	
	# 中心 3x3 区域不是所有值都 >= 5
	var result := arr.all_v(Vector2i(2, 2), Vector2i(1, 1), func(val): return val >= 5)
	
	assert_bool(result).is_false()

func test_all_v_out_of_bounds() -> void:
	var arr := SArray.new(3, 3, 10)
	
	# (0, 0) 周围半径 2，超出边界，应该返回 false
	var result := arr.all_v(Vector2i(0, 0), Vector2i(2, 2), func(val): return val >= 5)
	
	assert_bool(result).is_false()
#endregion

#region 测试：区域操作 - MaxV
func test_max_v_find_maximum() -> void:
	var arr := SArray.new(5, 5, 0)
	
	# 设置一些值
	arr.set_cell(1, 1, 5)
	arr.set_cell(2, 2, 15)  # 最大值
	arr.set_cell(3, 3, 10)
	
	# 查找 (2, 2) 周围半径 1 的最大值
	var max_val := [0]
	arr.max_v(Vector2i(2, 2), Vector2i(1, 1), max_val, func(val): return val)
	
	assert_int(max_val[0]).is_equal(15)

func test_max_v_with_transform() -> void:
	var arr := SArray.new(3, 3)
	
	# 存储字典，提取其中的 "value" 键
	arr.set_cell(0, 0, {"value": 10})
	arr.set_cell(1, 1, {"value": 30})
	arr.set_cell(2, 2, {"value": 20})
	
	var max_val := [0]
	arr.max_v(Vector2i(1, 1), Vector2i(1, 1), max_val, func(val): return val["value"] if val else 0)
	
	assert_int(max_val[0]).is_equal(30)

func test_max_v_null_handling() -> void:
	var arr := SArray.new(3, 3, null)
	arr.set_cell(1, 1, 5)
	
	var max_val := [null]
	arr.max_v(Vector2i(1, 1), Vector2i(1, 1), max_val, func(val): return val)
	
	assert_int(max_val[0]).is_equal(5)
#endregion

#region 测试：调试功能
func test_print_array() -> void:
	var arr := SArray.new(3, 2, null)
	arr.set_cell(0, 0, "X")
	arr.set_cell(2, 1, "X")
	
	var printed := arr.print_array()
	
	# 应该包含 X 和 0
	assert_str(printed).contains("X")
	assert_str(printed).contains("0")
	
	# 应该有 2 行
	var lines := printed.split("\n", false)
	assert_int(lines.size()).is_equal(2)
#endregion

#region 测试：边缘情况
func test_1x1_array() -> void:
	var arr := SArray.new(1, 1, "only")
	
	assert_str(arr.get_cell(0, 0)).is_equal("only")
	assert_bool(arr.within_bounds(Vector2i(0, 0))).is_true()
	assert_bool(arr.within_bounds(Vector2i(1, 0))).is_false()

func test_large_array() -> void:
	var arr := SArray.new(100, 100, 0)
	
	assert_int(arr.w).is_equal(100)
	assert_int(arr.h).is_equal(100)
	assert_int(arr.array.size()).is_equal(10000)
	
	arr.set_cell(99, 99, 999)
	assert_int(arr.get_cell(99, 99)).is_equal(999)

func test_different_types() -> void:
	# 测试不同类型的存储
	var arr_int := SArray.new(2, 2, 0)
	var arr_str := SArray.new(2, 2, "")
	var arr_dict := SArray.new(2, 2, {})
	var arr_null := SArray.new(2, 2, null)
	
	arr_int.set_cell(0, 0, 42)
	arr_str.set_cell(0, 0, "test")
	arr_dict.set_cell(0, 0, {"key": "value"})
	
	assert_int(arr_int.get_cell(0, 0)).is_equal(42)
	assert_str(arr_str.get_cell(0, 0)).is_equal("test")
	assert_object(arr_dict.get_cell(0, 0)).is_equal({"key": "value"})
	assert_object(arr_null.get_cell(0, 0)).is_null()
#endregion
