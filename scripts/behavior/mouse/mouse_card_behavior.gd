extends MouseBehavior
class_name MouseCardBehavior

## 开始拖拽
@warning_ignore("unused_parameter")
func on_begin_drag(viz: Viz) -> void:
	print("拖拽开始 - stack_drag: %s, count: %d" % [viz.stack_counter.stack_drag, viz.stack_counter.get_count()])
	var card_viz = viz as CardViz
	# 如果不是整堆拖拽模式且堆中有卡片，弹出一张卡进行拖拽
	if not card_viz.stack_counter.stack_drag and card_viz.stack_counter.get_count() > 0:
		var popped_card = card_viz.stack_counter.pop()
		if popped_card != null:
			# 停止当前卡的拖拽
			card_viz._end_drag()
			# 让弹出的卡开始拖拽
			popped_card.start_drag_directly()
			return
		if card_viz.highlight_behavior:
			card_viz.highlight_behavior.highlight_targets(viz)

## 结束拖拽
@warning_ignore("unused_parameter")
func on_end_drag(viz: Viz) -> void:
	var card_viz = viz as CardViz
	var label_text = card_viz.card_data.label.get_text() if card_viz.card_data and card_viz.card_data.label else "未命名"
	print("结束拖拽卡片: ", label_text)
	
	# 取消高亮
	card_viz.highlight_behavior.set_highlight(viz, false)
	
	_on_drag_release(card_viz.collision_area)
	
	# 重置整堆拖拽标记（必须在 _check_drop_targets 之后，因为需要用到这个标记）
	print("[CardViz] 重置 stack_drag = false")
	card_viz.stack_counter.stack_drag = false

## 可以拖拽
func can_drag(viz: Viz) -> bool:
	var _card_viz = viz as CardViz
	return _card_viz.free

func handle_double_click(viz: Viz) -> void:
	if Manager.GM == null or Manager.GM.open_window == null:
		return
	
	# 尝试自动放置到可用的 Slot
	var ready_slot = null

	# 先检查打开的窗口
	ready_slot = Manager.GM.open_window.accepts_card(viz, true)
	
	# 再检查所有 token 窗口
	for token in Manager.GM.tokens:
		if token.act_window != null:
			ready_slot = token.act_window.accepts_card(viz, true)
			if ready_slot:
				break
	
	# 如果找到可用 slot，放置卡片
	if ready_slot:
		var card_viz_y = viz.yield_card()
		
		# 通知父节点
		var parent_dock = card_viz_y.get_parent()
		if parent_dock and parent_dock.has_method("on_card_undock"):
			parent_dock.on_card_undock(card_viz_y)
		
		# 抓取到 slot（TODO: SlotViz.grab 方法签名可能不同）
		if ready_slot.has_method("grab_card"):
			ready_slot.grab_card(card_viz_y, true)

#region Drop操作，在CardViz中连接信号

#endregion
