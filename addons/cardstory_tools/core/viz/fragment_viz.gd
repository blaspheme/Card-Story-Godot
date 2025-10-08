# FragmentViz - Fragment可视化组件
# 用于显示Fragment（如Aspect）的UI组件
class_name FragmentViz
extends Control

# Fragment数据
@export var fragment: Fragment					# 绑定的Fragment数据
var card_viz: CardViz							# 如果是卡牌Fragment，关联的CardViz

# 布局组件
@export_group("布局组件")
@export var art: TextureRect					# 艺术图显示
@export var count_text: Label					# 数量文本显示

# 私有变量
var _count: int = 0								# 数量
@export var width: float = 64.0					# 宽度

# 属性访问器
var count: int:
	get: return _count
	set(value): set_count(value)

# 鼠标点击处理
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_pointer_click()

# 点击事件处理
func _on_pointer_click() -> void:
	if card_viz == null:
		# 显示Aspect信息
		if UIManager.instance and UIManager.instance.aspect_info:
			UIManager.instance.aspect_info.load_aspect(fragment)
	else:
		# 显示卡牌信息
		if UIManager.instance and UIManager.instance.card_info:
			UIManager.instance.card_info.load_card(card_viz)

# 加载Fragment数据（泛型版本）
func load_fragment(frag_data) -> void:
	if frag_data == null:
		return
	
	card_viz = null
	
	# 如果传入的是IFrag接口的实现
	if frag_data.has_method("to_fragment") and frag_data.has_method("count"):
		fragment = frag_data.to_fragment()
		set_count(frag_data.count())
	elif frag_data is Fragment:
		fragment = frag_data
		set_count(1)
	
	# 加载艺术图
	if fragment and art:
		if fragment.art != null:
			art.texture = fragment.art
			art.modulate = Color.WHITE
		else:
			art.texture = null
			art.modulate = fragment.color

# 加载CardViz
func load_card_viz(card_viz_ref: CardViz) -> void:
	if card_viz_ref != null:
		load_fragment(card_viz_ref.card)
		card_viz = card_viz_ref
		set_count(1)

# 设置数量
func set_count(value: int) -> void:
	_count = value
	
	if count_text:
		count_text.text = str(value)
	
	_adjust_size()

# 调整大小
func _adjust_size() -> void:
	if _count == 1:
		# 数量为1时，缩小宽度并隐藏计数文本
		custom_minimum_size.x = width * 0.5
		if count_text:
			count_text.hide()
	else:
		# 数量大于1时，显示完整宽度和计数文本
		custom_minimum_size.x = width
		if count_text:
			count_text.show()

# 初始化
func _ready() -> void:
	set_count(_count)
	
	# 确保接收鼠标输入
	mouse_filter = Control.MOUSE_FILTER_PASS
