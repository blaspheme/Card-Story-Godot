extends Viz
class_name TokenViz

#region 参数
@export_category("Token")
@export var token_data: TokenData
@export var auto_play: ActData
@export var init_rule: RuleData
@export var memory_fragment: FragmentData

# SceneTree引用
@onready var area: Area2D = $Area2D
@onready var title: Label = $Visuals/Label
@onready var front_image: TextureRect = $Visuals/Image
@onready var background: Sprite2D = $Visuals/Background
@onready var mat: ShaderMaterial = $Visuals/Background.material
@onready var token_timer: TokenTimer = $Timer

var act_window: ActWindow
var result_count: int
#endregion

#region 生命周期方法
func _ready() -> void:
	load_token(token_data)
	_init_drag_system()
	token_timer.start_timer(5)
	if Manager.GM:
		dragging_plane = Manager.GM.card_drag_plane
		if act_window == null:
			act_window = Manager.GM.create_window()

		Manager.GM.add_token(self)
#endregion

#region 实现父类抽象方法
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
#endregion

#region 信号回调（连接到场景中的信号）
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
#endregion

#region 保存和加载数据逻辑
func save_state() -> TokenVizState:
	var _save = TokenVizState.new()
	_save.token = token_data
	_save.position = position
	
	return _save

func load_state(_save: TokenVizState) -> void:
	load_token(_save.token)
	global_position = _save.position
	act_window = Manager.GM.create_window()
	#act_window.load_state(_save.window_save, self)
	

func load_token(_token: TokenData) -> void:
	if _token == null:
		return

	token_data = _token
	title.text = _token.label.get_text()
	front_image.texture = _token.image

	name = "[TOKEN] " + _token.resource_path.get_file().get_basename()
#endregion
