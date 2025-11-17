extends DropArea2D
class_name DropCardArea2D


#region Card Drop时候的操作
## 放置到CardViz上面
func on_card_drop(dragged, target) -> void:
	var dragged_card = NodeUtils.get_parent_of_type(dragged, CardViz) as CardViz
	var target_card = target as CardViz

	if dragged_card.stack_counter.stack_drag:
		print("[CardViz] 整堆拖拽模式，尝试 merge")
		# 把目标卡合并到当前拖拽的卡（而不是反过来，避免循环依赖）
		if dragged_card.stack_counter.merge(target_card.stack_counter):
			var target_label = target_card.card_data.label.get_text() if target_card.card_data and target_card.card_data.label else "未命名"
			print("成功合并堆叠到卡片: ", target_label)
		else:
			print("无法合并堆叠到目标卡片")
	# 否则是单卡拖拽，尝试push
	else:
		print("[CardViz] 单卡拖拽模式，尝试 push")
		if target_card.accept_dropped_card(dragged_card):
			var target_label = target_card.card_data.label.get_text() if target_card.card_data and target_card.card_data.label else "未命名"
			print("成功堆叠到卡片: ", target_label)
		else:
			print("无法堆叠到目标卡片")

## 放置到TokenViz上面
func on_token_drop(dragged, target) -> void:
	pass

## 放置到Table上面
func on_table_drop(dragged, target) -> void:
	var dragged_card = NodeUtils.get_parent_of_type(dragged, CardViz) as CardViz
	var target_table = target as Table


#endregion
