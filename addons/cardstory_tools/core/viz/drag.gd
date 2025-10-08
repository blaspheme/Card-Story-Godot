# Drag - 拖拽功能基类
# 提供基础的拖拽交互功能，可被其他需要拖拽功能的组件继承
class_name Drag
extends Control

# 拖拽选项
@export_group("拖拽选项")
@export var center_on_cursor: bool = false			# 拖拽时物体是否居中于光标
@export var undrag: bool = false					# 拖拽失败后是否返回原位置

# 拖拽相关变量
var dragging_plane: Control						# 拖拽平面（通常是游戏的主画布）
var _interactive: bool = true					# 是否可交互
var _is_dragging: bool = false					# 是否正在拖拽
var mouse_offset: Vector2						# 鼠标偏移量
var drag_origin: Vector2						# 拖拽起始位置
var drag_origin_dock: ICardDock					# 拖拽起始的停靠位置

# 移动动画相关
var is_being_moved: bool = false				# 是否正在执行动画移动
var move_target: Vector2						# 移动目标位置

# 属性访问器
var is_dragging: bool:
	get: return _is_dragging
	set(value): _is_dragging = value

var interactive: bool:
	get: return _interactive
	set(value): _interactive = value

var target_position: Vector2:
	get: return move_target if is_being_moved else global_position

# 接口定义
class ICardDock:
	# 卡牌停靠接口
	func on_card_dock(card: Control) -> void:
		pass
	
	func on_card_undock(card: Control) -> void:
		pass

# 开始拖拽
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_on_begin_drag(mouse_event)
			else:
				_on_end_drag(mouse_event)
	elif event is InputEventMouseMotion and _is_dragging:
		_on_drag(event as InputEventMouseMotion)

func _on_begin_drag(event: InputEventMouseButton) -> void:
	if not _can_drag(event) or not _interactive:
		return
	
	_is_dragging = true
	drag_origin = global_position
	
	# 获取原始停靠位置
	var parent_node = get_parent()
	if parent_node:
		drag_origin_dock = _get_component_in_parent(parent_node, ICardDock)
	
	# 重新设置父级到拖拽平面
	if dragging_plane:
		_parent_to(dragging_plane)
		if drag_origin_dock:
			drag_origin_dock.on_card_undock(self)
	
	# 禁用碰撞检测（在Godot中可能不需要）
	# 在Unity中是禁用Collider，在Godot中可以禁用Area2D的monitoring
	_set_collision_enabled(false)
	
	# 计算鼠标偏移量
	mouse_offset = global_position - event.global_position
	
	_set_dragged_position(event)

func _on_drag(event: InputEventMouseMotion) -> void:
	if not _is_dragging or not _interactive:
		return
	
	_set_dragged_position(event)

func _on_end_drag(event: InputEventMouseButton) -> void:
	if not _is_dragging:
		return
	
	_is_dragging = false
	
	# 重新启用碰撞检测
	_set_collision_enabled(true)
	
	# 如果没有成功停靠且设置了undrag，则返回原位置
	if undrag and not _get_component_in_parent(get_parent(), ICardDock):
		undrag_to_origin()

# 重新设置父级
func _parent_to(new_parent: Node) -> void:
	var old_parent = get_parent()
	if old_parent != new_parent:
		reparent(new_parent)
		
		# 触发FragTree变更事件（如果存在）
		var old_frag_tree = _get_component_in_parent(old_parent, FragTree)
		if old_frag_tree:
			old_frag_tree.on_change()
		
		var new_frag_tree = _get_component_in_parent(new_parent, FragTree)
		if new_frag_tree:
			new_frag_tree.on_change()

# 动画移动到目标位置
func do_move(target: Vector2, duration: float, on_start: Callable = Callable(), on_complete: Callable = Callable()) -> void:
	var prev_interactive = _interactive
	_interactive = false
	
	move_target = target
	is_being_moved = true
	
	if on_start.is_valid():
		on_start.call(self)
	
	# 使用Tween进行动画移动
	var tween = create_tween()
	tween.tween_property(self, "global_position", target, duration)
	tween.tween_callback(func():
		_interactive = prev_interactive
		is_being_moved = false
		if on_complete.is_valid():
			on_complete.call(self)
	)

# 返回拖拽起始位置
func undrag_to_origin() -> void:
	do_move(drag_origin, GameConfig.NORMAL_SPEED, Callable(), func(_tween):
		if drag_origin_dock:
			drag_origin_dock.on_card_dock(self)
	)

# 检查是否可以拖拽
func _can_drag(event: InputEventMouseButton) -> bool:
	return event.button_index == MOUSE_BUTTON_LEFT and dragging_plane != null

# 设置拖拽位置
func _set_dragged_position(event: InputEvent) -> void:
	var world_mouse_pos: Vector2
	if event is InputEventMouseButton:
		world_mouse_pos = (event as InputEventMouseButton).global_position
	elif event is InputEventMouseMotion:
		world_mouse_pos = (event as InputEventMouseMotion).global_position
	else:
		return
	
	if not center_on_cursor:
		world_mouse_pos += mouse_offset
	
	global_position = world_mouse_pos

# 启用/禁用碰撞检测
func _set_collision_enabled(enabled: bool) -> void:
	# 查找并设置所有子节点的Area2D组件的monitoring属性
	for child in get_children():
		if child is Area2D:
			(child as Area2D).monitoring = enabled
			(child as Area2D).monitorable = enabled

# 获取父节点中指定类型的组件（模拟Unity的GetComponentInParent）
func _get_component_in_parent(node: Node, component_class) -> Node:
	var current = node
	while current != null:
		if current is component_class:
			return current
		current = current.get_parent()
	return null

# 初始化
func _ready() -> void:
	# 设置默认的拖拽平面为场景的主画布
	if not dragging_plane:
		dragging_plane = get_viewport()
