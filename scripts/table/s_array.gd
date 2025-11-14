class_name SArray
extends RefCounted

## 二维数组包装类，使用一维数组存储
## 支持动态扩展和区域操作

#region 内部变量
## 一维数组存储
var array: Array
## 宽度
var w: int
## 高度
var h: int
#endregion

#region 构造函数
## 创建指定大小的空数组
func _init(width: int, height: int, default_value: Variant = null) -> void:
	w = width
	h = height
	array = []
	array.resize(w * h)
	
	if default_value != null:
		for i in range(array.size()):
			array[i] = default_value
#endregion

#region 索引访问
## 通过 x, y 坐标获取元素
func get_cell(x: int, y: int) -> Variant:
	return array[w * y + x]

## 通过 x, y 坐标设置元素
func set_cell(x: int, y: int, value: Variant) -> void:
	array[w * y + x] = value

## 通过 Vector2i 获取元素
func get_cell_v(v: Vector2i) -> Variant:
	return array[w * v.y + v.x]

## 通过 Vector2i 设置元素
func set_cell_v(v: Vector2i, value: Variant) -> void:
	array[w * v.y + v.x] = value
#endregion

#region 边界检查
## 检查坐标是否在边界内
func within_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.x < w and v.y >= 0 and v.y < h
#endregion

#region 动态扩展
## 扩展数组（在四周各增加 i 个单元格）
## @param i: 扩展大小
## @param default_value: 新单元格的默认值
## @return: 新的 SArray 实例
func grow(i: int, default_value: Variant = null) -> SArray:
	var w2 := w + 2 * i
	var h2 := h + 2 * i
	var new_array := SArray.new(w2, h2, default_value)
	
	for x in range(w):
		for y in range(h):
			new_array.set_cell(x + i, y + i, get_cell(x, y))
	
	return new_array
#endregion

#region 区域操作
## 对指定区域内的所有元素应用函数
## @param v: 区域中心坐标
## @param size: 区域半径（Vector2i，x 和 y 方向的半径）
## @param f: 转换函数 Callable(old_value) -> new_value
func for_v(v: Vector2i, size: Vector2i, f: Callable) -> void:
	for x in range(-size.x, size.x + 1):
		for y in range(-size.y, size.y + 1):
			var pos := v + Vector2i(x, y)
			if within_bounds(pos):
				var old_value = get_cell_v(pos)
				var new_value = f.call(old_value)
				set_cell_v(pos, new_value)

## 检查指定区域内的所有元素是否满足条件
## @param v: 区域中心坐标
## @param size: 区域半径
## @param f: 条件函数 Callable(value) -> bool
## @return: 如果所有元素都满足条件返回 true
func all_v(v: Vector2i, size: Vector2i, f: Callable) -> bool:
	for x in range(-size.x, size.x + 1):
		for y in range(-size.y, size.y + 1):
			var pos := v + Vector2i(x, y)
			if not within_bounds(pos):
				return false
			if not f.call(get_cell_v(pos)):
				return false
	return true

## 查找指定区域内的最大值
## @param v: 区域中心坐标
## @param size: 区域半径
## @param max_value: 输入/输出参数（数组包装），存储当前最大值
## @param f: 提取函数 Callable(value) -> comparable_value
func max_v(v: Vector2i, size: Vector2i, max_value: Array, f: Callable) -> void:
	for x in range(-size.x, size.x + 1):
		for y in range(-size.y, size.y + 1):
			var pos := v + Vector2i(x, y)
			if within_bounds(pos):
				var new_value = f.call(get_cell_v(pos))
				if new_value != null and (max_value[0] == null or new_value >= max_value[0]):
					max_value[0] = new_value
#endregion

#region 调试
## 打印数组内容（用于调试）
func print_array() -> String:
	var result := ""
	for row in range(h - 1, -1, -1):
		for col in range(w):
			var cell = get_cell(col, row)
			result += "X" if cell != null else "0"
		result += "\n"
	return result
#endregion
