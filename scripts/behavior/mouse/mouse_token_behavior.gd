extends MouseBehavior
class_name MouseTokenBehavior

## 开始拖拽
@warning_ignore("unused_parameter")
func on_begin_drag(viz: Viz) -> void:
	pass

## 结束拖拽
@warning_ignore("unused_parameter")
func on_end_drag(viz: Viz) -> void:
	_on_drag_release(viz._area)

## 可以拖拽
@warning_ignore("unused_parameter")
func can_drag(viz: Viz) -> bool:
	# 始終允许
	return true


#region Drop操作，在CardViz中连接信号

#endregion
