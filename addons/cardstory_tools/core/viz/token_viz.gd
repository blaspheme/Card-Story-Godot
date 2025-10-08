# TokenViz - 令牌可视化组件
# 负责令牌在游戏中的可视化、交互、计时以及与 ActWindow 的联动
# 遵循 AGENTS.md 代码风格：大量中文注释，使用 tabs 缩进
class_name TokenViz
extends Control

# 导出属性（供编辑器设置）
@export var token: Token
@export var auto_play: Act
@export var init_rule: Rule
@export var memory_fragment: Fragment
@export var CellCount: Vector2i = Vector2i.ONE

# 内部状态
var _act_window: ActWindow
var result_count: int = 0
var dragging_plane: Control

# 编辑器节点绑定（约定节点路径）
@onready var title: Label = $Title
@onready var _timer: Timer = $Timer
@onready var result_counter: Label = $ResultCounter
@onready var result_counter_go: Control = $ResultCounterGO
@onready var art_back: TextureRect = $ArtBack
@onready var highlight: TextureRect = $Highlight
@onready var art: TextureRect = $Art

# 属性访问器，匹配原 C# 属性风格
var act_window: ActWindow:
	get:
		return _act_window
	set(value):
		_act_window = value

var timer:
	get:
		return _timer
	set(value):
		_timer = value

# 返回表格占用尺寸（ArrayTable 需要）
func GetCellSize() -> Vector2i:
	return CellCount

# Godot 初始化
func _ready() -> void:
	# 拖拽平面从 GameManager 获取
	dragging_plane = GameManager.instance.card_drag_plane if GameManager.instance else null

	# 如果在编辑器中直接设置了 token，则加载显示
	if token:
		LoadToken(token)

	# 如果没有 window，创建并初始化
	if not act_window and GameManager.instance:
		act_window = GameManager.instance.create_window()
		if act_window:
			act_window.load_token(self)
			if init_rule:
				act_window.get_act_logic().force_rule(init_rule)
			show_timer(false)

	# 将 token 注册到 GameManager
	if GameManager.instance:
		GameManager.instance.add_token(self)

# 拖拽/放置处理 - Godot 的放置通常由父节点或表格管理实现
func OnDrop(event: InputEvent) -> void:
	# 仅响应左键放置
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 这里假设 event 具有 pointer_drag 信息（由父节点传递）
		# ...existing code...
		pass

# 鼠标点击 - 打开 act window
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if act_window:
			act_window.bring_up()

# 消失（溶解）效果
func Dissolve() -> void:
	interactive = false
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0, 0), 1.0)
	tween.tween_callback(Callable(self, "_on_dissolve_complete"))

func _on_dissolve_complete() -> void:
	if GameManager.instance:
		GameManager.instance.destroy_token(self)
	else:
		queue_free()

# 加载令牌数据并更新 UI
func LoadToken(t: Token) -> void:
	if t == null:
		return
	token = t
	if title:
		title.text = token.label
	if token.art:
		art.texture = token.art
	if art_back:
		art_back.modulate = token.color

# 结果计数
func SetResultCount(count: int) -> void:
	result_count = count
	if result_counter:
		result_counter.text = str(count)
	if result_counter_go:
		result_counter_go.visible = result_count > 0

# 高亮
func SetHighlight(p: bool) -> void:
	if highlight:
		highlight.visible = p

# 计时器显示
func ShowTimer(p: bool = true) -> void:
	if timer:
		timer.visible = p

# 抓取卡牌（供 Modifier 使用）
func Grab(card_viz: CardViz) -> bool:
	if card_viz.free:
		var target: Vector2
		if act_window and act_window.is_open():
			target = act_window.global_position
		else:
			target = global_position

		# 在 Godot 中使用 card_viz 的方法进行移动与回调绑定
		card_viz.grab(target, Callable(card_viz, "parent_to_window").bind(act_window), Callable(card_viz, "hide"))
		return true
	return false

# 保存状态（返回 Dictionary，可被 SaveManager 使用）
func Save() -> Dictionary:
	var save := {}
	save.token = token
	save.position = global_position
	save.timer = timer.save() if timer and timer.has_method("save") else {}
	save.window = act_window.save() if act_window and act_window.has_method("save") else {}
	save.logic = act_window.get_act_logic().save() if act_window and act_window.has_method("get_act_logic") else {}
	return save

# 加载状态
func Load(save: Dictionary) -> void:
	if save.has("token"):
		LoadToken(save.token)
	if save.has("position"):
		global_position = save.position
	if GameManager.instance:
		act_window = GameManager.instance.create_window()
		if act_window:
			act_window.load(save.window if save.has("window") else {}, self)
			var act_logic = act_window.get_act_logic() if act_window and act_window.has_method("get_act_logic") else null
			if act_logic and save.has("logic"):
				act_logic.load(save.logic)
			if timer and timer.has_method("load"):
				timer.load(save.timer, act_logic.on_time_up if act_logic and act_logic.has_method("on_time_up") else null)
			show_timer((save.timer.has("duration") and save.timer.duration != 0.0) if typeof(save.timer) == TYPE_DICTIONARY else false)

# 编辑器友好占位
func _get_configuration_warning() -> String:
	if not title or not art:
		return "TokenViz 节点缺少必要子节点 (Title/Art)"
	return ""
