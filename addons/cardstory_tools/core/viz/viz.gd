# Viz - 可放置在桌面上的对象基类
# 继承自Drag，提供拖拽功能和桌面放置相关的抽象方法
class_name Viz
extends Drag

# 缓存的边界信息
var cached_bounds: Rect2
var bounds_calculated: bool = false

# 抽象方法：获取在离散网格桌面上的单元格大小
# 返回对象在表格中超出中心单元格的范围
# 最终大小是 (1,1) + 2*(x,y)
# 例如：(1,1) 对象将有 (3,3) 的大小
# (2,0) 对象将有 (5,1) 的大小
func get_cell_size() -> Vector2i:
	# 子类必须重写此方法
	assert(false, "get_cell_size() 必须在子类中实现")
	return Vector2i.ZERO

# 获取对象在连续桌面上的边界
# 用于连续坐标系统的桌面
func get_bounds() -> Rect2:
	if not bounds_calculated:
		cached_bounds = _calculate_bounds()
		bounds_calculated = true
	
	return cached_bounds

# 计算对象的边界
# 在Godot中，我们使用Control的get_rect()或者基于子节点的边界计算
func _calculate_bounds() -> Rect2:
	# 如果是Control节点，直接返回其矩形
	if self is Control:
		return (self as Control).get_rect()
	
	# 否则，基于子节点计算边界
	var bounds = Rect2()
	var has_bounds = false
	
	# 遍历所有子节点计算边界
	for child in get_children():
		var child_bounds = _get_child_bounds(child)
		if child_bounds.size != Vector2.ZERO:
			if not has_bounds:
				bounds = child_bounds
				has_bounds = true
			else:
				bounds = bounds.merge(child_bounds)
	
	# 如果没有找到有效边界，返回基于位置的零大小边界
	if not has_bounds:
		bounds = Rect2(global_position, Vector2.ZERO)
	
	return bounds

# 获取子节点的边界
func _get_child_bounds(child: Node) -> Rect2:
	# Control节点
	if child is Control:
		var control = child as Control
		return Rect2(control.global_position, control.size)
	
	# Node2D节点 - 尝试从子节点获取
	elif child is Node2D:
		return _calculate_node2d_bounds(child as Node2D)
	
	# 递归检查子节点
	else:
		var bounds = Rect2()
		var has_bounds = false
		
		for grandchild in child.get_children():
			var child_bounds = _get_child_bounds(grandchild)
			if child_bounds.size != Vector2.ZERO:
				if not has_bounds:
					bounds = child_bounds
					has_bounds = true
				else:
					bounds = bounds.merge(child_bounds)
		
		return bounds

# 计算Node2D节点的边界
func _calculate_node2d_bounds(node: Node2D) -> Rect2:
	var bounds = Rect2()
	var has_bounds = false
	
	# 检查是否有Sprite2D
	for child in node.get_children():
		if child is Sprite2D:
			var sprite = child as Sprite2D
			if sprite.texture:
				var texture_size = sprite.texture.get_size()
				var sprite_bounds = Rect2(
					sprite.global_position - texture_size * sprite.scale * 0.5,
					texture_size * sprite.scale
				)
				
				if not has_bounds:
					bounds = sprite_bounds
					has_bounds = true
				else:
					bounds = bounds.merge(sprite_bounds)
		
		# 检查其他可渲染节点
		elif child is CanvasItem:
			var canvas_item = child as CanvasItem
			var item_rect = canvas_item.get_rect()
			if item_rect.size != Vector2.ZERO:
				var item_bounds = Rect2(canvas_item.global_position, item_rect.size)
				
				if not has_bounds:
					bounds = item_bounds
					has_bounds = true
				else:
					bounds = bounds.merge(item_bounds)
	
	return bounds

# 重置边界缓存（当对象发生变化时调用）
func invalidate_bounds() -> void:
	bounds_calculated = false

# 当对象发生变化时自动重置边界缓存
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED, NOTIFICATION_TRANSFORM_CHANGED:
			invalidate_bounds()

# 初始化
func _ready() -> void:
	super._ready()
	invalidate_bounds()
