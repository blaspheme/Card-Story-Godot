extends Control
class_name AspectInfo

## Aspect/Fragment 信息面板，显示碎片的名称、描述和图标

#region 子节点引用
## 图标显示（Sprite 或颜色块）
@onready var art: TextureRect = $Image
## 描述文本
@onready var description_label: Label = $Description
## 名称文本
@onready var aspect_name_label: Label = $Name
#endregion

#region 公共方法
## 加载 Aspect 信息
func load_aspect(aspect: FragmentData) -> void:
	if not aspect:
		return
	
	visible = true
	
	aspect_name_label.text = aspect.label.get_text()
	description_label.text = aspect.description.get_text()
	
	if aspect.art:
		art.texture = aspect.art
		art.modulate = Color.WHITE
	else:
		art.texture = null
		art.modulate = aspect.color

## 卸载信息面板
func unload() -> void:
	aspect_name_label.text = ""
	description_label.text = ""
	art.texture = null
	art.modulate = Color.WHITE
	
	visible = false
#endregion

#region 生命周期
func _ready() -> void:
	# 初始状态隐藏
	visible = false
#endregion
