extends Resource
class_name HighlightBehavior


## 高亮 target
## @param target: 高亮目标
## @param p : true 高亮， false 取消高亮
@warning_ignore("unused_parameter")
func set_highlight(viz: Viz, enabled: bool) -> void:
	push_error("HighlightBehavior: set_highlight() not implemented!")

## 取消高亮目标
func un_highlight_targets() -> void:
	push_error("HighlightBehavior: un_highlight_targets() not implemented!")
