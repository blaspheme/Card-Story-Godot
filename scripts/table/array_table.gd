extends Table
class_name ArrayTable

#region 参数定义
# 网格实现：使用 Vector2i 格坐标
@export var cell_size: Vector2 = Vector2(64, 64)   # 单元格大小（像素）
@export var cell_count: Vector2i = Vector2i(8, 5) # 初始格数 (x,y)
@export var grow_step: int = 2                    # 扩容步长（每侧）

# 内部 occupancy 存储（扁平数组），等价于原 SArray<Viz>
var _array : SArray
var plane_width: float
var plane_height: float

var grid_corner: Vector2 = Vector2.ZERO
var directions4 := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
#endregion

#region 生命周期方法
func _ready() -> void:
	_array = SArray.new(cell_count.x, cell_count.y, Viz)
	frag_tree = NodeUtils.find_children_recursive(self, FragTree, false)[0] as FragTree
	_update_grid_corner()

func _update_grid_corner() -> void:
	plane_width = cell_count.x * cell_size.x
	plane_height = cell_count.y * cell_size.y
	grid_corner = 0.5 * Vector2(-plane_width, -plane_height)
	# 注册场景中已有子节点
	for child in get_children():
		if child is Viz:
			on_card_dock(child)

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
	#Table.on_card_undock(self, viz)

	if last_locations.has(viz):
		var v = last_locations[viz]
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
		var distance = 1 + phase / 4
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



# 内部复用基类 place 行为（因为我们重写 place）
func _place_parent_and_move(viz: Node, grid_coord: Vector2i, move_speed: float) -> void:
	# 基类 place
	if viz.has_method("parent_to"):
		viz.parent_to(self)
	else:
		#viz.get_parent()?.remove_child(viz)
		add_child(viz)
	#_domove(viz, grid_coord, move_speed)
	#last_locations[viz] = grid_coord

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
#endregion
