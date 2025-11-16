extends DragBehavior
class_name DragCardBehavior

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
	var _card_viz = viz as CardViz
	return _card_viz.free
