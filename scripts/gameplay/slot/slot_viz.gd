extends Node2D
class_name SlotViz

## 卡牌槽位可视化组件，提供卡片放置、自动抓取、显示/隐藏等功能

# ===============================
# 信号定义
# ===============================
## 卡片插入槽位时发出
signal card_slotted(card: CardViz)
## 卡片从槽位移除时发出
signal card_unslotted(card: CardViz)
## 槽位被点击时发出
signal slot_clicked(slot_viz: SlotViz)

# ===============================
# 导出属性
# ===============================
## 槽位数据资源
@export var slot_data: SlotData

## 是否自动抓取符合条件的卡片（从全局桌面）
var grab: bool = false

## 卡片是否锁定（不可移除）
var card_lock: bool = false

## 是否为首个槽位（移除卡片时触发特殊逻辑）
var first_slot: bool = false

# ===============================
# 节点引用
# ===============================
@onready var area: Area2D = $Area2D
@onready var title_label: Label = $Visuals/Label

# ===============================
# 私有属性
# ===============================
var _slotted_card: CardViz = null
var _act_window = null  # ActWindow 引用，在 Awake 时通过 get_parent 或外部设置
var _grab_listener_id: int = -1  # EventBus 监听器 ID

# ===============================
# 公开属性
# ===============================
## 槽位是否开放（通过节点可见性控制）
var is_open: bool:
	get:
		return visible

## 当前插入的卡片
var slotted_card: CardViz:
	get:
		return _slotted_card

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	title_label.text = slot_data.label
	
	# 获取父 ActWindow（如果存在）
	_act_window = _find_act_window()
	
	# 连接 Area2D 信号用于拖拽检测
	if area:
		area.input_event.connect(_on_area_input_event)
		area.mouse_entered.connect(_on_area_mouse_entered)
		area.mouse_exited.connect(_on_area_mouse_exited)
	


func _exit_tree() -> void:
	# 清理事件监听
	if _grab_listener_id != -1:
		EventBus.unsubscribe("card_in_play", _grab_listener_id)

# ===============================
# 槽位管理方法
# ===============================

## 打开槽位
func open_slot() -> void:
	visible = true
	refresh()

## 关闭槽位
func close_slot() -> void:
	visible = false
	slot_data = null
	
	# 移除抓取监听
	if grab and _grab_listener_id != -1:
		EventBus.unsubscribe("card_in_play", _grab_listener_id)
		_grab_listener_id = -1

## 刷新槽位状态（尝试自动抓取）
func refresh() -> void:
	if grab and _slotted_card == null:
		# 尝试从桌面抓取卡片
		var cards = _get_all_cards()
		for card in cards:
			if _try_grab(card):
				return
		
		# 如果没抓到，注册监听器等待新卡
		if _grab_listener_id == -1:
			_grab_listener_id = EventBus.subscribe("card_in_play", _on_card_in_play)
	
	elif slot_data and slot_data.grab_from_window and _slotted_card == null:
		# 从 ActWindow 内部抓取
		act_grab()

## 从 ActWindow 内部抓取符合条件的卡片
func act_grab() -> void:
	if _act_window == null or not _act_window.has_method("get_cards"):
		return
	
	var window_cards = _act_window.get_cards()
	for card in window_cards:
		if accepts_card(card):
			# TODO: CardViz 需要 is_free 属性
			# card.is_free = true
			if card.has_method("set_interactive"):
				card.set_interactive(true)
			if card.has_method("show_card"):
				card.show_card()
			slot_card(card)
			return

# ===============================
# 卡片插入/移除逻辑
# ===============================

## 尝试插入卡片
func try_slot_card(card: CardViz) -> bool:
	if not visible or card == null:
		return false
	
	if not accepts_card(card):
		return false
	
	# 槽位为空，直接插入
	if _slotted_card == null:
		slot_card(card)
		return true
	
	# 槽位已有卡且未锁定，替换
	elif not card_lock:
		var old_card = unslot_card()
		_return_card_to_table(old_card)
		slot_card(card)
		return true
	
	return false

## 插入卡片（完整流程）
func slot_card(card: CardViz) -> void:
	if card == null:
		return
	
	# 如果是堆叠卡，只取顶部一张
	var card_to_slot = card
	if card.has_method("yield_card"):
		card_to_slot = card.yield_card()
	
	# 逻辑插入
	slot_card_logical(card_to_slot)
	
	# 物理插入
	slot_card_physical(card_to_slot)
	
	# 如果弹出的卡与原卡不同，将原卡退回桌面
	if card != card_to_slot:
		_return_card_to_table(card)

## 逻辑插入：更新数据、添加 fragments
func slot_card_logical(card: CardViz) -> void:
	if card == null or slot_data == null:
		return
	
	_slotted_card = card
	
	# 将 slot 的 fragments 添加到 ActWindow
	if _act_window != null and _act_window.has_method("add_fragment"):
		for frag in slot_data.fragments:
			_act_window.add_fragment(frag)
	
	# 标记卡为非自由状态
	if card_lock:
		if card.has_method("set_interactive"):
			card.set_interactive(false)
		# TODO: CardViz 需要添加 is_free 属性（free 是 GDScript 保留字）
		# card.is_free = false
	
	# 发送信号
	card_slotted.emit(card)

## 物理插入：Parent 到槽位、设置位置、隐藏阴影
func slot_card_physical(card: CardViz) -> void:
	if card == null or not visible:
		return
	
	# Parent 到槽位节点
	if card.get_parent() != self:
		card.reparent(self)
	
	card.position = Vector2.ZERO
	
	# 如果 visuals 隐藏，同时隐藏卡片
	card.visible = false

## 移除卡片
func unslot_card() -> CardViz:
	if _slotted_card == null:
		return null
	
	var card = _slotted_card
	_slotted_card = null
	
	# 恢复卡片状态
	# TODO: CardViz 需要添加 is_free 属性
	# card.is_free = true
	if card.has_method("set_interactive"):
		card.set_interactive(true)
	
	# 恢复阴影
	if card.has_method("cast_shadow"):
		card.cast_shadow(true)
	
	# 从 ActWindow 移除 fragments
	if _act_window != null and _act_window.has_method("remove_fragment") and slot_data != null:
		for frag in slot_data.fragments:
			_act_window.remove_fragment(frag)
	
	# 如果是首个槽位，触发特殊逻辑
	if first_slot and _act_window != null and _act_window.has_method("first_slot_empty"):
		_act_window.first_slot_empty()
	
	# 发送信号
	card_unslotted.emit(card)
	
	return card

## 将已插入的卡 Parent 到 ActWindow
func parent_card_to_window() -> void:
	if _slotted_card != null and _act_window != null:
		var card = _slotted_card
		_slotted_card = null
		card.reparent(_act_window)

# ===============================
# 卡片接受规则
# ===============================

## 检查是否接受该卡片
func accepts_card(card: CardViz) -> bool:
	if slot_data == null or card == null:
		return false
	
	# 如果 slot_data 有 accepts_all 标志（从 SlotData 读取）
	if slot_data.accept_all:
		return true
	
	# TODO: 实现完整的规则检查（required/essential/forbidden fragments、card_rule 等）
	# 这里先简化为始终返回 true，后续按 SlotData 完善
	return true

# ===============================
# 自动抓取逻辑
# ===============================

## 尝试抓取卡片（带动画）
func _try_grab(card: CardViz, bring_up: bool = false) -> bool:
	# TODO: 需要检查 card.is_free 属性
	if card == null or not accepts_card(card):
		return false
	
	# 计算目标位置
	var target_pos = global_position
	if not is_open and _act_window != null and _act_window.has_method("get_token_target_position"):
		target_pos = _act_window.get_token_target_position()
	
	# 使用卡片的 Grab 方法（如果存在）
	if card.has_method("grab_to"):
		var on_start = func(): slot_card_logical(card)
		var on_complete = func():
			slot_card_physical(card)
			if bring_up and _act_window != null and _act_window.has_method("bring_up"):
				_act_window.bring_up()
		
		return card.grab_to(target_pos, on_start, on_complete)
	else:
		# 没有动画，直接插入
		slot_card(card)
		return true

## EventBus 事件处理：新卡进入游戏
func _on_card_in_play(card: CardViz) -> void:
	if _try_grab(card):
		# 抓取成功，移除监听
		EventBus.unsubscribe("card_in_play", _grab_listener_id)
		_grab_listener_id = -1

# ===============================
# 显示/隐藏与高亮
# ===============================

## 显示槽位
func show_slot() -> void:
	visible = true
	if _slotted_card != null and _slotted_card.has_method("show_card"):
		_slotted_card.show_card()

## 隐藏槽位
func hide_slot() -> void:
	visible = false
	if _slotted_card != null and _slotted_card.has_method("hide_card"):
		_slotted_card.hide_card()

# ===============================
# 输入事件处理
# ===============================

## Area2D 输入事件（处理拖拽放置）
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	# 处理点击事件
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_clicked()

func _on_area_mouse_entered() -> void:
	# 可选：鼠标进入时的反馈
	pass

func _on_area_mouse_exited() -> void:
	# 可选：鼠标离开时的反馈
	pass

## 槽位被点击
func _on_slot_clicked() -> void:
	# 高亮桌面上所有可接受的卡片
	var cards = _get_all_cards()
	var matching_cards = []
	for card in cards:
		if accepts_card(card):
			matching_cards.append(card)
	
	# 通过 EventBus 或 GameManager 高亮卡片
	if GameManager.has_method("highlight_cards"):
		GameManager.highlight_cards(matching_cards)
	
	# 发送信号供 UI 监听（显示槽位信息面板等）
	slot_clicked.emit(self)

# ===============================
# 辅助方法
# ===============================

## 查找父 ActWindow
func _find_act_window():
	var parent = get_parent()
	while parent != null:
		if parent.has_method("add_fragment") and parent.has_method("remove_fragment"):
			return parent
		parent = parent.get_parent()
	return null

## 获取所有卡片（从 GameManager 或 Table）
func _get_all_cards() -> Array:
	if GameManager.has_method("get_all_cards"):
		return GameManager.get_all_cards()
	return []

## 将卡片退回桌面
func _return_card_to_table(card: CardViz) -> void:
	if card != null and GameManager.has_method("return_to_table"):
		GameManager.return_to_table(card)
