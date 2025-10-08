# AspectInfo - Aspect信息UI组件
class_name AspectInfo
extends Control

# UI组件引用
@export var art_image: TextureRect
@export var description_label: RichTextLabel
@export var aspect_name_label: Label

# 属性访问器
var description: String:
	get:
		return description_label.text if description_label else ""
	set(value):
		if description_label:
			description_label.text = value

var aspect_name: String:
	get:
		return aspect_name_label.text if aspect_name_label else ""
	set(value):
		if aspect_name_label:
			aspect_name_label.text = value

func _ready():
	hide()

# 加载Aspect
func load_aspect(aspect: Fragment):
	if not aspect:
		return
	
	show()
	
	# 设置基本信息
	aspect_name = aspect.get_display_name()
	description = aspect.description
	
	# 设置图像
	if art_image:
		if aspect.art:
			art_image.texture = aspect.art
			art_image.modulate = Color.WHITE
		else:
			art_image.texture = null
			art_image.modulate = aspect.color

# 卸载信息
func unload():
	aspect_name = ""
	description = ""
	
	if art_image:
		art_image.texture = null
		art_image.modulate = Color.WHITE
	
	hide()

# 检查是否已加载
func is_loaded() -> bool:
	return visible

# 设置主题颜色
func set_theme_color(color: Color):
	if aspect_name_label:
		aspect_name_label.modulate = color