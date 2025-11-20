extends MouseBehavior
class_name MouseActWindowBehavior

## 开始拖拽
@warning_ignore("unused_parameter")
func on_begin_drag(viz: Viz) -> void:
	pass

## 结束拖拽
@warning_ignore("unused_parameter")
func on_end_drag(viz: Viz) -> void:
	pass

## 可以拖拽
@warning_ignore("unused_parameter")
func can_drag(viz: Viz) -> bool:
	return true

## 单击逻辑
@warning_ignore("unused_parameter")
func handle_single_click(viz: Viz) -> void:
	pass

## 双击逻辑
@warning_ignore("unused_parameter")
func handle_double_click(viz: Viz) -> void:
	pass

## Drag停止，进入 drop
func _on_drag_release(dragged_owner: DropArea2D):
	pass
