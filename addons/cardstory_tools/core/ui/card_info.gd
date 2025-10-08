# CardInfo - 卡牌信息UI组件
class_name CardInfo
extends Control

# UI组件引用
@export var art_image: TextureRect
@export var description_label: RichTextLabel
@export var card_name_label: Label
@export var fragment_bar: FragmentBar

# 属性访问器
var description: String:
	get:
		return description_label.text if description_label else ""
	set(value):
		if description_label:
			description_label.text = value

var card_name: String:
	get:
		return card_name_label.text if card_name_label else ""
	set(value):
		if card_name_label:
			card_name_label.text = value

func _ready():
	hide()

# 加载卡牌可视化组件
func load_card_viz(card_viz: CardViz):
	if not card_viz:
		return
	
	load_card(card_viz.card)
	
	# 加载Fragment条
	if fragment_bar and card_viz.frag_tree:
		fragment_bar.load_frag_tree(card_viz.frag_tree)

# 加载卡牌资源
func load_card(card: Card):
	# 关闭Aspect信息
	if UIManager.instance and UIManager.instance.aspect_info:
		UIManager.instance.aspect_info.unload()
	
	if not card:
		return
	
	show()
	
	# 设置基本信息
	card_name = card.get_display_name()
	description = card.description
	
	# 设置图像
	if art_image:
		if card.art:
			art_image.texture = card.art
			art_image.modulate = Color.WHITE
		else:
			art_image.texture = null
			art_image.modulate = card.color
	
	# 清空Fragment条
	if fragment_bar:
		fragment_bar.unload()

# 加载槽位可视化组件
func load_slot_viz(slot_viz: SlotViz):
	# 关闭Aspect信息
	if UIManager.instance and UIManager.instance.aspect_info:
		UIManager.instance.aspect_info.unload()
	
	if not slot_viz or not slot_viz.slot:
		return
	
	show()
	
	# 设置槽位信息
	card_name = slot_viz.slot.get_display_name()
	description = slot_viz.slot.description
	
	# 清空图像
	if art_image:
		art_image.texture = null
		art_image.modulate = Color.WHITE
	
	# 加载槽位Fragment条
	if fragment_bar:
		fragment_bar.load_slot(slot_viz.slot)

# 卸载信息
func unload():
	card_name = ""
	description = ""
	
	if art_image:
		art_image.texture = null
		art_image.modulate = Color.WHITE
	
	if fragment_bar:
		fragment_bar.unload()
	
	hide()

# 检查是否已加载
func is_loaded() -> bool:
	return visible

# 设置主题颜色
func set_theme_color(color: Color):
	if card_name_label:
		card_name_label.modulate = color

# 更新显示
func refresh_display():
	# 刷新Fragment条
	if fragment_bar:
		fragment_bar.refresh()

# 获取当前显示的卡牌信息
func get_current_info() -> Dictionary:
	return {
		"name": card_name,
		"description": description,
		"is_loaded": is_loaded()
	}
