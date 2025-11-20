extends Node2D
class_name Viz

## 可拖拽可视化物体的基类
## 提供拖拽、高亮、点击等通用功能，子类需实现抽象方法

#region 行为以及其依赖的属性
@export_group("导出节点")
## 碰撞检测区域: 拖拽、放置、点击触发区域
@export var collision_area: DropArea2D
@export_group("策略")
## 高亮行为
@export var highlight_behavior: HighlightBehavior
## Viz 高亮着色的材质
var _mat: ShaderMaterial
## 放置行为
@export var mouse_behavior: MouseBehavior
## 是否在进行UI操作，避免其他节点也响应输入
var is_input_active = false
#endregion

#region 属性
## 缓存的边界框（Rect2）
var _bounds: Rect2
## 边界框是否已计算
var _bounds_calculated := false

## 状态属性
var is_dragging := false  # 是否正在拖拽
var drag_offset := Vector2.ZERO
var original_z_index: int = 0
var dragging_plane: Node

@export_group("点击检测计时器")
@export var _click_timer: Timer
var _click_count: int = 0
var _last_click_position: Vector2 = Vector2.ZERO
## 判定为同一位置的像素阈值，双击检测
@export var _click_threshold: float = 5.0

## 缓存引用（由子类在 _ready 中初始化）
var _background: Node2D

var _tween: Tween
#endregion

#region 生命周期方法
func _ready() -> void:
	pass

#endregion

#region 抽象方法
## 获取背景节点（用于高亮效果）
func _get_background() -> Node2D:
	push_error("DragCardViz._get_background() 必须被子类重写")
	return null

## 获取材质（用于描边效果）
func _get_material() -> ShaderMaterial:
	push_error("DragCardViz._get_material() 必须被子类重写")
	return null

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
	_background = _get_background()
	_mat = _get_material()
	
	assert(_background != null, "DragCardViz: Background 节点不能为 null")
	assert(_mat != null, "DragCardViz: ShaderMaterial 不能为 null")
	
	# 为每张卡片创建独立的材质副本，避免共享材质
	_mat = _mat.duplicate() as ShaderMaterial
	_background.material = _mat
	
	# 记录原始层级
	original_z_index = z_index
	
	# 初始化点击检测计时器
	if _click_timer != null:
		_click_timer.timeout.connect(_on_click_timeout)

	# 默认不处理输入（只在拖拽时启用）
	set_process_input(false)
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

#region 鼠标进入退出卡牌
## 鼠标进入逻辑
func _on_area_mouse_entered() -> void:
	if highlight_behavior != null:
		highlight_behavior.set_highlight(self, true)

## 鼠标退出逻辑
func _on_area_mouse_exited() -> void:
	if highlight_behavior != null:
		highlight_behavior.set_highlight(self, false)

#endregion

#region 点击逻辑
# 输入逻辑由 Node._input + Area2D._on_area_2d_input_event 共同决定

## 处理鼠标输入事件：单击、双击、开始拖动
## 由子节点的 _on_area_2d_input_event 触发调用
func handle_mouse_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 记录点击位置用于点击检测
		var click_position = event.position

		# 处理点击检测（单击/双击）
		_handle_click_detection(click_position)
		
		if mouse_behavior != null and mouse_behavior.can_drag(self):
			# 按下鼠标左键，开始拖拽
			_start_drag()
			# 标记事件已处理，防止下层卡片也触发
			get_viewport().set_input_as_handled()

## 输入处理（只在拖拽时启用，优先级高于其他卡片）：正在拖动、结束拖动放置
## 全局输入或者复杂的拖拽系统
func _input(event: InputEvent) -> void:
	# 只处理当前正在拖拽的卡片
	if not is_dragging:
		return
	
	# 拖动
	if event is InputEventMouseMotion:
		# 鼠标移动时更新卡牌位置（使用全局坐标计算）
		global_position = get_global_mouse_position() - drag_offset
		# 标记事件已处理，防止其他节点响应
		get_viewport().set_input_as_handled()
	
	# 鼠标按钮事件
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			# 松开鼠标左键，停止拖拽
			_end_drag()
			# 标记事件已处理
			get_viewport().set_input_as_handled()

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
			if mouse_behavior != null:
				mouse_behavior.handle_double_click(self)
		else:
			# 重新开始计时
			_click_timer.start()

## 点击计时器超时（确认为单击）
func _on_click_timeout() -> void:
	if _click_count == 1:
		if mouse_behavior != null and not is_dragging:
			mouse_behavior.handle_single_click(self)
	_click_count = 0

## 外部直接启动拖拽（用于堆叠弹出后的拖拽传递）
func start_drag_directly() -> void:
	if mouse_behavior == null or not mouse_behavior.can_drag(self):
		return
	_start_drag()
	get_viewport().set_input_as_handled()

## 开始拖拽
func _start_drag() -> void:
	is_dragging = true
	# 使用全局鼠标位置和全局卡片位置计算偏移，避免父节点变化导致的坐标系问题
	drag_offset = get_global_mouse_position() - global_position
	if _tween:
		_tween.kill()
	
	# 提升层级到最顶层，避免被其他卡片遮挡
	z_index = 1000
	
	# 禁用 Area2D 输入，防止拖拽时触发其他事件
	collision_area.input_pickable = false
	
	# 启用输入处理（只处理当前卡片的输入）
	set_process_input(true)
	
	if mouse_behavior != null:
		mouse_behavior.on_begin_drag(self)

## 结束拖拽
func _end_drag() -> void:
	is_dragging = false
	
	# 恢复原始层级
	z_index = original_z_index
	# 重新启用 Area2D 输入
	collision_area.input_pickable = true
	# 停用输入处理
	set_process_input(false)
	
	if mouse_behavior != null:
		mouse_behavior.on_end_drag(self)
	

	# 检测是否放置在 Table 上
	
	#var table := NodeUtils.get_parent_of_type(self, Table)
	#if table:
		## 找到 Table，调用其 on_card_dock 方法
		#table.on_card_dock(self)
	#else:
		## 没有 Table，松开后平滑吸附到当前位置
		#move_to(position.round())
#endregion

#region Table 逻辑

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

#endregion

## Drop 信号连接类， area 是 target 的area
@warning_ignore("unused_parameter")
func _on_drop(dragged, target) -> void:
	var dragged_viz = dragged.get_parent()
	if dragged_viz is CardViz:
		collision_area.on_card_drop(dragged)
	if dragged_viz is TokenViz:
		collision_area.on_token_drop(dragged)

#region 辅助方法
## 设置当前对象的可见性、Area2D是否可触发性、碰撞体是否生效
func set_active(is_active: bool = true, collision_type: String = "CollisionShape2D") -> void:
	visible = is_active
	collision_area.monitoring = is_active
	collision_area.monitorable = is_active
	var _c = collision_area.get_node(collision_type) as CollisionShape2D
	_c.disabled = !is_active

#endregion
