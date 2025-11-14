extends Control
class_name FragmentViz

## 碎片可视化元素：显示单个碎片/卡牌的图标和计数
## 支持点击查看详细信息

#region 变量
## 碎片数据
var fragment: FragmentData
## 关联的卡牌
var card_viz: CardViz
## 图标显示
@onready var art: TextureRect = $Control/Image
## 计数文本
@onready var count_label: Label = $Control/Count
## 计数
var count := 0
## 默认宽度
@export var width := 60.0
#endregion


#region 公共方法
## 加载数据
func load_variant(t: Variant) -> void:
	if t == null:
		return
	card_viz = null

	fragment = t.to_fragment()

	if fragment.art:
		art.texture = fragment.art
		art.modulate = Color.WHITE
	else:
		art.texture = null
		art.modulate = fragment.color

	_set_count(t.count())

## 从 CardViz 加载
func load_card_viz(cviz: CardViz) -> void:
	if not cviz:
		return
	
	card_viz = cviz
	load_variant(cviz.card_data)
	_set_count(1)
#endregion

#region 私有方法
## 设置计数并调整尺寸
func _set_count(value: int) -> void:
	count = value
	count_label.text = str(value)
	_adjust_size()

## 根据计数调整尺寸
func _adjust_size() -> void:
	if count == 1:
		custom_minimum_size.x = width / 2
		count_label.visible = false
	else:
		custom_minimum_size.x = width
		count_label.visible = true

## 处理点击事件
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if card_viz:
				Manager.UI.card_info.load_card_viz(card_viz)
			else:
				Manager.UI.aspect_info.load_aspect(fragment)
#endregion

#region 生命周期
func _ready() -> void:
	gui_input.connect(_on_gui_input)
	
	assert(art != null, "FragmentViz: Art 组件不能为 null")
	assert(count_label != null, "FragmentViz: CountLabel 组件不能为 null")
	
	_set_count(count)
#endregion
