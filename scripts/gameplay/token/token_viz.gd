extends DragCardViz
class_name TokenViz

@export var token_data: TokenData
# ===============================
# SceneTree引用
# ===============================
@onready var area: Area2D = $Area2D
@onready var front_image: TextureRect = $Visuals/Image
@onready var background: Sprite2D = $Visuals/Background
@onready var mat: ShaderMaterial = $Visuals/Background.material
@onready var token_timer: TokenTimer = $TokenTimer

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	# 初始化拖拽系统（父类方法）
	_init_drag_system()
	
	# 如果有卡片数据，进行初始化
	setup_data()
	token_timer.start_timer(5)
	
	
## 设置卡片数据和外观
func setup_data() -> void:
	if not token_data:
		return
	
	# 卡牌特有的初始化
	front_image.texture = token_data.image

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

## 检查是否允许拖拽、
func _can_start_drag() -> bool:
	# 始终允许拖拽，具体的弹出逻辑在_on_drag_started中处理
	return true

# ===============================
# 信号回调（连接到场景中的信号）
# ===============================

## 鼠标进入逻辑（转发给父类）
func _on_area_2d_mouse_entered() -> void:
	_on_area_mouse_entered()

## 鼠标退出逻辑（转发给父类）
func _on_area_2d_mouse_exited() -> void:
	_on_area_mouse_exited()

## 卡牌输入逻辑
@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			# 开始拖拽处理
			_handle_mouse_input(mouse_event)
