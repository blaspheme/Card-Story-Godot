extends Node2D
class_name CardViz2D

# 导出变量
# 卡牌的数据资源
@export var card_data: CardData

# ===============================
# SceneTree引用
# ===============================
@onready var area: Area2D = $Area2D
@onready var title_label: Label = $Front/VBoxContainer/Title
@onready var front_image: TextureRect = $Front/VBoxContainer/Image
@onready var back_image: TextureRect = $Back
@onready var background: Sprite2D = $Background
@onready var mat: ShaderMaterial = $Background.material

# ===============================
# 属性
# ===============================
var tween: Tween
var is_dragging := false
var drag_offset := Vector2.ZERO

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	# 赋值
	title_label.text = card_data.label
	front_image.texture = card_data.image
	back_image.texture = card_data.image

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
# 鼠标进入逻辑
func _on_area_2d_mouse_entered() -> void:
	_highlight(true)
	mat.set_shader_parameter("outline_strength", 1.0)

# 鼠标退出逻辑
func _on_area_2d_mouse_exited() -> void:
	is_dragging = false # 鼠标离开卡牌即不可拖动
	mat.set_shader_parameter("outline_strength", 0.0)
	_highlight(false)

# 卡牌输入逻辑
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# 拖拽逻辑
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_local_mouse_position()
			tween.kill()
		else:
			is_dragging = false
			# 松开后平滑吸附
			move_to(position.round())
	elif event is InputEventMouseMotion and is_dragging:
		position = get_global_mouse_position() - drag_offset
