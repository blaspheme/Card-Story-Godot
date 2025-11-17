extends Area2D
class_name DropArea2D

## 放下的信号
## dragged: 正在拖动的东西
## target: 目标点
signal dropped(dragged, target)

## 放置
@warning_ignore("unused_parameter")
func on_drop(dragged: Area2D) -> void:
	# 检查鼠标位置是否在此 Area 内
	if get_overlapping_areas().has(dragged):
		emit_signal("dropped", dragged, owner)

#region Drop时候不同对象的操作的函数签名
## CardViz被放置到当前Viz
func on_card_drop(dragged: Area2D) -> void:
	var dragged_card = NodeUtils.get_parent_of_type(dragged, CardViz) as CardViz
	Manager.GM.table.return_to_table(dragged_card)

## TokenViz被放置到当前Viz
func on_token_drop(dragged: Area2D) -> void:
	var dragged_token = NodeUtils.get_parent_of_type(dragged, TokenViz) as TokenViz
	Manager.GM.table.return_to_table(dragged_token)

#endregion
