extends Area2D
class_name DropArea2D

## 放下的信号
## dragged: 正在拖动的东西
## target: 目标点
signal dropped(dragged, target)

## 放置
@warning_ignore("unused_parameter")
func on_drop(dragged) -> void:
	# 检查鼠标位置是否在此 Area 内
	if get_overlapping_areas().has(dragged):
		emit_signal("dropped", dragged, owner)


#region Drop时候不同对象的操作的函数签名
## 放置到CardViz上面
func on_card_drop(dragged, target) -> void:
	pass

## 放置到TokenViz上面
func on_token_drop(dragged, target) -> void:
	pass

## 放置到SlotViz上面
func on_slot_drop(dragged, target) -> void:
	pass

## 放置到Table上面
func on_table_drop(dragged, target) -> void:
	pass

#endregion
