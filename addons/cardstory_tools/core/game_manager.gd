# GameManager - 游戏主管理器
class_name GameManager
extends Node

# 单例实例
static var instance: GameManager

# 预制体引用
@export var card_prefab: PackedScene
@export var token_prefab: PackedScene  
@export var act_window_prefab: PackedScene
@export var fragment_prefab: PackedScene

# 根节点和核心组件
@export var root: FragTree
@export var table: Table
@export var heap: FragTree

# UI 平面
@export var window_plane: Control
@export var card_drag_plane: Control

# 卡牌变换时间配置
@export_group("动画时间")
@export var normal_speed: float = 1.0
@export var fast_speed: float = 0.5
@export var rotate_speed: float = 0.3
@export var scale_speed: float = 0.2

# 特殊 Fragment 引用
@export_group("特殊Fragment")
@export var this_aspect: Fragment
@export var this_card: Fragment
@export var matched_cards: Fragment
@export var memory_fragment: Fragment

# 时间控制
@export_group("时间控制")
@export var time_scale: float = 1.0
@export var max_time: float = 0.0
@export var all_time: float = 0.0

# 配置
@export_group("配置")
@export var has_localization: bool = false

# 信号
signal card_in_play(card_viz: CardViz)

# 私有变量
var _tokens: Array[TokenViz] = []
var _windows: Array[ActWindow] = []
var _open_window: ActWindow
var _elapsed_time: float = 0.0
var _initial_acts: Array[Act] = []
var _slot_sos: Array[Slot] = []

# 属性访问器
var cards: Array[CardViz]:
	get:
		return root.cards if root else []

var tokens: Array[TokenViz]:
	get:
		return _tokens

var windows: Array[ActWindow]:
	get:
		return _windows

var initial_acts: Array[Act]:
	get:
		return _initial_acts

var slot_sos: Array[Slot]:
	get:
		return _slot_sos

var open_window: ActWindow:
	get:
		return _open_window
	set(value):
		_open_window = value

var game_time: float:
	get:
		return _elapsed_time

var dev_time_on: bool:
	get:
		return max_time > 0 or all_time > 0

func _ready():
	# 设置单例
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	
	# 初始化
	time_scale = 1.0
	_find_initial_acts()
	_find_slot_sos()
	
	# 验证特殊 Fragment 是否设置
	if not this_aspect or not this_card or not matched_cards or not memory_fragment:
		push_error("GameManager 的特殊 Fragment 未设置！")

func _process(delta):
	_elapsed_time += delta * time_scale

# 获取开发时间
func get_dev_time(time: float) -> float:
	if max_time > 0:
		return min(time, max_time)
	elif all_time > 0:
		return all_time
	else:
		return time

# 窗口管理
func close_window():
	_open_window = null

func set_open_window(window: ActWindow):
	if _open_window != window:
		if _open_window:
			_open_window.close()
		_open_window = window

# 卡牌在场触发
func trigger_card_in_play(card_viz: CardViz):
	card_in_play.emit(card_viz)

# 创建卡牌
func create_card() -> CardViz:
	if not card_prefab:
		push_error("卡牌预制体未设置")
		return null
	
	var card_viz = card_prefab.instantiate() as CardViz
	if card_viz:
		card_viz.dragging_plane = card_drag_plane
	return card_viz

func create_card_with_data(card: Card) -> CardViz:
	if _is_allowed_to_create(card):
		var card_viz = create_card()
		if card_viz:
			card_viz.load_card(card)
		return card_viz
	return null

# 销毁卡牌
func destroy_card(card_viz: CardViz):
	if not card_viz:
		return
	
	card_viz.set_parent(null)
	
	# 创建销毁动画
	var tween = create_tween()
	tween.tween_property(card_viz, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): card_viz.queue_free())

# 令牌管理
func add_token(token_viz: TokenViz):
	if token_viz and not _tokens.has(token_viz):
		_tokens.append(token_viz)

func create_token() -> TokenViz:
	if not token_prefab:
		push_error("令牌预制体未设置")
		return null
	
	var token_viz = token_prefab.instantiate() as TokenViz
	if token_viz:
		add_token(token_viz)
	return token_viz

func create_token_with_data(token: Token) -> TokenViz:
	var token_viz = create_token()
	if token_viz:
		token_viz.load_token(token)
	return token_viz

func destroy_token(token_viz: TokenViz):
	if not token_viz:
		return
	
	_tokens.erase(token_viz)
	if table:
		table.remove_viz(token_viz)
	
	# 延迟销毁
	await get_tree().create_timer(0.1).timeout
	token_viz.queue_free()

# 窗口管理
func add_window(act_window: ActWindow):
	if act_window and not _windows.has(act_window):
		_windows.append(act_window)

func create_window() -> ActWindow:
	if not act_window_prefab or not window_plane:
		push_error("窗口预制体或窗口平面未设置")
		return null
	
	var act_window = act_window_prefab.instantiate() as ActWindow
	if act_window:
		window_plane.add_child(act_window)
		add_window(act_window)
	return act_window

func destroy_window(act_window: ActWindow):
	if not act_window:
		return
	
	_windows.erase(act_window)
	
	# 延迟销毁
	await get_tree().create_timer(0.1).timeout
	act_window.queue_free()

# 生成行动
func spawn_act(act: Act, spawner: FragTree, viz: Viz) -> TokenViz:
	if not act or not act.token:
		return null
	
	var new_token_viz = spawn_token(act.token, spawner, viz)
	if new_token_viz:
		new_token_viz.auto_play = act
		new_token_viz.init_rule = act.on_spawn
	
	return new_token_viz

# 生成令牌
func spawn_token(token: Token, spawner: FragTree, viz: Viz) -> TokenViz:
	if not token:
		return null
	
	# 检查唯一性
	if token.unique:
		for existing_token in _tokens:
			if existing_token.token == token:
				return null
	
	var new_position = viz.global_position if viz else Vector2.ZERO
	var new_token_viz = create_token_with_data(token)
	
	if not new_token_viz:
		return null
	
	new_token_viz.global_position = new_position
	if spawner:
		new_token_viz.memory_fragment = spawner.memory_fragment
	
	# 放置到桌面或特定位置
	if viz and table:
		table.place_viz(viz, [new_token_viz])
	elif table:
		table.return_to_table(new_token_viz)
	
	# 生成动画
	var original_scale = new_token_viz.scale
	new_token_viz.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.tween_property(new_token_viz, "scale", original_scale, 1.0)
	
	return new_token_viz

# 时间设置
func set_time_scale(ts: float):
	time_scale = ts

func set_max_time(time: float):
	max_time = time
	all_time = 0.0

func set_all_time(time: float):
	all_time = time
	max_time = 0.0

# 保存游戏
func save_game():
	if not SaveManager.instance:
		push_error("SaveManager 未初始化")
		return
	
	# 完成所有动画
	var tweens = get_tree().get_nodes_in_group("tweens")
	for tween in tweens:
		if tween.has_method("kill"):
			tween.kill()
	
	var save_data = GameManagerSave.new()
	
	# 保存卡牌
	for card_viz in cards:
		if card_viz.has_method("save"):
			save_data.cards.append(card_viz.save())
	
	# 保存令牌
	for token_viz in _tokens:
		if token_viz.has_method("save"):
			save_data.tokens.append(token_viz.save())
	
	# 保存牌库
	if DeckManager.instance:
		save_data.decks = DeckManager.instance.deck_instances
	
	# 保存桌面状态
	if table and table.has_method("save"):
		save_data.table = table.save()
	
	# 序列化保存
	var json_save = JSON.stringify(save_data.to_dict())
	SaveManager.instance.save(json_save)

# 加载游戏
func load_game():
	reset_game()
	
	if not SaveManager.instance:
		push_error("SaveManager 未初始化")
		return
	
	var json_save = SaveManager.instance.load()
	if json_save.is_empty():
		return
	
	var json = JSON.new()
	var parse_result = json.parse(json_save)
	if parse_result != OK:
		push_error("保存文件解析失败")
		return
	
	var save_data = GameManagerSave.new()
	save_data.from_dict(json.data)
	
	# 重建卡牌
	for card_save in save_data.cards:
		var card_viz = create_card()
		if card_viz and SaveManager.instance.has_method("register_card"):
			SaveManager.instance.register_card(card_save.id, card_viz)
	
	# 加载卡牌数据
	for card_save in save_data.cards:
		if SaveManager.instance.has_method("card_from_id"):
			var card_viz = SaveManager.instance.card_from_id(card_save.id)
			if card_viz and card_viz.has_method("load"):
				card_viz.load(card_save)
	
	# 重建令牌
	for token_save in save_data.tokens:
		var token_viz = create_token()
		if token_viz and token_viz.has_method("load"):
			token_viz.load(token_save)
			if table:
				table.add_child(token_viz)
	
	# 重新父化卡牌
	for card_save in save_data.cards:
		if SaveManager.instance.has_method("card_from_id"):
			var card_viz = SaveManager.instance.card_from_id(card_save.id)
			if card_viz and not card_viz.get_parent() and table:
				table.add_child(card_viz)
	
	# 加载牌库
	if DeckManager.instance and DeckManager.instance.has_method("load"):
		DeckManager.instance.load(save_data.decks)
	
	# 最后加载桌面状态
	if table and table.has_method("load"):
		table.load(save_data.table)

# 重置游戏
func reset_game():
	# 完成所有动画
	var tweens = get_tree().get_nodes_in_group("tweens")
	for tween in tweens:
		if tween.has_method("kill"):
			tween.kill()
	
	# 销毁所有卡牌
	for i in range(cards.size() - 1, -1, -1):
		destroy_card(cards[i])
	
	# 销毁所有令牌
	for i in range(_tokens.size() - 1, -1, -1):
		destroy_token(_tokens[i])
	_tokens.clear()
	
	# 销毁所有窗口
	for i in range(_windows.size() - 1, -1, -1):
		destroy_window(_windows[i])
	_windows.clear()
	
	# 重置牌库管理器
	if DeckManager.instance and DeckManager.instance.has_method("reset"):
		DeckManager.instance.reset()
	
	# 重置UI
	_open_window = null
	if UIManager.instance:
		if UIManager.instance.has_method("reset_ui"):
			UIManager.instance.reset_ui()

# 私有方法
func _is_allowed_to_create(card: Card) -> bool:
	if not card.unique:
		return true
	else:
		return root.count(card) == 0 if root else true

func _find_initial_acts():
	_initial_acts.clear()
	# 在 Godot 中，我们需要手动加载资源
	var acts_path = "res://resources/acts"
	if DirAccess.dir_exists_absolute(acts_path):
		var dir = DirAccess.open(acts_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres") or file_name.ends_with(".res"):
					var act = load(acts_path + "/" + file_name) as Act
					if act and act.initial:
						_initial_acts.append(act)
				file_name = dir.get_next()

func _find_slot_sos():
	_slot_sos.clear()
	# 加载所有 Slot 资源
	var slots_path = "res://resources/slots"
	if DirAccess.dir_exists_absolute(slots_path):
		var dir = DirAccess.open(slots_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres") or file_name.ends_with(".res"):
					var slot = load(slots_path + "/" + file_name) as Slot
					if slot:
						_slot_sos.append(slot)
				file_name = dir.get_next()

# 游戏管理器保存数据类
class GameManagerSave:
	var cards: Array = []
	var tokens: Array = []
	var decks: Array = []
	var table: String = ""
	
	func _init():
		cards = []
		tokens = []
		decks = []
		table = ""
	
	func to_dict() -> Dictionary:
		return {
			"cards": cards,
			"tokens": tokens,
			"decks": decks,
			"table": table
		}
	
	func from_dict(data: Dictionary):
		if data.has("cards"):
			cards = data.cards
		if data.has("tokens"):
			tokens = data.tokens
		if data.has("decks"):
			decks = data.decks
		if data.has("table"):
			table = data.table
