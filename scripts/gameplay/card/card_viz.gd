extends DragCardViz
class_name CardViz

## 卡牌可视化组件
## 继承自 DragCardViz，实现具体的卡牌显示和交互逻辑

# 导出变量
## 卡牌的数据资源
@export var card_data: CardData
## Table上卡牌尺寸
@export var cell_count: Vector2i = Vector2i.ONE

# ===============================
# SceneTree引用
# ===============================
@onready var area: Area2D = $Area2D
@onready var frag_tree: FragTree = $Root
@onready var title_label: Label = $Front/VBoxContainer/Title
@onready var front_image: TextureRect = $Front/VBoxContainer/Image
@onready var back_image: TextureRect = $Back
@onready var background: Sprite2D = $Background
@onready var mat: ShaderMaterial = $Background.material
@onready var stack_counter = $StackCounter

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	# 初始化拖拽系统（父类方法）
	_init_drag_system()
	
	# 卡牌特有的初始化
	title_label.text = card_data.label
	front_image.texture = card_data.image
	back_image.texture = card_data.image
	
	# 组件赋值
	stack_counter.parent_node = self

# ===============================
# 实现父类抽象方法
# ===============================

## 获取 Area2D 节点
func _get_area() -> Area2D:
	return area

## 获取背景节点
func _get_background() -> Node2D:
	return background

## 获取材质
func _get_material() -> ShaderMaterial:
	return mat

## 检查是否允许拖拽（重写以添加堆叠拖拽检查）
func _can_start_drag() -> bool:
	# 如果是堆叠拖拽状态，不允许单卡拖拽
	return not stack_counter.stack_drag

# ===============================
# 信号回调（连接到场景中的信号）
# ===============================

## 鼠标进入逻辑（转发给父类）
func _on_area_2d_mouse_entered() -> void:
	_on_area_mouse_entered()

## 鼠标退出逻辑（转发给父类）
func _on_area_2d_mouse_exited() -> void:
	_on_area_mouse_exited()

## 卡牌输入逻辑（转发给父类）
@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_input(event as InputEventMouseButton)
