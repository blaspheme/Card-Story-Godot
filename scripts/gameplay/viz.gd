extends Node2D
class_name Viz

## 可拖拽卡片的基类
## 提供拖拽、高亮、点击等通用功能，子类需实现抽象方法

#region 属性
## 缓存的边界框（Rect2）
var _bounds: Rect2
## 边界框是否已计算
var _bounds_calculated := false

## 状态属性
var is_dragging := false  # 是否正在拖拽
var _was_stacked := false  # 是否已被堆叠（用于阻止 Table 检测）
var drag_offset := Vector2.ZERO
var original_z_index: int = 0
var dragging_plane: Node

## 点击检测属性
var _click_timer: Timer = null
var _click_count: int = 0
var _double_click_time: float = 0.3  # 双击时间间隔（秒）
var _last_click_position: Vector2 = Vector2.ZERO
var _click_threshold: float = 5.0  # 判定为同一位置的像素阈值

## 缓存引用（由子类在 _ready 中初始化）
var _area: Area2D
var _background: Node2D
var _mat: ShaderMaterial
var _tween: Tween
#endregion

#region 抽象方法
## 获取 Area2D 节点（用于输入检测）
func _get_area() -> Area2D:
	push_error("DragCardViz._get_area() 必须被子类重写")
	return null

## 获取背景节点（用于高亮效果）
func _get_background() -> Node2D:
	push_error("DragCardViz._get_background() 必须被子类重写")
	return null

## 获取材质（用于描边效果）
func _get_material() -> ShaderMaterial:
	push_error("DragCardViz._get_material() 必须被子类重写")
	return null

## 检查是否允许拖拽（子类可重写以添加额外条件）
func _can_start_drag() -> bool:
	return true

## 单击事件回调（子类可重写）
func _on_clicked() -> void:
	pass

## 双击事件回调（子类可重写）
func _on_double_clicked() -> void:
	pass

func get_cell_size() -> Vector2i:
	return Vector2i.ZERO

#endregion

#region 虚拟方法
## 返回对象的边界框（用于连续坐标系桌面）
## 基于子节点的 Sprite2D、TextureRect 等可视化组件计算
func get_bounds() -> Rect2:
	if not _bounds_calculated:
		_bounds = _calculate_bounds(self)
		_bounds_calculated = true
	
	return _bounds

## 强制重新计算边界框
func recalculate_bounds() -> void:
	_bounds_calculated = false
	_bounds = Rect2()

static func _calculate_bounds(node: Node) -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	
	# 尝试从当前节点获取边界框
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture:
			var size := sprite.texture.get_size() * sprite.scale
			var pos := sprite.global_position - size / 2
			bounds = Rect2(pos, size)
			has_bounds = true
	
	elif node is TextureRect:
		var tex_rect := node as TextureRect
		bounds = Rect2(tex_rect.global_position, tex_rect.size)
		has_bounds = true
	
	elif node is CollisionShape2D:
		var collision := node as CollisionShape2D
		if collision.shape is RectangleShape2D:
			var rect_shape := collision.shape as RectangleShape2D
			var size := rect_shape.size
			var pos := collision.global_position - size / 2
			bounds = Rect2(pos, size)
			has_bounds = true
		elif collision.shape is CircleShape2D:
			var circle_shape := collision.shape as CircleShape2D
			var radius := circle_shape.radius
			var size := Vector2(radius * 2, radius * 2)
			var pos := collision.global_position - size / 2
			bounds = Rect2(pos, size)
			has_bounds = true
	
	# 如果当前节点没有边界框，从全局位置创建零大小边界框
	if not has_bounds and node is Node2D:
		bounds = Rect2((node as Node2D).global_position, Vector2.ZERO)
		has_bounds = true
	
	# 递归合并所有子节点的边界框
	for child in node.get_children():
		var child_bounds := _calculate_bounds(child)
		if child_bounds.size != Vector2.ZERO:
			if has_bounds:
				bounds = bounds.merge(child_bounds)
			else:
				bounds = child_bounds
				has_bounds = true
	
	return bounds
#endregion

#region 初始化方法（子类在 _ready 中调用）
## 初始化拖拽系统（子类必须在 _ready 中调用）
func _init_drag_system() -> void:
	_area = _get_area()
	_background = _get_background()
	_mat = _get_material()
	
	assert(_area != null, "DragCardViz: Area2D 不能为 null")
	assert(_background != null, "DragCardViz: Background 节点不能为 null")
	assert(_mat != null, "DragCardViz: ShaderMaterial 不能为 null")
	
	# 为每张卡片创建独立的材质副本，避免共享材质
	_mat = _mat.duplicate() as ShaderMaterial
	_background.material = _mat
	
	# 记录原始层级
	original_z_index = z_index
	
	# 初始化点击检测计时器
	_init_click_timer()
	
	# 默认不处理输入（只在拖拽时启用）
	set_process_input(false)

## 初始化点击检测计时器
func _init_click_timer() -> void:
	_click_timer = Timer.new()
	_click_timer.wait_time = _double_click_time
	_click_timer.one_shot = true
	_click_timer.timeout.connect(_on_click_timeout)
	add_child(_click_timer)
#endregion

#region 动画方法
## 创建 Tween 动画
func _create_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()

## 移动到目标位置
func move_to(target_pos: Vector2, duration := 0.3) -> void:
	_create_tween()
	_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## 旋转到目标角度
func rotate_to(deg: float, duration := 0.25) -> void:
	_create_tween()
	_tween.tween_property(self, "rotation", deg_to_rad(deg), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#endregion

#region 高亮效果
## 高亮效果（修改背景颜色）
func _highlight(active: bool) -> void:
	_create_tween()
	if active:
		# 更快的反应 + 明显的发光效果
		_tween.tween_property(_background, "self_modulate", Color(1.2, 1.0, 0.6, 1.0), 0.15)
	else:
		_tween.tween_property(_background, "self_modulate", Color(1, 1, 1, 1), 0.25)

## 鼠标进入逻辑
func _on_area_mouse_entered() -> void:
	_highlight(true)
	_mat.set_shader_parameter("border_visibility", 1.0)

## 鼠标退出逻辑
func _on_area_mouse_exited() -> void:
	_mat.set_shader_parameter("border_visibility", 0.0)
	_highlight(false)
#endregion

#region 点击检测逻辑
## 处理点击检测（区分单击和双击）
func _handle_click_detection(click_position: Vector2) -> void:
	# 检查是否在同一位置点击（容差范围内）
	var is_same_position = _last_click_position.distance_to(click_position) < _click_threshold
	
	if _click_timer.is_stopped() or not is_same_position:
		# 第一次点击或位置不同，重置计数
		_click_count = 1
		_last_click_position = click_position
		_click_timer.start()
	else:
		# 在双击时间内再次点击同一位置
		_click_count += 1
		
		if _click_count == 2:
			# 双击触发
			_click_timer.stop()
			_click_count = 0
			_on_double_clicked()
		else:
			# 重新开始计时
			_click_timer.start()

## 点击计时器超时（确认为单击）
func _on_click_timeout() -> void:
	if _click_count == 1:
		_on_clicked()
	_click_count = 0
#endregion


#region 鼠标事件
## 处理鼠标输入事件
func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 记录点击位置用于点击检测
		var click_position = event.position
		
		# 处理点击检测（单击/双击）
		_handle_click_detection(click_position)
		
		if _can_start_drag():
			# 按下鼠标左键，开始拖拽
			_start_drag()
			# 标记事件已处理，防止下层卡片也触发
			get_viewport().set_input_as_handled()

## 从鼠标事件开始拖拽
@warning_ignore("unused_parameter")
func start_drag_from_mouse(_mouse_event: InputEventMouseButton) -> void:
	if not _can_start_drag():
		return
	
	_start_drag()
	get_viewport().set_input_as_handled()

## 外部直接启动拖拽（用于堆叠弹出后的拖拽传递）
func start_drag_directly() -> void:
	if not _can_start_drag():
		return
	_start_drag()

## 开始拖拽
func _start_drag() -> void:
	is_dragging = true
	_was_stacked = false  # 重置堆叠标志
	# 使用全局鼠标位置和全局卡片位置计算偏移，避免父节点变化导致的坐标系问题
	drag_offset = get_global_mouse_position() - global_position
	if _tween:
		_tween.kill()
	
	# 提升层级到最顶层，避免被其他卡片遮挡
	z_index = 1000
	
	# 禁用 Area2D 输入，防止拖拽时触发其他事件
	_area.input_pickable = false
	
	# 启用输入处理（只处理当前卡片的输入）
	set_process_input(true)
	
	# 触发拖拽开始事件（子类可监听）
	_on_drag_started()

## 结束拖拽
func _end_drag() -> void:
	is_dragging = false
	
	# 恢复原始层级
	z_index = original_z_index
	# 重新启用 Area2D 输入
	_area.input_pickable = true
	# 停用输入处理
	set_process_input(false)
	
	# 触发拖拽结束事件（子类可监听）- 优先检测卡牌堆叠
	_on_drag_ended()
	
	# 如果子类已经处理了放置（如堆叠到其他卡片），则不再检测 Table
	if _was_stacked:
		return
	
	# 检测是否放置在 Table 上
	var table := _find_table_under_mouse()
	if table:
		# 找到 Table，调用其 on_card_dock 方法
		table.on_card_dock(self)
	else:
		# 没有 Table，松开后平滑吸附到当前位置
		move_to(position.round())

## 拖拽开始回调（子类可重写）
func _on_drag_started() -> void:
	pass

## 拖拽结束回调（子类可重写）
func _on_drag_ended() -> void:
	pass
#endregion

#region Table 检测逻辑
## 查找鼠标下方的 Table
func _find_table_under_mouse() -> Table:
	# 方法1：直接查找父节点链中的 Table
	var current := get_parent()
	while current:
		if current is Table:
			return current as Table
		current = current.get_parent()
	
	# 方法2：使用射线检测鼠标位置下的节点
	var mouse_pos := get_global_mouse_position()
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var results := space_state.intersect_point(query, 32)
	
	# 从结果中查找 Table 节点
	for result in results:
		var collider = result.get("collider")
		if collider:
			# 向上遍历父节点查找 Table
			current = collider as Node
			while current:
				if current is Table:
					return current as Table
				current = current.get_parent()
	
	return null
#endregion

## 输入处理（只在拖拽时启用，优先级高于其他卡片）
func _input(event: InputEvent) -> void:
	# 只处理当前正在拖拽的卡片
	if not is_dragging:
		return
	
	if event is InputEventMouseMotion:
		# 鼠标移动时更新卡牌位置（使用全局坐标计算）
		global_position = get_global_mouse_position() - drag_offset
		# 标记事件已处理，防止其他节点响应
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			# 松开鼠标左键，停止拖拽
			_end_drag()
			# 标记事件已处理
			get_viewport().set_input_as_handled()

## 在 ready 时尝试放置到最近的 ArrayTable 表格中
func _place_on_nearest_array_table() -> void:
	## 场景完全加载 + 所有节点 ready 完成
	await get_tree().process_frame
	# 在场景树中查找所有 ArrayTable
	var tables = NodeUtils.find_children_recursive(get_tree().root, ArrayTable, true)
	if tables.size() == 0:
		return

	# 选择最近的 Table
	var nearest = null
	var best_dist = 1e30
	for t in tables:
		var d = t.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			nearest = t

	if nearest == null:
		return

	# 计算本地格坐标并尝试放置
	var local_p = global_position - nearest.global_position
	var loc = nearest.from_local_position(local_p)

	# 获取速度（优先使用 Manager.GM 提供的值）
	var speed = Manager.GM.fast_speed

	# 首先尝试在计算的位置附近找到空位并放置
	if nearest.find_free_location(loc, self):
		nearest.place(self, loc, speed)
	else:
		nearest.on_card_dock(self)
			
