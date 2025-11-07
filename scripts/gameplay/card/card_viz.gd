extends DragCardViz
class_name CardViz

## 卡牌可视化组件
## 继承自 DragCardViz，实现具体的卡牌显示和交互逻辑

# 导出变量
## 卡牌的数据资源
@export var card_data: CardData
## Table上卡牌尺寸
@export var cell_count: Vector2i = Vector2i.ONE

# ===============================
# SceneTree引用
# ===============================
@onready var area: Area2D = $Area2D
@onready var frag_tree: FragTree = $Root
@onready var title_label: Label = $Front/VBoxContainer/Title
@onready var front_image: TextureRect = $Front/VBoxContainer/Image
@onready var back_image: TextureRect = $Back
@onready var background: Sprite2D = $Background
@onready var mat: ShaderMaterial = $Background.material
@onready var stack_counter: CardStack = $StackCounter
@onready var decay_timer: CardDency = $DaceyTimer

# 堆叠引用（用于CardStack中的卡牌）
var stack: CardViz = null

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
	if card_data:
		setup_card()

## 设置卡片数据和外观
func setup_card() -> void:
	if not card_data:
		return
	
	# 卡牌特有的初始化
	title_label.text = card_data.label
	front_image.texture = card_data.image
	back_image.texture = card_data.image
	
	# 组件赋值
	stack_counter._parent_card = self
	stack_counter.update_ui()
	
	# 检查是否需要开始衰败
	_check_and_start_decay()

# ===============================
# 实现父类抽象方法
# ===============================

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

## 检查是否可以与另一张卡堆叠
func can_stack_with(other_card: CardViz) -> bool:
	if other_card == null or other_card == self:
		return false
	
	# 检查卡牌类型是否相同（你可以根据项目需求修改这个条件）
	return card_data == other_card.card_data

# ===============================
# 堆叠交互方法
# ===============================

## 弹出一张卡（类似Unity的Yield）
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
			print("弹出的卡片开始拖拽: %s" % (popped_card.card_data.label if popped_card.card_data else "未命名"))
			return
	
	# 否则继续当前卡或整堆的拖拽
	if stack_counter.stack_drag:
		print("开始整堆拖拽: ", card_data.label if card_data else "未命名")
	else:
		print("开始单卡拖拽: ", card_data.label if card_data else "未命名")

## 拖拽结束时检测放置目标
func _on_drag_ended() -> void:
	print("结束拖拽卡片: ", card_data.label if card_data else "未命名")
	
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
			var potential_target := collider.get_parent() as CardViz
			if potential_target and potential_target != self and potential_target.z_index > highest_z_index:
				highest_z_index = potential_target.z_index
				target_card = potential_target
	
	# 尝试放置到目标卡片上
	if target_card:
		if target_card.accept_dropped_card(self):
			print("成功堆叠到卡片: ", target_card.card_data.label if target_card.card_data else "未命名")
		else:
			print("无法堆叠到目标卡片")

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
	print("卡片衰败完成: %s -> %s" % [card_data.label if card_data else "未知", decay_to_card.label if decay_to_card else "未知"])
	
	# 通过EventBus通知游戏管理器进行卡片转换
	EventBus.emit("card_decay_completed", [self, decay_to_card])

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
