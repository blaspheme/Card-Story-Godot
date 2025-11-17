extends HighlightBehavior
class_name HighlightTokenBehavior

# 高亮行为策略

## 高亮 viz
func set_highlight(viz: Viz, enabled: bool) -> void:
	if enabled:
		viz._mat.set_shader_parameter("border_visibility", 1.0)
	else:
		viz._mat.set_shader_parameter("border_visibility", 0.0)

## 取消高亮目标
func un_highlight_targets(viz: Viz) -> void:
	pass
