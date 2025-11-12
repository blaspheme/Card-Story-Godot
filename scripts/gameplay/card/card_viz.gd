extends DragCardViz
class_name CardViz

## 卡牌可视化组件
## 继承自 DragCardViz，实现具体的卡牌显示和交互逻辑

# 导出变量
## 卡牌的数据资源
@export var card_data: CardData

# ===============================
# SceneTree引用
# ===============================
@onready var area: Area2D = $Area2D
@onready var frag_tree: FragTree = $Root
@onready var visuals: Node2D = $Visuals
@onready var title_label: Label = $Visuals/Front/VBoxContainer/Title
@onready var front_image: TextureRect = $Visuals/Front/VBoxContainer/Image
@onready var back_image: TextureRect = $Visuals/Back
@onready var background: Sprite2D = $Visuals/Background
@onready var mat: ShaderMaterial = $Visuals/Background.material
@onready var highlight_sprite: Sprite2D = $Visuals/Highlight if has_node("$Visuals/Highlight") else null
@onready var stack_counter: CardStack = $StackCounter
@onready var decay_timer: CardDency = $DaceyTimer

# 堆叠引用（用于CardStack中的卡牌）
var stack: CardViz = null

# 状态属性
var _face_down: bool = false
var interactive: bool = true  # 是否可交互（拖拽、点击等）

# ===============================
# 属性访问器
# ===============================

## 卡牌是否自由（可拖动）
var free: bool:
	get: return frag_tree.free if frag_tree else false
	set(value): 
		if frag_tree:
			frag_tree.free = value

## 卡牌是否背面朝上
var face_down: bool:
	get: return _face_down
	
## 堆叠数量
var stack_count: int:
	get: return stack_counter.get_count() if stack_counter else 0

## 衰败组件引用
var decay: CardDency:
	get: return decay_timer

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:
	# 初始化拖拽系统（父类方法）
	_init_drag_system()
	
	# 连接衰败完成信号
	if decay_timer:
		decay_timer.decay_completed.connect(_on_decay_completed)
	
	# 如果有卡片数据，进行初始化
	setup_card()

## 设置卡片数据和外观
func setup_card() -> void:
	if not card_data:
		return
	
	load_card(card_data)
	
	# 组件赋值
	stack_counter._parent_card = self
	stack_counter.update_ui()
	
	# 检查是否需要开始衰败
	_check_and_start_decay()

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

## 检查是否允许拖拽（重写以添加堆叠拖拽检查）
func _can_start_drag() -> bool:
	# 始终允许拖拽，具体的弹出逻辑在_on_drag_started中处理
	return true

#endregion
# ===============================
# 堆叠交互方法
# ===============================

## 弹出一张卡
func yield_card() -> CardViz:
	if stack_counter.get_count() > 0:
		return stack_counter.pop()
	else:
		return self

## 接受其他卡片的放置
func accept_dropped_card(dropped_card: CardViz) -> bool:
	if not can_stack_with(dropped_card):
		return false
	
	# 检查被拖拽的卡是否有自己的堆叠
	if dropped_card.stack_counter.get_count() > 0:
		# 合并两个堆叠
		return stack_counter.merge(dropped_card.stack_counter)
	else:
		# 将单张卡加入当前堆叠
		return stack_counter.push(dropped_card)

## 检查是否可以与另一张卡堆叠
func can_stack_with(other_card: CardViz) -> bool:
	if other_card == null or other_card == self:
		return false
	
	# 检查卡牌类型是否相同（你可以根据项目需求修改这个条件）
	return card_data == other_card.card_data

# ===============================
# 重写父类钩子方法
# ===============================

## 拖拽开始时的处理
func _on_drag_started() -> void:
	print("拖拽开始 - stack_drag: %s, count: %d" % [stack_counter.stack_drag, stack_counter.get_count()])
	
	# 如果不是整堆拖拽模式且堆中有卡片，弹出一张卡进行拖拽
	if not stack_counter.stack_drag and stack_counter.get_count() > 0:
		print("弹出卡片进行拖拽")
		var popped_card := stack_counter.pop()
		if popped_card != null:
			# 停止当前卡的拖拽
			is_dragging = false
			z_index = original_z_index
			_area.input_pickable = true
			set_process_input(false)
			
			# 让弹出的卡开始拖拽
			popped_card.start_drag_directly()
			var popped_label = popped_card.card_data.label.get_text() if (popped_card.card_data and popped_card.card_data.label) else "未命名"
			print("弹出的卡片开始拖拽: %s" % popped_label)
			return
	
	# 否则继续当前卡或整堆的拖拽
	if stack_counter.stack_drag:
		var label_text = card_data.label.get_text() if card_data and card_data.label else "未命名"
		print("开始整堆拖拽: ", label_text)
	else:
		var label_text = card_data.label.get_text() if card_data and card_data.label else "未命名"
		print("开始单卡拖拽: ", label_text)

## 拖拽结束时检测放置目标
func _on_drag_ended() -> void:
	var label_text = card_data.label.get_text() if card_data and card_data.label else "未命名"
	print("结束拖拽卡片: ", label_text)
	
	# 检测是否放置在其他卡片上
	_check_drop_targets()

## 检测放置目标
func _check_drop_targets() -> void:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var results := space_state.intersect_point(query)
	
	# 找到最上层的目标卡片
	var target_card: CardViz = null
	var highest_z_index := -999999
	
	for result in results:
		var collider: Area2D = result["collider"] as Area2D
		if collider and collider != area:  # 不是自己的Area2D
			# 检查是否是其他卡片
			var potential_target := collider.get_parent() as CardViz
			if potential_target and potential_target != self and potential_target.z_index > highest_z_index:
				highest_z_index = potential_target.z_index
				target_card = potential_target
	
	# 尝试堆叠到卡片
	if target_card:
		if target_card.accept_dropped_card(self):
			var target_label = target_card.card_data.label.get_text() if target_card.card_data and target_card.card_data.label else "未命名"
			print("成功堆叠到卡片: ", target_label)
		else:
			print("无法堆叠到目标卡片")
	# 如果没有找到目标卡片，卡片保持在当前拖拽结束的位置（自由放置）

# ===============================
# 信号回调（连接到场景中的信号）
# ===============================

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

# ===============================
# 衰败系统
# ===============================

## 检查并开始衰败（在卡片创建时调用）
func _check_and_start_decay() -> void:
	if not card_data:
		# 隐藏衰败计时器
		if decay_timer:
			decay_timer.hide_timer()
		return
	
	# 如果没有衰败目标或时间为0，隐藏计时器
	if not card_data.decay_to or card_data.lifetime <= 0.0:
		if decay_timer:
			decay_timer.hide_timer()
		return
	
	# 开始衰败计时
	start_decay(card_data.lifetime, card_data.decay_to)
	print("开始衰败计时: %s -> %s (%s秒)" % [card_data.label, card_data.decay_to.label, card_data.lifetime])

## 开始衰败计时
func start_decay(duration: float, decay_to_card: CardData) -> void:
	if decay_timer:
		decay_timer.start_timer(duration, decay_to_card)
		EventBus.emit("card_decay_started", [self, duration, decay_to_card])

## 停止衰败
func stop_decay() -> void:
	if decay_timer:
		decay_timer.stop_timer()
		EventBus.emit("card_decay_stopped", [self])

## 暂停衰败
func pause_decay() -> void:
	if decay_timer:
		decay_timer.pause()
		EventBus.emit("card_decay_paused", [self])

## 恢复衰败
func resume_decay() -> void:
	if decay_timer:
		decay_timer.unpause()
		EventBus.emit("card_decay_resumed", [self])

## 获取剩余衰败时间
func get_decay_time_left() -> float:
	if decay_timer:
		return decay_timer.time_left()
	return 0.0

## 显示/隐藏衰败计时器
func show_decay_timer() -> void:
	if decay_timer:
		decay_timer.show_timer()

func hide_decay_timer() -> void:
	if decay_timer:
		decay_timer.hide_timer()

## 衰败完成回调
func _on_decay_completed(decay_to_card: CardData) -> void:
	var from_label = card_data.label.get_text() if card_data and card_data.label else "未知"
	var to_label = decay_to_card.label.get_text() if decay_to_card and decay_to_card.label else "未知"
	print("卡片衰败完成: %s -> %s" % [from_label, to_label])
	
	# 如果这张卡在别的卡的堆叠中，先从堆叠中弹出
	if stack != null and stack.stack_counter:
		print("从堆叠中弹出衰变卡牌")
		if stack.stack_counter.handle_stacked_card_decay(self):
			# 成功弹出后进行转换
			_transform_self(decay_to_card)
		return
	
	# 转换当前卡片（只转换触发衰变的这张卡）
	_transform_self(decay_to_card)

# ===============================
# 公开接口
# ===============================

## 设置新的卡片数据（会重新初始化衰败）
func set_card_data(new_card_data: CardData) -> void:
	# 停止当前的衰败计时器
	stop_decay()
	
	# 设置新数据
	card_data = new_card_data
	
	# 重新设置卡片
	setup_card()



## 转换当前卡片自身
func _transform_self(new_card_data: CardData) -> void:
	print("转换当前卡片: %s -> %s" % [card_data.label, new_card_data.label])
	
	# 执行衰败完成规则（如果存在）
	if card_data.on_decay_complete:
		print("执行衰败完成规则: %s" % card_data.on_decay_complete.resource_path)
		# TODO: 在这里调用规则系统执行规则
		# RuleSystem.execute_rule(card_data.on_decay_complete, self)
	
	# 转换当前卡片数据
	set_card_data(new_card_data)
	
	# 如果有堆叠，弹出所有与新类型不匹配的卡牌
	if stack_counter.get_count() > 0:
		var ejected_cards = stack_counter.eject_mismatched_cards()
		if ejected_cards.size() > 0:
			print("弹出了 %d 张不匹配的卡牌" % ejected_cards.size())
	
	# 执行衰败进入规则（如果新卡片有此规则）
	if new_card_data.on_decay_into:
		print("执行衰败进入规则: %s" % new_card_data.on_decay_into.resource_path)
		# TODO: 在这里调用规则系统执行规则
		# RuleSystem.execute_rule(new_card_data.on_decay_into, self)
	
	# 播放转换特效
	_play_transform_effect()

## 播放转换特效
func _play_transform_effect() -> void:
	print("在位置 %s 播放转换特效" % global_position)
	# TODO: 添加粒子特效、闪光等
	# var effect = preload("res://scenes/effects/transform_effect.tscn").instantiate()
	# effect.global_position = global_position
	# get_tree().current_scene.add_child(effect)

# ===============================
# 显示/隐藏和翻转功能（Unity 迁移）
# ===============================

## 隐藏卡牌（设置 visuals 不可见）
func hide_card() -> void:
	if visuals:
		visuals.hide()

## 显示卡牌
func show_card() -> void:
	if visuals:
		visuals.show()

## 翻转卡牌（正反面切换）
func reverse(instant: bool = false) -> void:
	if instant:
		# 立即翻转180度
		rotation_degrees += 180.0
	else:
		# 动画翻转
		interactive = false
		var tween = create_tween()
		tween.tween_property(self, "rotation_degrees", rotation_degrees + 180.0, 0.3)  # 翻转速度
		# Punch 效果（Y轴位移）
		var start_y = position.y
		tween.parallel().tween_property(self, "position:y", start_y - 20.0, 0.15).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(self, "position:y", start_y, 0.15).set_trans(Tween.TRANS_QUAD)
		tween.finished.connect(func(): interactive = true)
	
	_face_down = !_face_down
	if frag_tree:
		frag_tree.on_change()

## 显示正面
func show_face() -> void:
	rotation_degrees = 0.0
	_face_down = false
	if frag_tree:
		frag_tree.on_change()

## 显示背面
func show_back() -> void:
	rotation_degrees = 180.0
	_face_down = true
	if frag_tree:
		frag_tree.on_change()

## 设置高亮状态
func set_highlight(enabled: bool) -> void:
	if highlight_sprite:
		highlight_sprite.visible = enabled

## 取消所有目标高亮（Tokens 和 Slots）
func unhighlight_targets() -> void:
	# 取消所有 token 的高亮
	for token in Manager.GM.tokens:
		if token.has_method("set_highlight"):
			token.set_highlight(false)
	
	# 取消打开窗口的 slot 高亮
	if Manager.GM.open_window and Manager.GM.open_window.has_method("unhighlight_slots"):
		Manager.GM.open_window.unhighlight_slots()

# ===============================
# 加载和转换功能（Unity 迁移）
# ===============================
#region 保存和加载数据逻辑

## 加载卡片数据（对应 Unity LoadCard）
func load_card(card: CardData, load_fragments: bool = true) -> void:
	if card == null:
		return
	
	card_data = card
	# 设置标题和图片
	title_label.text = card.label.get_text() if card.label else ""
	front_image.texture = card.image
	
	# 加载碎片
	if load_fragments:
		_load_fragments()
	
	# 设置节点名称
	name = "[CARD] " + card.resource_path.get_file().get_basename()

## 加载卡片的碎片数据
func _load_fragments() -> void:
	if not card_data or not frag_tree:
		return
	
	# 添加卡片定义的碎片
	for frag in card_data.fragments:
		if frag != null:
			frag_tree.add_fragment(frag)
	
	# 设置记忆碎片
	if frag_tree.memory_fragment == null:
		if card_data.memory_from_first and frag_tree.local_fragments.size() > 0:
			frag_tree.memory_fragment = frag_tree.local_fragments[0].fragment
		else:
			frag_tree.memory_fragment = card_data

#endregion

## 转换卡片（对应 Unity Transform）
func transform_card(new_card: CardData) -> void:
	if new_card == null:
		return
	
	# 检查是否是 mutator 类型
	if new_card.has("is_mutator") and new_card.is_mutator:
		# Mutator 模式：在标题后添加修饰符
		var index = title_label.text.find("\n[")
		if index != -1:
			title_label.text = title_label.text.substr(0, index)
		
		var mutator_label = new_card.label.get_text() if new_card.label else ""
		if mutator_label.length() > 4:
			title_label.text += "\n[" + mutator_label.substr(2, mutator_label.length() - 4) + "]"
		
		# 停止当前衰败
		stop_decay()
		
		# 开始新的衰败（使用当前卡的数据）
		if new_card.lifetime > 0.0:
			start_decay(new_card.lifetime, card_data)
	else:
		# 普通转换：完全替换卡片
		load_card(new_card, false)
		
		# 重新开始衰败
		stop_decay()
		if new_card.lifetime > 0.0 and new_card.decay_to:
			start_decay(new_card.lifetime, new_card.decay_to)
	
	if frag_tree:
		frag_tree.on_change()

## 复制卡片（对应 Unity Duplicate）
func duplicate_card() -> CardViz:
	if not card_data:
		return null
	
	# 创建新卡片实例
	var new_card_viz = Manager.GM.create_card(card_data)
	
	if new_card_viz != null:
		# 清除并复制碎片
		new_card_viz.frag_tree.clear()
		
		for frag in frag_tree.local_fragments:
			new_card_viz.frag_tree.add_held_fragment(frag)
		
		# 复制记忆碎片
		new_card_viz.frag_tree.memory_fragment = frag_tree.memory_fragment
	
	return new_card_viz

## 设置父节点（对应 Unity ParentTo）
func parent_to(trans: Node, should_hide: bool = false) -> void:
	if should_hide:
		hide_card()
	
	interactive = false
	free = false
	
	# 重新设置父节点
	if get_parent():
		get_parent().remove_child(self)
	trans.add_child(self)
	
	# TODO: 重置本地位置
	# position = Vector2.ZERO

## 抓取卡片并移动到目标位置（对应 Unity Grab）
func grab(target_pos: Vector3, on_start: Callable = Callable(), on_complete: Callable = Callable()) -> bool:
	if not visible or not free:
		return false
	
	var card_viz_y = yield_card()
	
	if not card_viz_y.free:
		return false
	
	# 停止所有动画
	var tween = get_tree().create_tween()
	if tween:
		tween.kill()
	
	# 中断拖拽
	if card_viz_y.has_method("interrupt_drag"):
		card_viz_y.interrupt_drag()
	
	# 通知父节点卡片被取走
	var parent_dock = card_viz_y.get_parent()
	if parent_dock and parent_dock.has_method("on_card_undock"):
		parent_dock.on_card_undock(card_viz_y)
	
	# 激活卡片
	card_viz_y.show()
	card_viz_y.global_position = card_viz_y._get_position()
	
	# 移出父节点
	if card_viz_y.get_parent():
		card_viz_y.get_parent().remove_child(card_viz_y)
		get_tree().root.add_child(card_viz_y)
	
	# 开始回调
	if on_start.is_valid():
		on_start.call(card_viz_y)
	
	# 移动动画（使用固定速度0.5秒）
	var move_tween = create_tween()
	move_tween.tween_property(card_viz_y, "global_position", target_pos, 0.5)
	move_tween.finished.connect(func():
		if on_complete.is_valid():
			on_complete.call(card_viz_y)
	)
	
	return true

## 获取卡片位置（考虑 ActWindow 的情况）
func _get_position(force_token: bool = false) -> Vector2:
	# 查找父级 ActWindow
	var current = get_parent()
	while current:
		if current.has_method("get_class") and current.get_class() == "ActWindow":
			var act_window = current
			if force_token or (act_window.has("open") and not act_window.open):
				if act_window.has("token_viz") and act_window.token_viz:
					return act_window.token_viz.global_position
			break
		current = current.get_parent()
	return global_position

## 获取指定类型的父节点
func get_parent_of_type(type) -> Node:
	var current = get_parent()
	while current:
		if is_instance_of(current, type):
			return current
		current = current.get_parent()
	return null

# ===============================
# 点击交互（Unity 迁移）
# ===============================

## 处理卡片点击（对应 Unity OnPointerClick）
func _on_card_clicked(event: InputEventMouseButton) -> void:
	if not interactive:
		return
	
	# 单击：翻转或显示信息
	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _face_down:
			reverse()
		else:
			# 显示卡片信息UI（TODO: 需要实现 UIManager）
			# if UIManager and UIManager.has_method("show_card_info"):
			# 	UIManager.show_card_info(self)
			pass
		
		# 双击：自动放置到 Slot
		if event.double_click:
			_handle_double_click()

## 处理双击逻辑
func _handle_double_click() -> void:
	# 从 Slot 中取出卡片（TODO: 需要实现 SlotViz）
	# var slot = get_parent_of_type(SlotViz)
	# if slot and slot.has("card_lock") and not slot.card_lock:
	# 	if slot.has_method("unslot_card"):
	# 		slot.unslot_card()
	# 	if GameManager.table and GameManager.table.has_method("return_to_table"):
	# 		GameManager.table.return_to_table(self)
	# 	return
	
	# 尝试自动放置到可用的 Slot
	var ready_slot = null
	
	# 先检查打开的窗口
	if Manager.GM.has("open_window") and Manager.GM.open_window:
		if Manager.GM.open_window.has_method("accepts_card"):
			ready_slot = Manager.GM.open_window.accepts_card(self, true)
	
	# 再检查所有 token 窗口
	if not ready_slot and Manager.GM.has("tokens"):
		for token in Manager.GM.tokens:
			if token.has("act_window") and token.act_window:
				if token.act_window.has_method("accepts_card"):
					ready_slot = token.act_window.accepts_card(self, true)
					if ready_slot:
						break
	
	# 如果找到可用 slot，放置卡片
	if ready_slot:
		var card_viz_y = yield_card()
		
		# 通知父节点
		var parent_dock = card_viz_y.get_parent()
		if parent_dock and parent_dock.has_method("on_card_undock"):
			parent_dock.on_card_undock(card_viz_y)
		
		# 抓取到 slot（TODO: SlotViz.grab 方法签名可能不同）
		if ready_slot.has_method("grab_card"):
			ready_slot.grab_card(card_viz_y, true)


## 检查记忆是否相等（对应 Unity MemoryEqual）
func memory_equal(other_card: CardViz) -> bool:
	if other_card == null:
		return false
	return other_card.card_data == card_data and \
		   other_card.frag_tree.memory_fragment == frag_tree.memory_fragment

# ===============================
# 内部辅助方法
# ===============================
#region 保存&加载
## 保存卡片状态
func save_state() -> CardVizState:
	var _save = CardVizState.new()
	_save.save(self)
	return _save
	

## 加载卡片状态
func load_state(save_data: Dictionary) -> void:
	# 加载卡片数据
	if save_data.has("card") and save_data.card != "":
		var card = load(save_data.card) as CardData
		load_card(card, false)
	
	# 加载碎片树
	if save_data.has("frag_save") and frag_tree:
		frag_tree.load_state(save_data.frag_save)
	
	# 加载状态
	free = save_data.get("free", false)
	if save_data.get("face_down", false):
		show_back()
	
	global_position = save_data.get("position", Vector2.ZERO)
	
	# 加载衰败状态
	if save_data.has("decay_save") and decay_timer:
		var decay_save = save_data.decay_save
		if decay_save.has("decay_to") and decay_save.decay_to != "":
			var decay_to = load(decay_save.decay_to) as CardData
			decay_timer.start_timer(decay_save.get("time_left", 0.0), decay_to)
	
	# 注意：堆叠卡片和子卡片需要在所有卡片实例化后统一处理
	# 这部分逻辑应该由 SaveManager 负责
#endregion

func destroy() -> void:
	Manager.GM.destroy_card(self)
