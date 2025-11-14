extends Control
class_name CardInfo

## 卡牌信息面板
## 显示卡牌的名称、描述、图标和碎片栏

#region 子节点引用
## 图标显示（Sprite 或颜色块）
@onready var art: TextureRect = $Image
## 描述文本
@onready var description_label: Label = $Description
## 名称文本
@onready var aspect_name_label: Label = $Name
@export var fragment_bar: FragmentBar
#endregion

#region 公共方法
## 加载 CardViz 信息
func load_card_viz(card_viz: CardViz) -> void:
	if not card_viz:
		return
	
	load_card_data(card_viz.card_data)
	fragment_bar.load_from_frag_tree(card_viz.frag_tree)

## 加载 CardData 信息
func load_card_data(card: CardData) -> void:
	Manager.UI.aspect_info.unload()
	
	if not card:
		return
	
	visible = true
	
	aspect_name_label.text = card.label.get_text()
	description_label.text = card.description.get_text()
	
	if card.art:
		art.texture = card.art
		art.modulate = Color.WHITE
	else:
		art.texture = null
		art.modulate = card.color
	
	fragment_bar.unload()

## 加载 SlotViz 信息
func load_slot_viz(slot_viz: SlotViz) -> void:
	Manager.UI.aspect_info.unload()
	
	if not slot_viz:
		return
	
	visible = true
	
	aspect_name_label.text = slot_viz.slot_data.label.get_text()
	description_label.text = slot_viz.slot_data.description.get_text()
	
	art.texture = null
	art.modulate = Color.WHITE
	
	fragment_bar.load_from_slot(slot_viz.slot_data)

## 卸载信息面板
func unload() -> void:
	aspect_name_label.text = ""
	description_label.text = ""
	art.texture = null
	art.modulate = Color.WHITE
	
	fragment_bar.unload()
	
	visible = false
#endregion

#region 生命周期
func _ready() -> void:
	visible = false

#endregion
