# CardViz - 卡牌可视化组件
# 提供卡牌的显示、交互和动画功能
class_name CardViz
extends Viz

# 卡牌相关
@export var card: Card							# 绑定的卡牌数据
var stack: CardViz								# 堆叠的卡牌引用

# 布局组件
@export_group("布局组件")
@export var frag_tree: FragTree					# Fragment树组件
@export var visuals_go: Control					# 视觉效果根节点
@export var title_label: Label					# 标题文本
@export var art_back: Control					# 卡牌背面艺术图
@export var art: TextureRect					# 卡牌正面艺术图
@export var highlight: Control					# 高亮效果
@export var card_stack: CardStack				# 卡牌堆叠组件
@export var card_decay: CardDecay				# 卡牌衰变组件

# 桌面相关
@export_group("桌面属性")
@export var cell_count: Vector2i = Vector2i(1, 1)	# 在基于数组的桌面上的大小

# 私有变量
var _face_down: bool = false					# 是否背面朝上
var _free: bool = true							# 是否可自由移动

# 属性访问器
var free: bool:
	get: return frag_tree.free if frag_tree else _free
	set(value): 
		_free = value
		if frag_tree:
			frag_tree.free = value

var visible_state: bool:
	get: return visuals_go.visible if visuals_go else false

var face_down: bool:
	get: return _face_down
	set(value): _face_down = value

var decay: CardDecay:
	get: return card_decay

# 实现基类抽象方法
func get_cell_size() -> Vector2i:
	return cell_count

# 卡牌停靠接口实现
func on_card_dock(card_obj: Control) -> void:
	var card_viz = card_obj as CardViz
	if card_viz != null:
		if not card_stack.push(card_viz):
			# 如果无法堆叠，返回桌面
			if GameManager.instance and GameManager.instance.table:
				GameManager.instance.table.return_to_table(card_viz)

func on_card_undock(card_obj: Control) -> void:
	# 卡牌离开停靠位置时的处理
	pass

# 拖拽开始时的处理
func _on_begin_drag(event: InputEventMouseButton) -> void:
	if interactive and event.button_index == MOUSE_BUTTON_LEFT:
		# 如果不是拖拽整个堆叠且堆叠中有多张卡牌，则弹出一张
		if not card_stack.stack_drag and card_stack.count > 1:
			var popped_card = card_stack.pop()
			if popped_card != null:
				# 将拖拽事件转移到弹出的卡牌
				popped_card._on_begin_drag(event)
				return
		
		super._on_begin_drag(event)
		
		# 高亮可放置的位置
		_highlight_valid_slots()

# 拖拽结束时的处理
func _on_end_drag(event: InputEventMouseButton) -> void:
	super._on_end_drag(event)
	_unhighlight_targets()

# 处理拖放事件
func _can_drop_data(position: Vector2, data) -> bool:
	return data is CardViz and interactive

func _drop_data(position: Vector2, data) -> void:
	var dropped_card = data as CardViz
	if dropped_card != null and dropped_card.is_dragging:
		# 处理卡牌堆叠
		if _get_array_table() != null:
			if can_stack(dropped_card):
				var stacked = false
				if dropped_card.card_stack.count > 1:
					stacked = card_stack.merge(dropped_card.card_stack)
				else:
					stacked = card_stack.push(dropped_card)
				
				if stacked:
					dropped_card._on_end_drag(InputEventMouseButton.new())
			return
		
		# 处理放置到插槽卡牌上
		var slot = _get_component_in_parent(self, SlotViz)
		if slot != null:
			slot.on_card_dock(dropped_card)
			return

# 鼠标点击处理
func _gui_input(event: InputEvent) -> void:
	super._gui_input(event)
	
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if interactive:
				if face_down:
					reverse_card()
				else:
					if UIManager.instance and UIManager.instance.card_info:
						UIManager.instance.card_info.load_card(self)
				
				# 双击处理
				if mouse_event.double_click:
					_handle_double_click()

# 鼠标悬停处理
func _on_mouse_entered() -> void:
	if card_decay and card_decay.enabled:
		card_decay.show_timer()

func _on_mouse_exited() -> void:
	if card_decay and card_decay.enabled:
		card_decay.hide_timer()

# 卡牌衰变
func decay_card(target_card: Card, time: float) -> void:
	if card_decay:
		var actual_time = time
		# 在开发模式下可能需要调整时间
		if GameManager.instance:
			actual_time = GameManager.instance.dev_time(time)
		
		card_decay.start_timer(actual_time, target_card)
		
		if not visible_state and card_decay.pause_on_hide:
			card_decay.pause()

# 销毁卡牌
func destroy_card() -> void:
	var parent_dock = _get_component_in_parent(get_parent(), ICardDock)
	if parent_dock:
		parent_dock.on_card_undock(self)
	
	if GameManager.instance:
		GameManager.instance.destroy_card(self)

# 翻转卡牌
func reverse_card(instant: bool = false) -> void:
	if instant:
		rotation_degrees.y += 180.0
	else:
		interactive = false
		var tween = create_tween()
		tween.tween_property(self, "rotation_degrees:y", rotation_degrees.y + 180.0, 0.5)
		tween.tween_callback(func(): interactive = true)
	
	_face_down = !_face_down
	_update_face_display()

# 隐藏卡牌
func hide_card() -> void:
	if visuals_go:
		visuals_go.hide()
	
	if card_decay and card_decay.pause_on_hide:
		card_decay.pause()

# 显示卡牌
func show_card() -> void:
	if visuals_go:
		visuals_go.show()
	
	if card_decay:
		var slot = _get_component_in_parent(self, SlotViz)
		if not card_decay.pause_on_slot or slot == null:
			card_decay.resume()

# 显示卡牌正面
func show_face() -> void:
	_face_down = false
	_update_face_display()

# 显示卡牌背面
func show_back() -> void:
	_face_down = true
	_update_face_display()

# 设置高亮状态
func set_highlight(enabled: bool) -> void:
	if highlight:
		highlight.visible = enabled

# 取消目标高亮
func _unhighlight_targets() -> void:
	if GameManager.instance:
		for token_viz in GameManager.instance.tokens:
			var slot_viz = _get_component_in_children(token_viz, SlotViz)
			if slot_viz:
				slot_viz.set_highlight(false)

# 弹出卡牌（从堆叠中取出一张）
func yield_card() -> CardViz:
	if card_stack.count > 1:
		return card_stack.pop()
	else:
		return self

# 加载卡牌数据
func load_card(new_card: Card, load_fragments: bool = true) -> void:
	if new_card == null:
		return
	
	card = new_card
	
	# 加载标题
	if title_label:
		title_label.text = card.get_display_name()
	
	# 加载艺术图
	if art:
		if card.art != null:
			art.texture = card.art
			art.modulate = Color.WHITE
		else:
			art.texture = null
			art.modulate = card.color
	
	# 加载Fragment
	if load_fragments and frag_tree:
		_load_fragments()

# 变形为其他卡牌
func transform_card(target_card: Card) -> void:
	var old_card = card
	load_card(target_card)
	
	# 触发衰变规则
	if target_card.on_decay_into:
		var context = Context.new()
		# 设置适当的上下文
		target_card.on_decay_into.execute(context)
	
	# 开始衰变过程
	if target_card.lifetime > 0.0:
		decay_card(target_card, target_card.lifetime)

# 复制卡牌
func duplicate_card() -> CardViz:
	# 需要从GameManager或ObjectPool获取新的CardViz实例
	if GameManager.instance:
		var new_card_viz = GameManager.instance.create_card_viz(card)
		if new_card_viz:
			new_card_viz.load_card(card)
			new_card_viz.global_position = global_position
		return new_card_viz
	return null

# 移动卡牌到窗口
func parent_to_window(target_transform: Control, should_hide: bool = false) -> void:
	if should_hide:
		hide_card()
	
	reparent(target_transform)

# 抓取卡牌到目标位置
func grab_card(target: Vector2, on_start: Callable = Callable(), on_complete: Callable = Callable()) -> bool:
	if visible and free:
		var card_to_grab = yield_card()
		
		if card_to_grab.free:
			card_to_grab.interactive = false
			
			if on_start.is_valid():
				on_start.call(card_to_grab)
			
			card_to_grab.do_move(target, GameConfig.NORMAL_SPEED, Callable(), func(_tween):
				card_to_grab.interactive = true
				if on_complete.is_valid():
					on_complete.call(card_to_grab)
			)
			return true
	
	return false

# 检查是否可以堆叠
func can_stack(other_card: CardViz) -> bool:
	return (card == other_card.card and
			not face_down and
			not other_card.face_down and
			(not card_decay or not card_decay.enabled) and
			(not other_card.card_decay or not other_card.card_decay.enabled))

# 堆叠卡牌
func stack_card(other_card: CardViz) -> void:
	card_stack.push(other_card)

# 衰变完成回调
func on_decay_complete(target_card: Card) -> void:
	if target_card != null:
		transform_card(target_card)
	else:
		destroy_card()

# 私有方法
func _update_face_display() -> void:
	if art and art_back:
		art.visible = not _face_down
		art_back.visible = _face_down

func _load_fragments() -> void:
	if frag_tree and card:
		frag_tree.clear()
		
		# 加载卡牌的所有Fragment
		for fragment in card.fragments:
			frag_tree.add_fragment(fragment)
		
		# 设置记忆Fragment
		if not frag_tree.memory_fragment and card.memory_fragment:
			frag_tree.memory_fragment = card.memory_fragment

func _highlight_valid_slots() -> void:
	if GameManager.instance:
		for token_viz in GameManager.instance.tokens:
			var slot_viz = _get_component_in_children(token_viz, SlotViz)
			if slot_viz and (not slot_viz.slotted_card or not slot_viz.card_lock):
				slot_viz.set_highlight(true)

func _handle_double_click() -> void:
	# 处理双击逻辑：自动放置到合适的插槽
	var ready_slot: SlotViz = null
	
	# 首先检查当前打开的窗口
	if GameManager.instance and GameManager.instance.open_window:
		ready_slot = GameManager.instance.open_window.accepts_card(self, true)
	
	# 然后检查所有token的插槽
	if not ready_slot and GameManager.instance:
		for token_viz in GameManager.instance.tokens:
			var slot_viz = _get_component_in_children(token_viz, SlotViz)
			if slot_viz and slot_viz.can_accept_card(self):
				ready_slot = slot_viz
				break
	
	if ready_slot:
		var card_to_place = yield_card()
		
		# 从当前位置取出
		var current_dock = _get_component_in_parent(card_to_place.get_parent(), ICardDock)
		if current_dock:
			current_dock.on_card_undock(card_to_place)
		
		ready_slot.grab_card(card_to_place, true)

func _get_array_table() -> ArrayTable:
	return _get_component_in_parent(self, ArrayTable)

func _get_component_in_parent(node: Node, component_class) -> Node:
	var current = node
	while current != null:
		if current.get_script() and current.get_script().get_global_name() == component_class.get_global_name():
			return current
		current = current.get_parent()
	return null

func _get_component_in_children(node: Node, component_class) -> Node:
	if node.get_script() and node.get_script().get_global_name() == component_class.get_global_name():
		return node
	
	for child in node.get_children():
		var result = _get_component_in_children(child, component_class)
		if result:
			return result
	
	return null

func _ready() -> void:
	super._ready()
	
	if card != null:
		load_card(card)
	
	# 连接鼠标事件
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# 如果有衰变设置且时间为0但卡牌有生命周期，则开始衰变
	if card_decay and card_decay.time_left == 0.0 and card and card.lifetime > 0.0:
		decay_card(card.decay_to if card.decay_to else null, card.lifetime)
