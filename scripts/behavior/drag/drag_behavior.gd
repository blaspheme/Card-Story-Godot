extends Resource
class_name DragBehavior

## 开始拖拽
@warning_ignore("unused_parameter")
func on_begin_drag(viz: Viz) -> void:
	push_error("DragBehavior: on_begin_drag() not implemented!")

## 结束拖拽
@warning_ignore("unused_parameter")
func on_end_drag(viz: Viz) -> void:
	push_error("DragBehavior: on_end_drag() not implemented!")

## 可以拖拽
func can_drag(viz: Viz) -> bool:
	return true
