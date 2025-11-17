extends DropArea2D
class_name DropTokenArea2D


#region Card Drop时候的操作
func on_card_drop(dragged: Area2D) -> void:
	super.on_card_drop(dragged)

func on_token_drop(dragged: Area2D) -> void:
	super.on_token_drop(dragged)


#endregion
