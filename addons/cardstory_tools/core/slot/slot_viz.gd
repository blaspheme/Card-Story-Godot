# SlotViz - 槽位可视化组件
class_name SlotViz
extends Control

# 槽位资源引用
@export var slot: Slot

# UI 组件引用
@export_group("布局组件")
@export var visuals: Control
@export var label: Label
@export var art_renderer: Sprite2D
@export var highlight_renderer: Sprite2D

# 卡牌选项
@export_group("卡牌选项")
@export var accept_all: bool = false			# 接受所有卡牌
@export var grab: bool = false					# 抓取卡牌
@export var card_lock: bool = false				# 卡牌锁定（无法移除）

# 特殊选项
@export_group("特殊选项")
@export var first_slot: bool = false			# 第一个槽位（移除卡牌会关闭其他槽位）

# 私有变量
var act_window: ActWindow
var slotted_card: CardViz

# 属性
var is_open: bool:
	get:
		return visible

# 信号
signal card_slotted(slot: SlotViz, card: CardViz)
signal card_unslotted(slot: SlotViz, card: CardViz)
signal slot_clicked(slot: SlotViz)

func _ready():
	# 查找父窗口
	var parent = get_parent()
	while parent:
		if parent is ActWindow:
			act_window = parent
			break
		parent = parent.get_parent()
	
	# 初始化UI
	_update_display()
	
	# 连接点击事件
	gui_input.connect(_on_gui_input)

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_slot_clicked()

func _on_slot_clicked():
	slot_clicked.emit(self)
	
	# 如果有卡牌且未锁定，尝试移除
	if slotted_card and not card_lock:
		unslot_card()

# 拖拽处理
func _can_drop_data(position: Vector2, data) -> bool:
	if not visible or not data is CardViz:
		return false
	
	var card_viz = data as CardViz
	return accepts_card(card_viz)

func _drop_data(position: Vector2, data):
	if data is CardViz:
		var card_viz = data as CardViz
		try_slot_card(card_viz)

# 尝试放置卡牌
func try_slot_card(card_viz: CardViz) -> bool:
	if not visible or not card_viz:
		return false
	
	if accept_all or accepts_card(card_viz):
		if not slotted_card:
			# 空槽位，直接放置
			slot_card(card_viz)
			return true
		elif not card_lock:
			# 有卡牌但未锁定，替换
			var old_card = unslot_card()
			slot_card(card_viz)
			
			# 将旧卡牌返回桌面
			if old_card and GameManager.instance and GameManager.instance.table:
				GameManager.instance.table.return_to_table(old_card)
			
			return true
	
	return false

# 放置卡牌
func slot_card(card_viz: CardViz):
	if not card_viz or not visible:
		return
	
	# 如果已有卡牌，先移除
	if slotted_card:
		unslot_card()
	
	# 进行逻辑和物理放置
	slot_card_logical(card_viz)
	slot_card_physical(card_viz)
	
	card_slotted.emit(self, card_viz)

# 物理放置（UI层面）
func slot_card_physical(card_viz: CardViz):
	if not card_viz or not visible:
		return
	
	# 设置卡牌位置和父节点
	card_viz.reparent(self)
	card_viz.position = Vector2.ZERO
	
	# 如果槽位UI隐藏，显示它
	if visuals and not visuals.visible:
		visuals.show()
	
	# 如果卡牌正在拖拽，停止拖拽
	if card_viz.has_method("stop_drag") and card_viz.has_method("is_dragging"):
		if card_viz.is_dragging():
			card_viz.stop_drag()

# 逻辑放置（游戏逻辑层面）
func slot_card_logical(card_viz: CardViz):
	if not card_viz or not slot:
		return
	
	slotted_card = card_viz
	
	# 在槽位的FragTree中添加卡牌的Fragment
	if act_window and act_window.slots_frag and card_viz.frag_tree:
		for fragment in card_viz.frag_tree.get_all_fragments():
			act_window.slots_frag.add(fragment)
	
	# 如果卡牌锁定，禁用卡牌交互
	if card_lock and card_viz.has_method("set_interactive"):
		card_viz.set_interactive(false)
	
	# 如果在槽位时暂停衰变
	if card_viz.has_method("get_decay_component"):
		var decay = card_viz.get_decay_component()
		if decay and decay.pause_on_slot:
			decay.pause()
	
	# 设置记忆Fragment
	if act_window:
		act_window.set_frag_memory(card_viz)

# 移除卡牌
func unslot_card() -> CardViz:
	var card = slotted_card
	
	if card:
		# 进行逻辑和物理移除
		unslot_card_logical(card)
		unslot_card_physical(card)
		
		card_unslotted.emit(self, card)
		
		# 如果是第一个槽位，通知窗口
		if first_slot and act_window:
			act_window.first_slot_empty()
	
	return card

# 物理移除
func unslot_card_physical(card_viz: CardViz):
	if not card_viz:
		return
	
	# 移动卡牌到父窗口
	if act_window:
		card_viz.reparent(act_window)

# 逻辑移除
func unslot_card_logical(card_viz: CardViz):
	if not card_viz:
		return
	
	slotted_card = null
	
	# 从槽位FragTree中移除卡牌Fragment
	if act_window and act_window.slots_frag and card_viz.frag_tree:
		for fragment in card_viz.frag_tree.get_all_fragments():
			act_window.slots_frag.remove(fragment)
	
	# 恢复卡牌交互
	if card_viz.has_method("set_interactive"):
		card_viz.set_interactive(true)
	
	# 恢复衰变计时
	if card_viz.has_method("get_decay_component"):
		var decay = card_viz.get_decay_component()
		if decay and decay.pause_on_slot:
			decay.unpause()

# 将卡牌设为窗口子节点
func parent_card_to_window():
	if slotted_card and act_window:
		slotted_card.reparent(act_window)
		
		# 设置位置到窗口中心
		var window_size = act_window.size
		slotted_card.position = window_size / 2

# 关闭槽位
func close_slot():
	hide()
	
	# 如果有抓取功能，尝试抓取合适的卡牌
	if grab and not slotted_card:
		_try_grab_card()

# 打开槽位
func open_slot():
	show()
	_update_display()

# 刷新槽位
func refresh():
	if grab and not slotted_card:
		_try_grab_card()

# 尝试抓取卡牌
func _try_grab_card():
	if not slot or not GameManager.instance:
		return
	
	# 在桌面查找匹配的卡牌
	var table = GameManager.instance.table
	if table and table.has_method("get_cards"):
		var cards = table.get_cards()
		for card_viz in cards:
			if card_viz and accepts_card(card_viz):
				if card_viz.has_method("is_free") and card_viz.is_free():
					try_slot_card(card_viz)
					break

# 检查是否接受此卡牌
func accepts_card(card_viz: CardViz) -> bool:
	if accept_all:
		return true
	
	if not slot or not card_viz:
		return false
	
	# 检查槽位的Fragment要求
	if slot.fragments.is_empty():
		return true
	
	# 检查卡牌是否包含所需Fragment
	for required_fragment in slot.fragments:
		if card_viz.has_method("contains_fragment"):
			if not card_viz.contains_fragment(required_fragment):
				return false
	
	return true

# 设置高亮
func set_highlight(enable: bool):
	if highlight_renderer:
		highlight_renderer.visible = enable

# 更新显示
func _update_display():
	if not slot:
		return
	
	# 更新标签
	if label:
		label.text = slot.get_display_name()
	
	# 更新图标
	if art_renderer and slot.art:
		art_renderer.texture = slot.art

# 保存槽位状态
func save() -> Dictionary:
	return {
		"slot": slot.resource_path if slot else "",
		"slotted_card_id": slotted_card.get_instance_id() if slotted_card else -1,
		"accept_all": accept_all,
		"grab": grab,
		"card_lock": card_lock,
		"first_slot": first_slot
	}

# 加载槽位状态
func load_from_dict(save_data: Dictionary):
	if save_data.has("slot") and save_data.slot != "":
		slot = load(save_data.slot) as Slot
	
	if save_data.has("accept_all"):
		accept_all = save_data.accept_all
	
	if save_data.has("grab"):
		grab = save_data.grab
	
	if save_data.has("card_lock"):
		card_lock = save_data.card_lock
	
	if save_data.has("first_slot"):
		first_slot = save_data.first_slot
	
	# 重建卡牌引用（需要SaveManager配合）
	if save_data.has("slotted_card_id") and save_data.slotted_card_id != -1:
		if SaveManager.instance and SaveManager.instance.has_method("card_from_id"):
			slotted_card = SaveManager.instance.card_from_id(save_data.slotted_card_id)
	
	_update_display()

# 获取槽位信息（调试用）
func get_slot_info() -> String:
	var card_name = "空"
	if slotted_card and slotted_card.has_method("get_card_name"):
		card_name = slotted_card.get_card_name()
	
	return "SlotViz[%s]: %s" % [
		slot.get_display_name() if slot else "未知槽位",
		card_name
	]