extends DropArea2D
class_name DropSlotArea2D


#region Card Drop时候的操作
func on_card_drop(dragged: Area2D) -> void:
	var dragged_card = NodeUtils.get_parent_of_type(dragged, CardViz) as CardViz
	var target_slot = NodeUtils.get_parent_of_type(self, SlotViz) as SlotViz
	if not target_slot.try_slot_card(dragged_card):
		Manager.GM.table.return_to_table(dragged_card)



func on_token_drop(dragged: Area2D) -> void:
	super.on_token_drop(dragged)
#endregion
