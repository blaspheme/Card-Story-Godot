extends DropArea2D
class_name DropCardArea2D


#region Card Drop时候的操作
func on_card_drop(dragged: Area2D) -> void:
	var dragged_card = NodeUtils.get_parent_of_type(dragged, CardViz) as CardViz
	var target_card = NodeUtils.get_parent_of_type(self, CardViz)

	if dragged_card.can_stack_with(target_card):
		# 检查被拖拽的卡是否有自己的堆叠
		if dragged_card.stack_counter.get_count() > 0:
			# 合并两个堆叠
			target_card.stack_counter.merge(dragged_card.stack_counter)
		else:
			# 将单张卡加入当前堆叠
			target_card.stack_counter.push(dragged_card)
	else:
		print("無法堆叠...")
		Manager.GM.table.return_to_table(dragged_card)


func on_token_drop(dragged: Area2D) -> void:
	super.on_token_drop(dragged)

## 放置到Table上面
#func on_table_drop(dragged, target) -> void:
	#var dragged_card = NodeUtils.get_parent_of_type(dragged, CardViz) as CardViz
	#var target_table = target as Table


#endregion
