extends DropArea2D
class_name DropTableArea2D

#region Drop时候不同对象的操作的函数签名
## 放置到Viz到Table上面
func on_viz_drop(viz: Viz, target:Table) -> void:
	target.on_card_dock(viz)
	

#endregion
