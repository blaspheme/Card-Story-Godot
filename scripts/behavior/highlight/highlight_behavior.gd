extends Node
class_name HighlightBehavior


## 高亮 target
## @param target: 高亮目标
## @param p : true 高亮， false 取消高亮
@warning_ignore("unused_parameter")
func set_highlight(viz: Viz, enabled: bool) -> void:
	push_error("HighlightBehavior: set_highlight() not implemented!")

## 高亮目标
@warning_ignore("unused_parameter")
func highlight_targets(viz: Viz) -> void:
	pass

## 取消高亮目标
@warning_ignore("unused_parameter")
func un_highlight_targets(viz: Viz) -> void:
	push_error("HighlightBehavior: un_highlight_targets() not implemented!")
