@tool  # 启用编辑器模式，支持实时预览
extends Table
class_name ArrayTable

#region 参数定义
# 网格实现：使用 Vector2i 格坐标
@export var cell_size: Vector2 = Vector2(64, 64):   # 单元格大小（像素）
	set(value):
		cell_size = value
		_update_grid_corner()
		queue_redraw()  # 触发重绘
@export var cell_count: Vector2i = Vector2i(8, 5):  # 初始格数 (x,y)
	set(value):
		cell_count = value
		if _array:
			_array = SArray.new(cell_count.x, cell_count.y, null)
		_update_grid_corner()
		queue_redraw()  # 触发重绘
@export var grow_step: int = 2                      # 扩容步长（每侧）

## 网格绘制设置
@export_group("Grid Display")
@export var show_grid := true:  # 是否显示网格
	set(value):
		show_grid = value
		queue_redraw()
@export var grid_color := Color(0.5, 0.5, 0.5, 0.3)  # 网格线颜色
@export var grid_width := 1.0  # 网格线宽度
@export var show_cell_coords := false:  # 是否显示单元格坐标
	set(value):
		show_cell_coords = value
		queue_redraw()
@export var coord_color := Color(0.8, 0.8, 0.8, 0.6)  # 坐标文本颜色

# 内部 occupancy 存储（扁平数组），等价于原 SArray<Viz>
var _array : SArray
var plane_width: float
var plane_height: float

var grid_corner: Vector2 = Vector2.ZERO
var directions4 := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
#endregion

#region 生命周期方法
func _ready() -> void:
	if not _array:
		_array = SArray.new(cell_count.x, cell_count.y, null)
	if not Engine.is_editor_hint():
		var frag_trees := NodeUtils.find_children_recursive(self, FragTree, false)
		if frag_trees.size() > 0:
			frag_tree = frag_trees[0] as FragTree
	_update_grid_corner()
	queue_redraw()

func _draw() -> void:
	if not show_grid:
		return
	
	_draw_grid()
	
	if show_cell_coords:
		_draw_cell_coords()

func _update_grid_corner() -> void:
	plane_width = cell_count.x * cell_size.x
	plane_height = cell_count.y * cell_size.y
	grid_corner = 0.5 * Vector2(-plane_width, -plane_height)
	
	# 在运行时注册场景中已有子节点
	if not Engine.is_editor_hint():
		for child in get_children():
			if child is Viz:
				on_card_dock(child)
	
	queue_redraw()

#endregion

#region 网格绘制
## 绘制网格线
func _draw_grid() -> void:
	# 绘制垂直线
	for x in range(cell_count.x + 1):
		var start := grid_corner + Vector2(x * cell_size.x, 0)
		var end := start + Vector2(0, plane_height)
		draw_line(start, end, grid_color, grid_width)
	
	# 绘制水平线
	for y in range(cell_count.y + 1):
		var start := grid_corner + Vector2(0, y * cell_size.y)
		var end := start + Vector2(plane_width, 0)
		draw_line(start, end, grid_color, grid_width)
	
	# 绘制外框（加粗）
	var rect := Rect2(grid_corner, Vector2(plane_width, plane_height))
	draw_rect(rect, grid_color, false, grid_width * 2)

## 绘制单元格坐标
func _draw_cell_coords() -> void:
	# 需要字体才能绘制文本，这里使用默认主题字体
	var font := ThemeDB.fallback_font
	var font_size := 12
	
	for x in range(cell_count.x):
		for y in range(cell_count.y):
			var cell_center := to_local_position(Vector2i(x, y))
			var coord_text := "(%d,%d)" % [x, y]
			
			# 计算文本尺寸以居中显示
			var text_size := font.get_string_size(coord_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos := cell_center - text_size / 2
			
			draw_string(font, text_pos, coord_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, coord_color)

#endregion

#region 父类方法
## grid_coord: Vector2i
func to_local_position(grid_coord: Variant) -> Vector2:
	# center of cell
	return Vector2(grid_coord.x * cell_size.x, grid_coord.y * cell_size.y) + 0.5 * cell_size + grid_corner

func from_local_position(local_pos: Vector2) -> Vector2i:
	var d = local_pos - grid_corner
	var gx = int(floor(d.x / cell_size.x))
	var gy = int(floor(d.y / cell_size.y))
	return Vector2i(gx, gy)

func remove(viz: Viz) -> void:
	on_card_undock(viz)

func on_card_undock(viz: Viz) -> void:
	super.on_card_undock(viz)

	var v = get_last_location(viz)
	if v != null:
		_array.for_v(v, viz.get_cell_size(), func(_current): return null)

## 单对象螺旋搜索
func find_free_location(grid_ref: Variant, viz:Viz) -> bool:
	var v = grid_ref as Vector2i
	var origin = v
	var size = viz.get_cell_size()
	var phase = 0
	var steps = 0

	while not fits_in_location(v, size):
		var phase4 = phase % 4
		var distance = floori(phase / 4.0) + 1  # 修复整数除法警告
		var new_v = v + directions4[phase4]
		if abs(directions4[phase4].x * (new_v.x - origin.x)) <= distance and abs(directions4[phase4].y * (new_v.y - origin.y)) <= distance:
			v = new_v
			steps += 1
		else:
			phase += 1
		if steps > cell_count.x * cell_count.y:
			# 扩容并继续
			grow(grow_step)
	# 输出最终位置并返回 true
	grid_ref.x = v.x
	grid_ref.y = v.y
	return true

## 批量放置（连续 / 非连续）
func find_free_locations(center_viz: Viz, l: Array[Viz]) -> Array[Vector2i]:
	var local_p = center_viz.global_position - global_position
	var locs :Array[Vector2i] = []
	var start = from_local_position(local_p)
	if _find_free_locations_c(start, l, locs):
		return locs
	locs.clear()
	if _find_free_locations_nc(start, l, locs):
		return locs
	else:
		grow(grow_step)
		return find_free_locations(center_viz, l)

## Place
func place(viz: Viz, grid_coord: Variant, move_speed: float) -> void:
	super.place(viz, grid_coord, move_speed)
	_array.for_v(grid_coord, viz.get_cell_size(), func(_current): return viz)


func _find_free_locations_c(v: Vector2i, l: Array[Viz], locs: Array[Vector2i]) -> bool:
	var found_all = false
	var steps = 0
	while true:
		found_all = true
		for i in range(l.size()):
			if fits_in_location(v, l[i].get_cell_size()):
				locs.append(v)
			else:
				found_all = false
				locs.clear()
			v = _next_cell(v, l[i].get_cell_size())
			steps += 1
			if not found_all:
				break
		if found_all:
			return true
		if steps >= cell_count.x * cell_count.y:
			return false
	return found_all

func _find_free_locations_nc(v: Vector2i, l: Array[Viz], locs: Array[Vector2i]) -> bool:
	var steps = 0
	for i in range(l.size()):
		var found_one = false
		while not found_one and steps < cell_count.x * cell_count.y:
			found_one = fits_in_location(v, l[i].get_cell_size())
			if found_one:
				locs.append(v)
			v = _next_cell(v, l[i].get_cell_size())
			steps += 1
	return steps < cell_count.x * cell_count.y

func _next_cell(v: Vector2i, size: Vector2i) -> Vector2i:
	v.x = v.x + size.x * 2 + 1
	if v.x + size.x >= cell_count.x:
		v.x = size.x
		v.y = v.y - size.y * 2 - 1
		if v.y - size.y <= 0:
			v.y = cell_count.y - size.y
	return v

## 占位检查
func fits_in_location(v: Vector2i, size: Vector2i) -> bool:
	return _array.all_v(v, size, func(a): return a == null)


func grow(i: int) -> void:
	# 将 SArray 或等价实现扩展四周 i 格，保持已放置项相对位置不变
	_array = _array.grow(i, null)
	# 更新 cell_count
	cell_count += Vector2i(2 * int(i), 2 * int(i))

	# 更新 grid_corner（中心偏移）
	var plane_w = float(cell_count.x) * cell_size.x
	var plane_h = float(cell_count.y) * cell_size.y
	grid_corner = 0.5 * Vector2(-plane_w, -plane_h)

	# 将 last_locations 中每个记录偏移 i,i（旧数组被移动到新数组中心）
	var keys = last_locations.keys()
	for k in keys:
		last_locations[k] = last_locations[k] + Vector2i(int(i), int(i))
	
	# 触发重绘
	queue_redraw()
#endregion
