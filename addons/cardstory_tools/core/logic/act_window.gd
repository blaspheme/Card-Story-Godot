# ActWindow - 行动窗口
class_name ActWindow
extends Drag

# 行动状态枚举
enum ActStatus {
	IDLE,			# 空闲
	READY,			# 准备就绪
	RUNNING,		# 运行中
	FINISHED		# 已完成
}

# UI 组件引用
@export_group("布局组件")
@export var visuals: Control
@export var label: Label
@export var description_text: RichTextLabel
@export var slots_frag: FragTree
@export var idle_slots_container: Control
@export var run_slots_container: Control
@export var result_lane: CardLane
@export var aspect_bar: FragmentBar
@export var card_bar: FragmentBar
@export var timer: Timer
@export var ok_button: Button
@export var collect_button: Button

# 槽位数组
@export_group("槽位")
@export var idle_slots: Array[SlotViz] = []
@export var run_slots: Array[SlotViz] = []

# 状态变量
var is_open: bool = false
var act_status: ActStatus = ActStatus.IDLE
var ready_act: Act

# 引用
var token_viz: TokenViz
var act_logic: ActLogic

# 内部状态
var suspend_updates: bool = false
var pending_update: bool = false

# 当前使用的槽位列表
var current_slots: Array[SlotViz]:
	get:
		return run_slots if act_status == ActStatus.RUNNING else idle_slots

# 信号
signal window_opened()
signal window_closed()
signal act_started(act: Act)
signal act_completed(act: Act, results: Array[CardViz])

func _ready():
	# 初始化按钮连接
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	
	if collect_button:
		collect_button.pressed.connect(_on_collect_pressed)
	
	# 初始化槽位
	_initialize_slots()

func _initialize_slots():
	# 为所有槽位设置事件连接
	for slot in idle_slots:
		if slot:
			_connect_slot_signals(slot)
	
	for slot in run_slots:
		if slot:
			_connect_slot_signals(slot)

func _connect_slot_signals(slot: SlotViz):
	if not slot.card_slotted.is_connected(_on_slot_card_slotted):
		slot.card_slotted.connect(_on_slot_card_slotted)
	
	if not slot.card_unslotted.is_connected(_on_slot_card_unslotted):
		slot.card_unslotted.connect(_on_slot_card_unslotted)

# 尝试放置卡牌并显示窗口
func try_slot_and_bring_up(card_viz: CardViz) -> bool:
	if act_status == ActStatus.FINISHED:
		return false
	
	var slot_viz = accepts_card(card_viz)
	if slot_viz and slot_viz.try_slot_card(card_viz):
		bring_up()
		return true
	
	return false

# 检查哪个槽位接受此卡牌
func accepts_card(card_viz: CardViz, only_empty: bool = false) -> SlotViz:
	for slot in current_slots:
		if slot and slot.visible and slot.accepts_card(card_viz):
			if not only_empty or not slot.slotted_card:
				return slot
	
	return null

# 显示窗口
func bring_up():
	if GameManager.instance:
		GameManager.instance.set_open_window(self)
	
	show()
	is_open = true
	window_opened.emit()

# 关闭窗口
func close():
	match act_status:
		ActStatus.IDLE, ActStatus.READY:
			# 返回所有卡牌到桌面
			_return_cards_to_table()
		_:
			pass
	
	hide()
	is_open = false
	
	if GameManager.instance:
		GameManager.instance.close_window()
	
	window_closed.emit()

# 执行行动
func go_for_it():
	if act_status == ActStatus.READY and ready_act:
		act_started.emit(ready_act)
		_execute_act()

# 第一个槽位变空时调用
func first_slot_empty():
	if not suspend_updates and act_status != ActStatus.RUNNING:
		# 清空所有其他槽位
		for slot in current_slots:
			if slot and slot != current_slots[0]:
				slot.close_slot()
		
		update_slots()

# 设置Fragment记忆（从卡牌）
func set_frag_memory(card_viz: CardViz):
	if card_viz and slots_frag:
		slots_frag.memory_fragment = card_viz.frag_tree.memory_fragment

# 设置Fragment记忆（直接）
func set_frag_memory_direct(frag: Fragment):
	if slots_frag:
		slots_frag.memory_fragment = frag

# 将槽位中的卡牌设为窗口子节点
func parent_slot_cards_to_window():
	for slot in current_slots:
		if slot and slot.slotted_card:
			slot.parent_card_to_window()

# 高亮匹配的槽位
func highlight_slots(card_viz: CardViz, enable: bool = true):
	for slot in current_slots:
		if slot:
			if enable and slot.accepts_card(card_viz):
				slot.set_highlight(true)
			else:
				slot.set_highlight(false)

# 取消所有槽位高亮
func unhighlight_slots():
	for slot in current_slots:
		if slot:
			slot.set_highlight(false)

# 更新槽位状态
func update_slots():
	if suspend_updates or act_status == ActStatus.FINISHED:
		return
	
	# 关闭所有当前槽位
	_close_slots(current_slots)
	
	var re_update = false
	
	# 打开匹配的槽位
	if token_viz and token_viz.token:
		for slot_resource in token_viz.token.slots:
			if slot_resource:
				_open_slot(slot_resource, current_slots)
				re_update = true
	
	# 如果需要重新更新
	if re_update:
		update_slots()
	else:
		# 检查状态变化
		_check_status_change()

# 关闭槽位列表
func _close_slots(slots: Array[SlotViz]):
	for slot in slots:
		if slot:
			slot.close_slot()

# 打开指定槽位
func _open_slot(slot_resource: Slot, slots: Array[SlotViz]):
	for slot in slots:
		if slot and slot.slot == slot_resource:
			slot.open_slot()
			break

# 设置结果卡牌
func setup_result_cards(cards: Array[CardViz]):
	if result_lane:
		result_lane.place_cards(cards)

# 检查状态变化
func _check_status_change():
	var new_status = _calculate_new_status()
	
	if new_status != act_status:
		_change_status(new_status)

# 计算新状态
func _calculate_new_status() -> ActStatus:
	# 检查是否所有必需槽位都已填充
	var all_required_filled = true
	var has_any_cards = false
	
	for slot in current_slots:
		if slot and slot.visible:
			if slot.slotted_card:
				has_any_cards = true
			elif slot.slot and slot.slot.required:
				all_required_filled = false
	
	if not has_any_cards:
		return ActStatus.IDLE
	elif all_required_filled:
		return ActStatus.READY
	else:
		return act_status  # 保持当前状态

# 改变状态
func _change_status(new_status: ActStatus):
	var old_status = act_status
	act_status = new_status
	
	# 更新UI
	_update_ui_for_status()
	
	print("ActWindow 状态变化: %s -> %s" % [
		ActStatus.keys()[old_status], 
		ActStatus.keys()[new_status]
	])

# 根据状态更新UI
func _update_ui_for_status():
	if not visuals:
		return
	
	match act_status:
		ActStatus.IDLE:
			idle_slots_container.show()
			run_slots_container.hide()
			if ok_button:
				ok_button.disabled = true
		
		ActStatus.READY:
			if ok_button:
				ok_button.disabled = false
		
		ActStatus.RUNNING:
			idle_slots_container.hide()
			run_slots_container.show()
			if ok_button:
				ok_button.disabled = true
		
		ActStatus.FINISHED:
			if collect_button:
				collect_button.disabled = false

# 执行行动
func _execute_act():
	if not ready_act:
		return
	
	act_status = ActStatus.RUNNING
	_update_ui_for_status()
	
	# 这里需要实际的行动逻辑处理
	# 暂时模拟执行
	if timer:
		timer.start_timer(5.0)  # 5秒执行时间
		await timer.timeout
	
	_complete_act()

# 完成行动
func _complete_act():
	act_status = ActStatus.FINISHED
	_update_ui_for_status()
	
	# 生成结果卡牌（这里需要实际逻辑）
	var result_cards: Array[CardViz] = []
	
	act_completed.emit(ready_act, result_cards)
	setup_result_cards(result_cards)

# 返回卡牌到桌面
func _return_cards_to_table():
	for slot in current_slots:
		if slot and slot.slotted_card:
			var card = slot.unslot_card()
			if card and GameManager.instance and GameManager.instance.table:
				GameManager.instance.table.return_to_table(card)

# 按钮事件处理
func _on_ok_pressed():
	if act_status == ActStatus.READY:
		go_for_it()

func _on_collect_pressed():
	if act_status == ActStatus.FINISHED:
		close()

# 槽位事件处理
func _on_slot_card_slotted(slot: SlotViz, card: CardViz):
	if slot.first_slot and not card:
		first_slot_empty()
	
	update_slots()

func _on_slot_card_unslotted(slot: SlotViz, card: CardViz):
	update_slots()

# 保存窗口状态
func save() -> Dictionary:
	var save_data = {
		"is_open": is_open,
		"act_status": act_status,
		"ready_act": ready_act.resource_path if ready_act else "",
		"position": global_position,
		"slots": [],
		"result_lane": result_lane.save() if result_lane else {}
	}
	
	# 保存槽位状态
	for slot in current_slots:
		if slot:
			save_data.slots.append(slot.save())
	
	return save_data

# 加载窗口状态
func load_from_dict(save_data: Dictionary):
	if save_data.has("is_open"):
		is_open = save_data.is_open
		visible = is_open
	
	if save_data.has("act_status"):
		act_status = save_data.act_status
		_update_ui_for_status()
	
	if save_data.has("ready_act") and save_data.ready_act != "":
		ready_act = load(save_data.ready_act) as Act
	
	if save_data.has("position"):
		global_position = save_data.position
	
	# 加载槽位状态
	if save_data.has("slots"):
		var slot_saves = save_data.slots
		for i in range(min(slot_saves.size(), current_slots.size())):
			if current_slots[i]:
				current_slots[i].load_from_dict(slot_saves[i])
	
	# 加载结果通道
	if save_data.has("result_lane") and result_lane:
		result_lane.load_from_dict(save_data.result_lane)

# 获取窗口信息（调试用）
func get_window_info() -> String:
	return "ActWindow[%s]: %s, 槽位: %d" % [
		ready_act.get_display_name() if ready_act else "未知行动",
		ActStatus.keys()[act_status],
		current_slots.size()
	]