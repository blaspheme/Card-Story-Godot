extends HighlightBehavior
class_name HighlightCardBehavior

# 高亮行为策略

## 高亮 viz
func set_highlight(viz: Viz, enabled: bool) -> void:
	if enabled:
		viz._mat.set_shader_parameter("border_visibility", 1.0)
	else:
		viz._mat.set_shader_parameter("border_visibility", 0.0)

## 取消高亮目标
func un_highlight_targets() -> void:
	# 取消所有 token 的高亮
	for token in Manager.GM.tokens:
		if token.highlight_behavior != null:
			token.highlight_behavior.set_highlight(token, false)
	
	# 取消打开窗口的 slot 高亮
	if Manager.GM.open_window != null:
		Manager.GM.open_window.unhighlight_slots()
