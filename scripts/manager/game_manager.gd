extends Node
class_name GameManager

#region 实例化scene
const card_viz = preload("res://scenes/gameplay/viz/card_viz.tscn")
const token_viz = preload("res://scenes/gameplay/viz/token_viz.tscn")
const fragment_viz = preload("res://scenes/gameplay/viz/fragment_viz.tscn")
const act_window = preload("res://scenes/gameplay/viz/act_window.tscn")
const resource_path = "res://resources/data/"
#endregion

#region 导出参数
@export_category("Root")
@export var root: FragTree
@export_category("Planes")
@export var window_plane: Node
@export var card_drag_plane: Node
@export_category("Card transform time")
@export var normal_speed: float = 0.7
@export var fast_speed: float = 0.05
@export var rotate_speed: float = 0.5
@export var scale_speed: float = 0.5
@export_category("Special fragments")
@export var this_aspect: AspectData
@export var this_card: CardData
@export var matched_card: CardData
@export var memory_fragment: FragmentData
@export_category("Time control")
@export var time_scale: float = 1.0
@export var max_time: float
@export var all_time: float
#endregion

#region 类参数
signal on_card_in_play(card_viz)

var windows: Array[ActWindow]
var open_window: ActWindow
var elapsed_time: float
var tokens: Array[TokenViz]
var cards: Array[CardViz]
var initial_acts: Array[ActData]
var slot_sos: Array[SlotData]
#endregion

#region 生命周期方法
func _ready() -> void:
	find_slot_sos()
	find_initial_acts()
	Manager.GM = self

func _process(delta: float) -> void:
	elapsed_time += delta * time_scale

func find_slot_sos() -> void:
	slot_sos.clear()
	var _tmp = FileUtils.find_resources_by_type(resource_path, "SlotData")
	for _t in _tmp:
		slot_sos.append(_t)


func find_initial_acts() -> void:
	initial_acts.clear()
	var _acts = FileUtils.find_resources_by_type(resource_path, "ActData")
	for _act in _acts:
		if _act.initial:
			initial_acts.append(_act)

#endregion

#region DEV
func dev_time_on() -> bool:
	return max_time > 0 or all_time > 0

func dev_time(_time: float) -> float:
	if max_time > 0:
		return min(_time, max_time)
	elif all_time > 0:
		return all_time
	else:
		return _time
#endregion

#region ActWindow操作
func close_window(_window: ActWindow) -> void:
	if open_window == _window:
		open_window = null

func open_window_method(_window: ActWindow) -> void:
	if open_window != _window:
		if is_instance_valid(open_window):
			open_window.close()
		open_window = _window

func add_window(_window: ActWindow) -> void:
	if _window != null and windows.has(_window) == false:
		windows.append(_window)

func create_window() -> ActWindow:
	var _act_window = act_window.instantiate()
	window_plane.add_child(_act_window)
	add_window(_act_window)
	return _act_window

func destroy_window(_window: ActWindow) -> void:
	if _window == null:
		return
	if windows.has(_window):
		windows.erase(_window)
	_window.visible = false
	_window.queue_free()

#endregion

#region Card操作
func card_in_play(_card_viz: CardViz) -> void:
	emit_signal("on_card_in_play", _card_viz)

## 创建新卡片
func create_card(card_data: CardData) -> CardViz:
	if not _allowed_to_create(card_data):
		return null
	var card_instance = card_viz.instantiate() as CardViz
	card_instance.dragging_plane = Manager.GM.card_drag_plane
	card_instance.load_card(card_data)
	return card_instance

## 销毁卡牌
func destroy_card(_card_viz: CardViz) -> void:
	if _card_viz == null:
		return
	_card_viz.parent(null)
	_card_viz.visible = false
	_card_viz.queue_free()

## 返回是否允许创建该 Card
func _allowed_to_create(card: CardData) -> bool:
	if card == null:
		return true
	# 非 unique 卡总是允许
	if not card.unique:
		return true
	# unique 卡：仅在 root 中不存在该 Card 时允许
	return root != null and root.count_card(card) == 0

#endregion

#region Token操作
func add_token(_token_viz: TokenViz) -> void:
	if _token_viz != null and tokens.has(_token_viz) == false:
		tokens.append(_token_viz)

func create_token() -> TokenViz:
	var _token_viz = token_viz.instantiate()
	add_token(_token_viz)
	return _token_viz

func create_token_from_data(_token: TokenData) -> TokenViz:
	var _token_viz = create_token()
	_token_viz.load_token(_token)
	return _token_viz

func destroy_token(_token_viz: TokenViz) -> void:
	if _token_viz == null:
		return
	tokens.erase(_token_viz)
	_token_viz.visible = true
	_token_viz.queue_free()

func spawn_act(_act: ActData, spawner: FragTree, viz: DragCardViz) -> TokenViz:
	if _act == null or _act.token == null:
		return null
	var new_token_viz = spawn_token(_act.token, spawner, viz)
	if new_token_viz != null:
		new_token_viz.auto_play = _act
		new_token_viz.init_rule = _act.on_spawn if _act.has("on_spawn") else null
	return new_token_viz


@warning_ignore("unused_parameter")
func spawn_token(_token: TokenData, spawner: FragTree, viz: DragCardViz) -> TokenViz:
	if _token == null:
		return null

	if _token.unique and tokens.filter(func(t): return t.token == _token).size() != 0:
		return null

	var new_token_viz = token_viz.instantiate() as TokenViz
	new_token_viz.load_token(_token)
	if spawner:
		new_token_viz.memory_fragment = spawner.memory_fragment
	return new_token_viz
#endregion

#region 时间相关
func set_max_time(time: float) -> void:
	max_time = time
	all_time = 0.0

func set_all_time(time: float) -> void:
	all_time = time
	max_time = 0.0
#endregion

#region 保存&加载
func save_state() -> void:
	var _save = GameManagerState.new();
	_save.save(self)

#endregion
