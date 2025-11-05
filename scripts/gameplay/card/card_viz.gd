extends Node2D
class_name CardViz

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
# 属性
# ===============================
var tween: Tween
var is_dragging := false
var drag_offset := Vector2.ZERO
var original_z_index: int = 0  # 记录原始层级

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	# 为每张卡片创建独立的材质副本，避免共享材质
	mat = mat.duplicate() as ShaderMaterial
	background.material = mat
	
	# 赋值
	title_label.text = card_data.label
	front_image.texture = card_data.image
	back_image.texture = card_data.image
	# 组件赋值
	stack_counter.parent_node = $"."
	# 记录原始层级
	original_z_index = z_index
	# 默认不处理输入（只在拖拽时启用）
	set_process_input(false)

# --------------------
# 动画函数
# --------------------
func move_to(target_pos: Vector2, duration := 0.3):
	_create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func rotate_to(deg: float, duration := 0.25):
	_create_tween()
	tween.tween_property(self, "rotation", deg_to_rad(deg), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --------------------
# TODO: 高亮效果，目前不显眼
# --------------------
func _highlight(active: bool):
	_create_tween()
	if active:
		# 更快的反应 + 明显的发光效果
		tween.tween_property(background, "self_modulate", Color(1.2, 1.0, 0.6, 1.0), 0.15)
	else:
		tween.tween_property(background, "self_modulate", Color(1, 1, 1, 1), 0.25)

# 创建 Tewwn 动画
func _create_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
# ===============================
# 信号机制
# ===============================
## 鼠标进入逻辑
func _on_area_2d_mouse_entered() -> void:
	_highlight(true)
	mat.set_shader_parameter("outline_strength", 1.0)

## 鼠标退出逻辑
func _on_area_2d_mouse_exited() -> void:
	mat.set_shader_parameter("outline_strength", 0.0)
	_highlight(false)

## 卡牌输入逻辑
@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if stack_counter.stack_drag:
		# 堆叠拖拽状态，不处理单卡拖拽
		return
	# 点击卡牌逻辑
	if event is InputEventMouseButton:
		_handle_mouse_input_event(viewport, event, shape_idx)


## 处理鼠标输入逻辑
@warning_ignore("unused_parameter")
func _handle_mouse_input_event(viewport: Node, event: InputEventMouseButton, shape_idx: int) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 按下鼠标左键，开始拖拽
		_start_drag()
		# 标记事件已处理，防止下层卡片也触发
		get_viewport().set_input_as_handled()


## 开始拖拽
func _start_drag() -> void:
	is_dragging = true
	drag_offset = get_local_mouse_position()
	if tween:
		tween.kill()
	
	# 提升层级到最顶层，避免被其他卡片遮挡
	z_index = 1000
	
	# 禁用 Area2D 输入，防止拖拽时触发其他事件
	area.input_pickable = false
	
	# 启用输入处理（只处理当前卡片的输入）
	set_process_input(true)


## 结束拖拽
func _end_drag() -> void:
	is_dragging = false
	# 松开后平滑吸附
	move_to(position.round())
	# 恢复原始层级
	z_index = original_z_index
	# 重新启用 Area2D 输入
	area.input_pickable = true
	# 停用输入处理
	set_process_input(false)


## 输入处理（只在拖拽时启用，优先级高于其他卡片）
func _input(event: InputEvent) -> void:
	# 只处理当前正在拖拽的卡片
	if not is_dragging:
		return
	
	if event is InputEventMouseMotion:
		# 鼠标移动时更新卡牌位置
		position = get_global_mouse_position() - drag_offset
		# 标记事件已处理，防止其他节点响应
		get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			# 松开鼠标左键，停止拖拽
			_end_drag()
			# 标记事件已处理
			get_viewport().set_input_as_handled()
