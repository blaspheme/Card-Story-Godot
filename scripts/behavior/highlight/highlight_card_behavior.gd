extends HighlightBehavior
class_name HighlightCardBehavior

# 高亮行为策略

func set_highlight(viz: Viz, enabled: bool) -> void:
	if enabled:
		viz._mat.set_shader_parameter("border_visibility", 1.0)
	else:
		viz._mat.set_shader_parameter("border_visibility", 0.0)

func highlight_targets(viz: Viz) -> void:
	_set_highlight_targets(viz, true)


func un_highlight_targets(viz: Viz) -> void:
	_set_highlight_targets(viz, false)

## 设置高亮
func _set_highlight_targets(viz: Viz, is_highlight: bool) -> void:
	# 所有 token 的高亮
	for token in Manager.GM.tokens:
		if token.highlight_behavior != null:
			token.highlight_behavior.set_highlight(token, is_highlight)
	
	# 打开窗口的 slot 高亮
	if Manager.GM.open_window != null:
		if is_highlight:
			Manager.GM.open_window.highlight_slots(viz)
		else:
			Manager.GM.open_window.unhighlight_slots()
