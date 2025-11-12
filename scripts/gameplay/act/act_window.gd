extends Node2D
class_name ActWindow

# ===============================
# Act 窗口：管理 Act 执行流程、Slot 系统、结果展示
# ===============================

#region 场景树引用
@onready var visuals: Node2D = $Visuals if has_node("Visuals") else null
@onready var label_text: Label = $Visuals/Label if has_node("Visuals/Label") else null
@onready var text_display: RichTextLabel = $Visuals/Text if has_node("Visuals/Text") else null
@onready var slots_frag: FragTree = $SlotsFragTree if has_node("SlotsFragTree") else null
@onready var idle_slots_container: Node = $IdleSlots if has_node("IdleSlots") else null
@onready var run_slots_container: Node = $RunSlots if has_node("RunSlots") else null
@onready var result_lane: Node = $ResultLane if has_node("ResultLane") else null
@onready var aspect_bar: Node = $AspectBar if has_node("AspectBar") else null
@onready var card_bar: Node = $CardBar if has_node("CardBar") else null
@onready var timer_widget: Node = $Timer if has_node("Timer") else null
@onready var ok_button: Button = $Visuals/OKButton if has_node("Visuals/OKButton") else null
@onready var collect_button: Button = $Visuals/CollectButton if has_node("Visuals/CollectButton") else null
@onready var act_logic: ActLogic = $ActLogic if has_node("ActLogic") else null
#endregion

#region 导出变量
@export var idle_slots: Array[SlotViz] = []
@export var run_slots: Array[SlotViz] = []
#endregion

#region 状态变量
var _open: bool = false
var act_status: GameEnums.ActStatus = GameEnums.ActStatus.IDLE
var ready_act: ActData = null
var token_viz: TokenViz = null

# 更新控制
var suspend_updates: bool = false
var pending_update: bool = false
#endregion

#region 属性访问器
var open: bool:
	get: return _open
	set(value): _open = value

var slots_frag_tree: FragTree:
	get: return slots_frag

var timer: Node:
	get: return timer_widget

var cards: Array[CardViz]:
	get: return act_logic.frag_tree.cards() if act_logic and act_logic.frag_tree else []

var slots: Array[SlotViz]:
	get: return run_slots if act_status == GameEnums.ActStatus.RUNNING else idle_slots
#endregion

#region 生命周期方法
func _ready() -> void:
	# 连接 FragTree 变化事件
	if act_logic and act_logic.frag_tree:
		act_logic.frag_tree.change_event.connect(_on_frag_tree_changed)
	
	# 连接按钮信号
	if ok_button:
		ok_button.pressed.connect(go_for_it)
		ok_button.disabled = true
	
	if collect_button:
		collect_button.pressed.connect(collect_all)
		collect_button.disabled = true
	
	# 初始化状态
	if timer_widget:
		timer_widget.visible = false
	
	if not _open:
		hide_window()
	
	# 关闭所有 Slots
	close_slots(idle_slots)
	close_slots(run_slots)
	
	# 如果有 autoPlay，直接执行
	if token_viz and token_viz.auto_play:
		ready_act = token_viz.auto_play
		force_act(ready_act)
	else:
		update_slots()
		apply_status(act_status)

func _process(_delta: float) -> void:
	if pending_update:
		update_slots()
		check()
		pending_update = false
#endregion

#region 公开接口
## 尝试插槽卡片并打开窗口
func try_slot_and_bring_up(card_viz: CardViz) -> bool:
	if act_status != GameEnums.ActStatus.FINISHED:
		var slot_viz = accepts_card(card_viz)
		if slot_viz and slot_viz.try_slot_card(card_viz):
			bring_up()
			return true
	return false

## 检查是否接受该卡片
func accepts_card(card_viz: CardViz, only_empty: bool = false) -> SlotViz:
	for slot_viz in matching_slots(card_viz, only_empty):
		if slot_viz:
			return slot_viz
	return null

## 打开窗口
func bring_up() -> void:
	show_window()
	_open = true
	if Manager.GM:
		Manager.GM.open_window_method(self)

## 关闭窗口
func close() -> void:
	match act_status:
		GameEnums.ActStatus.IDLE, GameEnums.ActStatus.READY:
			return_cards_to_table()
			status_idle()
	
	hide_window()
	_open = false
	if Manager.GM:
		Manager.GM.close_window(self)

## 执行准备好的 Act
func go_for_it() -> void:
	if act_logic:
		act_logic.run_act(ready_act)

## 第一个 Slot 清空时回调
func first_slot_empty() -> void:
	if not suspend_updates:
		suspend_updates = true
		return_cards_to_table()
		suspend_updates = false
		if act_status != GameEnums.ActStatus.RUNNING:
			status_idle()

## 设置碎片记忆（从卡片）
func set_frag_memory_from_card(card_viz: CardViz) -> void:
	if card_viz and act_logic and act_logic.frag_tree:
		act_logic.frag_tree.memory_fragment = card_viz.frag_tree.memory_fragment

## 设置碎片记忆（从 Fragment）
func set_frag_memory(frag: FragmentData) -> void:
	if act_logic and act_logic.frag_tree:
		act_logic.frag_tree.memory_fragment = frag

## 将 Slot 中的卡片移到窗口
func parent_slot_cards_to_window() -> void:
	for slot in slots:
		if slot and slot.has_method("parent_card_to_window"):
			slot.parent_card_to_window()

## 高亮匹配的 Slots
func highlight_slots(card_viz: CardViz, highlight: bool = true) -> void:
	for slot_viz in matching_slots(card_viz):
		if slot_viz and (not slot_viz.slotted_card or not slot_viz.card_lock):
			slot_viz.set_highlight(highlight)

## 取消所有 Slot 高亮
func unhighlight_slots() -> void:
	for slot_viz in slots:
		if slot_viz and slot_viz.visible:
			slot_viz.set_highlight(false)

## 更新 Slots（检查哪些应该打开/关闭）
func update_slots() -> void:
	if suspend_updates or act_status == GameEnums.ActStatus.FINISHED:
		return
	
	suspend_updates = true
	
	var slots_to_open = act_logic.check_for_slots() if act_logic else []
	var slots_to_refresh: Array[SlotViz] = []
	
	var re_update = false
	for slot_viz in slots:
		if slot_viz and slot_viz.is_open:
			var found_slot = null
			for s in slots_to_open:
				if s == slot_viz.slot:
					found_slot = s
					break
			
			if not found_slot:
				var card_viz = slot_viz.unslot_card()
				slot_viz.close_slot()
				if card_viz:
					re_update = true
					if Manager.GM and Manager.GM.table and Manager.GM.table.has_method("return_to_table"):
						Manager.GM.table.return_to_table(card_viz)
			else:
				slots_to_open.erase(found_slot)
				slots_to_refresh.append(slot_viz)
	
	if re_update:
		suspend_updates = false
		update_slots()
	else:
		for slot_viz in slots_to_refresh:
			if slot_viz.has_method("refresh"):
				slot_viz.refresh()
		
		for slot in slots_to_open:
			open_slot(slot, slots)
		
		suspend_updates = false

## 设置结果卡片到结果区域
func setup_result_cards(result_cards: Array[CardViz]) -> void:
	if result_lane and result_lane.has_method("parent_cards"):
		result_lane.parent_cards(result_cards)
	if token_viz:
		token_viz.set_result_count(result_cards.size())

## 检查状态变化
func check() -> void:
	match act_status:
		GameEnums.ActStatus.IDLE, GameEnums.ActStatus.READY:
			attempt_ready_act()
		
		GameEnums.ActStatus.RUNNING:
			if act_logic:
				act_logic.attempt_alt_acts()
			apply_status(GameEnums.ActStatus.RUNNING)
		
		GameEnums.ActStatus.FINISHED:
			var count = 0
			if result_lane and result_lane.has_method("get_count"):
				count = result_lane.get_count()
			elif result_lane and result_lane.has("cards"):
				count = result_lane.cards.size()
			
			if count == 0:
				status_idle()
				if token_viz and token_viz.token and token_viz.token.dissolve:
					token_viz.dissolve()
					close()
					queue_free()
			else:
				if token_viz:
					token_viz.set_result_count(count)

## 收集所有结果卡片
func collect_all() -> void:
	if not result_lane or not result_lane.has("cards"):
		return
	
	var viz_list: Array = []
	for card_viz in result_lane.cards:
		if card_viz.has_method("show_face"):
			card_viz.show_face()
		
		if Manager.GM and Manager.GM.table and Manager.GM.table.has_method("last_location"):
			if Manager.GM.table.last_location(card_viz):
				Manager.GM.table.return_to_table(card_viz)
			else:
				viz_list.append(card_viz)
	
	if Manager.GM and Manager.GM.table and Manager.GM.table.has_method("place"):
		Manager.GM.table.place(token_viz, viz_list)
	
	result_lane.cards.clear()
	check()

## 加载 Token 数据
func load_token(token: TokenViz) -> void:
	if token:
		token_viz = token
		set_frag_memory(token.memory_fragment)
		name = "[WINDOW] " + (token.token.resource_path if token.token else "Unknown")

## 应用状态
func apply_status(new_status: GameEnums.ActStatus) -> void:
	act_status = new_status
	
	match act_status:
		GameEnums.ActStatus.IDLE:
			if idle_slots_container:
				idle_slots_container.visible = true
			if run_slots_container:
				run_slots_container.visible = false
			if result_lane:
				result_lane.visible = false
			if ok_button:
				ok_button.disabled = true
			if collect_button:
				collect_button.visible = false
			if token_viz:
				token_viz.set_result_count(0)
				if label_text:
					label_text.text = token_viz.token.label if token_viz.token else ""
				if text_display and act_logic:
					text_display.text = act_logic.token_description()
			if card_bar:
				card_bar.visible = true
		
		GameEnums.ActStatus.READY:
			if ready_act:
				if ok_button:
					ok_button.disabled = false
				if label_text:
					label_text.text = ready_act.label
				if text_display and act_logic:
					text_display.text = act_logic.get_text(ready_act)
				if token_viz:
					token_viz.set_result_count(0)
			if collect_button:
				collect_button.visible = false
			if card_bar:
				card_bar.visible = true
		
		GameEnums.ActStatus.RUNNING:
			if timer_widget:
				timer_widget.visible = true
			if idle_slots_container:
				idle_slots_container.visible = false
			if run_slots_container:
				run_slots_container.visible = true
			if ok_button:
				ok_button.disabled = true
			if collect_button:
				collect_button.visible = false
			if token_viz:
				token_viz.set_result_count(0)
			if act_logic:
				if label_text and act_logic.label:
					label_text.text = act_logic.label.get_text() if act_logic.label.has_method("get_text") else str(act_logic.label)
				if text_display and act_logic.run_text:
					text_display.text = act_logic.run_text.get_text() if act_logic.run_text.has_method("get_text") else str(act_logic.run_text)
			if card_bar:
				card_bar.visible = true
		
		GameEnums.ActStatus.FINISHED:
			if timer_widget:
				timer_widget.visible = false
			if run_slots_container:
				run_slots_container.visible = false
			if result_lane:
				result_lane.visible = true
			if collect_button:
				collect_button.disabled = false
				collect_button.visible = true
			if act_logic:
				if label_text and act_logic.label:
					label_text.text = act_logic.label.get_text() if act_logic.label.has_method("get_text") else str(act_logic.label)
				if text_display and act_logic.end_text:
					text_display.text = act_logic.end_text.get_text() if act_logic.end_text.has_method("get_text") else str(act_logic.end_text)
			if card_bar:
				card_bar.visible = false
			check()

## 隐藏窗口
func hide_window() -> void:
	if visuals:
		visuals.visible = false
	for slot in idle_slots:
		if slot and slot.has_method("hide"):
			slot.hide()
	for slot in run_slots:
		if slot and slot.has_method("hide"):
			slot.hide()
	if result_lane and result_lane.has_method("hide"):
		result_lane.hide()

## 显示窗口
func show_window() -> void:
	if visuals:
		visuals.visible = true
	for slot in idle_slots:
		if slot and slot.has_method("show"):
			slot.show()
	for slot in run_slots:
		if slot and slot.has_method("show"):
			slot.show()
	if result_lane and result_lane.has_method("show"):
		result_lane.show()

## 添加碎片
func add_fragment(frag: FragmentData) -> void:
	if act_logic and act_logic.frag_tree:
		act_logic.frag_tree.add_fragment(frag)

## 移除碎片
func remove_fragment(frag: FragmentData) -> void:
	if act_logic and act_logic.frag_tree:
		act_logic.frag_tree.remove_fragment(frag)

## 强制执行 Act
func force_act(act: ActData) -> void:
	if act_logic:
		act_logic.force_act_impl(act)
#endregion

#region 内部方法
## 尝试准备 Act
func attempt_ready_act() -> void:
	if not token_viz or not token_viz.token or not act_logic:
		return
	
	ready_act = act_logic.attempt_initial_acts()
	
	# 防止在没有测试的情况下进入 Ready 状态（除非有卡片插槽）
	if ready_act and idle_slots.size() > 0 and idle_slots[0].slotted_card:
		apply_status(GameEnums.ActStatus.READY)
	else:
		apply_status(GameEnums.ActStatus.IDLE)

## 切换到 Idle 状态
func status_idle() -> void:
	if act_logic:
		act_logic.reset()
	apply_status(GameEnums.ActStatus.IDLE)
	update_slots()

## 将卡片返回到桌面
func return_cards_to_table() -> void:
	for card_slot in idle_slots:
		if card_slot and card_slot.slotted_card:
			var card_viz = card_slot.unslot_card()
			if card_viz and Manager.GM and Manager.GM.table and Manager.GM.table.has_method("return_to_table"):
				Manager.GM.table.return_to_table(card_viz)

## 关闭 Slots 列表
func close_slots(slot_list: Array[SlotViz]) -> void:
	for slot_viz in slot_list:
		if slot_viz and slot_viz.has_method("close_slot"):
			slot_viz.close_slot()

## 打开一个 Slot
func open_slot(slot: SlotData, slot_list: Array[SlotViz]) -> void:
	for slot_viz in slot_list:
		if slot_viz and not slot_viz.visible:
			if slot_viz.has_method("load_slot"):
				slot_viz.load_slot(slot)
			if slot_viz.has_method("open_slot"):
				slot_viz.open_slot()
			break

## 获取匹配的 Slots
func matching_slots(card_viz: CardViz, only_empty: bool = false) -> Array:
	var result: Array = []
	
	if not card_viz:
		return result
	
	if act_status == GameEnums.ActStatus.FINISHED and result_lane and result_lane.has("cards") and result_lane.cards.size() > 0:
		return result
	
	for slot_viz in slots:
		if slot_viz and slot_viz.visible:
			if slot_viz.has_method("accepts_card") and slot_viz.accepts_card(card_viz):
				if not only_empty or not slot_viz.slotted_card:
					result.append(slot_viz)
	
	return result

## FragTree 变化回调
func _on_frag_tree_changed() -> void:
	pending_update = true
#endregion

#region 保存/加载（占位）
## 保存窗口状态
func save_state() -> Dictionary:
	var save = {
		"open": _open,
		"act_status": act_status,
		"ready_act": ready_act.resource_path if ready_act else "",
		"position": global_position,
		"local_cards": [],
		"card_lane": {},
		"slots": []
	}
	
	# 保存直接子卡片
	for child in get_children():
		if child is CardViz:
			save.local_cards.append(child.get_instance_id())
	
	# 保存结果区域
	if result_lane and result_lane.has_method("save_state"):
		save.card_lane = result_lane.save_state()
	
	# 保存激活的 Slots
	for slot_viz in slots:
		if slot_viz and slot_viz.visible and slot_viz.has_method("save_state"):
			save.slots.append(slot_viz.save_state())
	
	return save

## 加载窗口状态
func load_state(save: Dictionary, token: TokenViz) -> void:
	if save.has("position"):
		global_position = save.position
	if save.has("act_status"):
		act_status = save.act_status
	if save.has("ready_act") and save.ready_act != "":
		ready_act = load(save.ready_act)
	if save.has("open"):
		_open = save.open
	
	load_token(token)
	
	# TODO: 加载本地卡片和 Slots 状态
	
	if _open:
		bring_up()
#endregion
