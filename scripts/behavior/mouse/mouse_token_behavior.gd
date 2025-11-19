extends MouseBehavior
class_name MouseTokenBehavior

## 开始拖拽
@warning_ignore("unused_parameter")
func on_begin_drag(viz: Viz) -> void:
	pass

## 结束拖拽
@warning_ignore("unused_parameter")
func on_end_drag(viz: Viz) -> void:
	_on_drag_release(viz.area)

## 可以拖拽
@warning_ignore("unused_parameter")
func can_drag(viz: Viz) -> bool:
	# 始終允许
	return true

func handle_single_click(viz: Viz) -> void:
	var _token_viz = viz as TokenViz
	_token_viz.act_window.bring_up()
