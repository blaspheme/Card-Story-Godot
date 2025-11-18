extends MouseBehavior
class_name MouseSlotBehavior

## 可以拖拽
@warning_ignore("unused_parameter")
func can_drag(viz: Viz) -> bool:
	# 始終不允许
	return false
