extends Node
class_name MouseBehavior

## 开始拖拽
@warning_ignore("unused_parameter")
func on_begin_drag(viz: Viz) -> void:
	push_error("DragBehavior: on_begin_drag() not implemented!")

## 结束拖拽
@warning_ignore("unused_parameter")
func on_end_drag(viz: Viz) -> void:
	push_error("DragBehavior: on_end_drag() not implemented!")

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
	var areas := dragged_owner.get_overlapping_areas()

	# 找 DropArea2D，最后才处理在Table上的Drop
	var _table_area : DropTableArea2D
	for a in areas:
		if a is DropArea2D:
			if a is DropTableArea2D:
				_table_area = a
			else:
				a.on_drop(dragged_owner)
				return
	if _table_area != null:
		_table_area.on_drop(dragged_owner)
