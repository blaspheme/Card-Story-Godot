extends Table
class_name ArrayTable

## 基于二维网格数组的桌面实现
## 支持螺旋搜索、自动扩容、多卡片放置等功能

# ===============================
# 导出属性
# ===============================
## 单个网格单元的尺寸（世界坐标）
@export var cell_size: Vector2 = Vector2(220, 320)
## 网格数量（列 x 行）
@export var cell_count: Vector2i = Vector2i(20, 12)
## 空间不足时每次扩容的步长
@export var grow_step: int = 5

# ===============================
# 节点引用
# ===============================
## 桌面区域检测（需要在场景中添加 Area2D 子节点）
@onready var collision_area: Area2D 

# ===============================
# 内部属性
# ===============================
## 二维数组存储（每个元素是 CardViz 或 null）
var _grid_array: Array = []
## 网格左下角的本地坐标
var _grid_corner: Vector2

## 四个方向的偏移（用于螺旋搜索）
const DIRECTIONS_4: Array[Vector2i] = [
	Vector2i.RIGHT,   # 右
	Vector2i.DOWN,    # 下
	Vector2i.LEFT,    # 左
	Vector2i.UP       # 上
]

# ===============================
# 计算属性
# ===============================
var _plane_width: float:
	get: return cell_count.x * cell_size.x

var _plane_height: float:
	get: return cell_count.y * cell_size.y

# ===============================
# 重写基类抽象方法
# ===============================

## 网格坐标转世界坐标
func to_local_position(grid_pos: Vector2i) -> Vector2:
	return _grid_coords_to_local(grid_pos)

## 世界坐标转网格坐标
func from_local_position(local_pos: Vector2):  # 返回 Variant 以匹配基类
	return _local_to_grid_coords(local_pos)

## 查找空闲位置（螺旋搜索）
func find_free_location(grid_pos: Variant, card: CardViz) -> bool:
	if not (grid_pos is Vector2i):
		push_error("ArrayTable.find_free_location: grid_pos 必须是 Vector2i 类型")
		return false
	
	var v: Vector2i = grid_pos as Vector2i
	var phase := 0
	var steps := 0
	var origin := v
	var size := card.cell_count
	
	# 螺旋搜索空位
	@warning_ignore("integer_division")
	while not _fits_in_location(v, size):
		var phase_4 := phase % 4
		@warning_ignore("integer_division")
		var distance := 1 + phase / 4  # 整数除法
		var new_v := v + DIRECTIONS_4[phase_4]
		
		# 检查是否在当前螺旋圈内
		if abs(DIRECTIONS_4[phase_4].x * (new_v.x - origin.x)) <= distance and \
		   abs(DIRECTIONS_4[phase_4].y * (new_v.y - origin.y)) <= distance:
			v = new_v
			steps += 1
		else:
			phase += 1
		
		# 如果搜索超过网格大小，扩容
		if steps > cell_count.x * cell_count.y:
			_grow(grow_step)
	
	# 将找到的位置写回（通过引用修改，但GDScript不支持，所以需要返回值）
	# 注意：这里依赖调用者重新赋值
	if grid_pos is Array:
		grid_pos[0] = v
	
	return true

## 查找多个空闲位置
func find_free_locations(anchor_card: CardViz, cards: Array[CardViz]) -> Array:
	var local_pos := anchor_card.position if anchor_card else Vector2.ZERO
	var start_pos := _local_to_grid_coords(local_pos)
	var locs: Array[Vector2i] = []
	
	# 先尝试连续放置
	if _find_free_locations_consecutive(start_pos, cards, locs):
		return locs
	
	# 否则尝试非连续放置
	locs.clear()
	if _find_free_locations_non_consecutive(start_pos, cards, locs):
		return locs
	
	# 仍然失败，扩容后重试
	_grow(grow_step)
	return find_free_locations(anchor_card, cards)

## 从桌面移除卡片
func remove_card(card: CardViz) -> void:
	if not last_locations.has(card):
		return
	
	var grid_pos: Vector2i = last_locations[card]
	var size := card.cell_count
	
	# 清空占用的网格
	_for_each_cell(grid_pos, size, func(_val): return null)
	
	# 清除位置记录
	last_locations.erase(card)

# ===============================
# 重写基类回调
# ===============================

## 卡片放置后标记网格占用
func _on_card_placed(card: CardViz, grid_pos) -> void:
	if not (grid_pos is Vector2i):
		return
	
	var v: Vector2i = grid_pos as Vector2i
	var size := card.cell_count
	
	# 标记占用
	_for_each_cell(v, size, func(_val): return card)

# ===============================
# 内部辅助方法
# ===============================

## 检查指定位置是否能放下卡片
func _fits_in_location(v: Vector2i, size: Vector2i) -> bool:
	return _all_cells(v, size, func(cell): return cell == null)

## 遍历指定区域的所有格子并应用函数
func _for_each_cell(v: Vector2i, size: Vector2i, f: Callable) -> void:
	for x in range(-size.x, size.x + 1):
		for y in range(-size.y, size.y + 1):
			var pos := v + Vector2i(x, y)
			if _within_bounds(pos):
				_set_grid(pos, f.call(_get_grid(pos)))

## 检查区域内所有格子是否满足条件
func _all_cells(v: Vector2i, size: Vector2i, f: Callable) -> bool:
	for x in range(-size.x, size.x + 1):
		for y in range(-size.y, size.y + 1):
			var pos := v + Vector2i(x, y)
			if not _within_bounds(pos) or not f.call(_get_grid(pos)):
				return false
	return true

## 检查坐标是否在网格范围内
func _within_bounds(v: Vector2i) -> bool:
	return v.x >= 0 and v.x < cell_count.x and v.y >= 0 and v.y < cell_count.y

## 获取网格值
func _get_grid(v: Vector2i):
	var index := v.y * cell_count.x + v.x
	if index >= 0 and index < _grid_array.size():
		return _grid_array[index]
	return null

## 设置网格值
func _set_grid(v: Vector2i, value) -> void:
	var index := v.y * cell_count.x + v.x
	if index >= 0 and index < _grid_array.size():
		_grid_array[index] = value

## 扩容网格
func _grow(step: int) -> void:
	print("ArrayTable: 扩容网格 (+%d 每边)" % step)
	
	var new_width := cell_count.x + 2 * step
	var new_height := cell_count.y + 2 * step
	var new_array: Array = []
	new_array.resize(new_width * new_height)
	new_array.fill(null)
	
	# 复制旧数据到新数组中心
	for x in range(cell_count.x):
		for y in range(cell_count.y):
			var old_index := y * cell_count.x + x
			var new_x := x + step
			var new_y := y + step
			var new_index := new_y * new_width + new_x
			new_array[new_index] = _grid_array[old_index]
	
	# 更新网格
	_grid_array = new_array
	cell_count = Vector2i(new_width, new_height)
	_grid_corner = 0.5 * Vector2(-_plane_width, -_plane_height)
	
	# 更新所有已记录位置的坐标（向右下偏移step）
	var offset := Vector2i(step, step)
	for card in last_locations.keys():
		last_locations[card] = last_locations[card] + offset

## 世界坐标转网格坐标
func _local_to_grid_coords(v: Vector2) -> Vector2i:
	var d := v - _grid_corner
	return Vector2i(
		int(floor(d.x / cell_size.x)),
		int(floor(d.y / cell_size.y))
	)

## 网格坐标转世界坐标（网格中心）
func _grid_coords_to_local(v: Vector2i) -> Vector2:
	return Vector2(v.x * cell_size.x, v.y * cell_size.y) + \
		   0.5 * cell_size + _grid_corner

## 获取下一个候选格子（用于连续放置）
func _next_cell(v: Vector2i, size: Vector2i) -> Vector2i:
	var new_v := v
	new_v.x = new_v.x + size.x * 2 + 1
	if new_v.x + size.x >= cell_count.x:
		new_v.x = size.x
		new_v.y = new_v.y - size.y * 2 - 1
		if new_v.y - size.y <= 0:
			new_v.y = cell_count.y - size.y
	return new_v

## 连续查找多个空位
func _find_free_locations_consecutive(start: Vector2i, cards: Array[CardViz], locs: Array) -> bool:
	var v := start
	var steps := 0
	var found_all := false
	
	while not found_all and steps < cell_count.x * cell_count.y:
		found_all = true
		locs.clear()
		
		for card in cards:
			if _fits_in_location(v, card.cell_count):
				locs.append(v)
			else:
				found_all = false
				break
			v = _next_cell(v, card.cell_count)
			steps += 1
		
		if not found_all:
			v = _next_cell(v, cards[0].cell_count if not cards.is_empty() else Vector2i.ONE)
	
	return found_all

## 非连续查找多个空位
func _find_free_locations_non_consecutive(start: Vector2i, cards: Array[CardViz], locs: Array) -> bool:
	var v := start
	var steps := 0
	
	for card in cards:
		var found_one := false
		while not found_one and steps < cell_count.x * cell_count.y:
			found_one = _fits_in_location(v, card.cell_count)
			if found_one:
				locs.append(v)
			v = _next_cell(v, card.cell_count)
			steps += 1
		
		if not found_one:
			return false
	
	return true

# ===============================
# 生命周期
# ===============================

func _ready() -> void:
	# 初始化网格数组
	_grid_array.resize(cell_count.x * cell_count.y)
	_grid_array.fill(null)
	
	# 计算网格左下角位置
	_grid_corner = 0.5 * Vector2(-_plane_width, -_plane_height)
	
	# 设置 Area2D 碰撞区域（覆盖整个桌面）
	if collision_area:
		_setup_collision_area()
	
	# 调用基类初始化
	super._ready()
	
	print("ArrayTable: 初始化完成 - 网格尺寸: %dx%d, 单元格: %v" % [cell_count.x, cell_count.y, cell_size])

## 设置碰撞区域
func _setup_collision_area() -> void:
	# 创建矩形碰撞形状覆盖整个桌面
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_plane_width, _plane_height)
	
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = shape
	collision_area.add_child(collision_shape)
	
	print("ArrayTable: Area2D 设置完成 - 尺寸: %v" % shape.size)
