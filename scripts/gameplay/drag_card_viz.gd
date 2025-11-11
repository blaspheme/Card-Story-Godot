extends Node2D
class_name DragCardViz

## 可拖拽卡片的基类
## 提供拖拽、高亮等通用功能，子类需实现抽象方法

# ===============================
# 拖拽属性
# ===============================
var is_dragging := false
var drag_offset := Vector2.ZERO
var original_z_index: int = 0
var dragging_plane: Control
# ===============================
# 缓存引用（由子类在 _ready 中初始化）
# ===============================
var _area: Area2D
var _background: Node2D
var _mat: ShaderMaterial
var _tween: Tween

# ===============================
# 抽象方法（子类必须实现）
# ===============================

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

# ===============================
# 初始化方法（子类在 _ready 中调用）
# ===============================

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
	
	# 默认不处理输入（只在拖拽时启用）
	set_process_input(false)

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


# ===============================
# 高亮效果
# ===============================

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

# ===============================
# 拖拽逻辑
# ===============================

## 处理鼠标输入事件
func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
	# 松开后平滑吸附
	move_to(position.round())
	# 恢复原始层级
	z_index = original_z_index
	# 重新启用 Area2D 输入
	_area.input_pickable = true
	# 停用输入处理
	set_process_input(false)
	
	# 触发拖拽结束事件（子类可监听）
	_on_drag_ended()

## 拖拽开始回调（子类可重写）
func _on_drag_started() -> void:
	pass

## 拖拽结束回调（子类可重写）
func _on_drag_ended() -> void:
	pass

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

#region 节点操作
## 将当前节点重新设置父节点
func parent(new_parent: Node) -> void:
	var old_parent := get_parent()
	if old_parent == new_parent:
		return

	# 从旧父级移除并添加到新父级
	if old_parent:
		old_parent.remove_child(self)
	if new_parent:
		new_parent.add_child(self)

	var old_frag = NodeUtils.get_parent_of_type(old_parent, FragTree) as FragTree
	if old_frag:
		old_frag.on_change()

	var new_frag := NodeUtils.get_parent_of_type(new_parent, FragTree) as FragTree
	if new_frag:
		new_frag.on_change()
		new_frag.on_add_card(self)
#endregion
