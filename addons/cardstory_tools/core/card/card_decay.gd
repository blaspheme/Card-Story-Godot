# CardDecay - 卡牌衰变组件
class_name CardDecay
extends Node2D

# UI 组件引用
@export var time_label: Label
@export var art_renderer: Sprite2D

# 配置选项
@export var pause_on_hide: bool = false			# 隐藏时暂停
@export var pause_on_slot: bool = false			# 在槽位时暂停

# 衰变目标
var decay_to: Card

# 状态变量
var is_paused: bool = false
var decay_time: float = 0.0
var elapsed_time: float = 0.0
var original_color: Color

# 渲染器引用
var timer_renderer: CanvasItem

# 剩余时间属性
var time_left: float:
	get:
		return decay_time - elapsed_time

func _ready():
	# 初始化
	if art_renderer:
		original_color = art_renderer.modulate
	
	timer_renderer = time_label if time_label else null
	
	if timer_renderer:
		timer_renderer.visible = false
	
	# 默认禁用更新
	set_process(false)

func _process(delta):
	if is_paused:
		return
	
	# 更新时间（考虑游戏时间缩放）
	var time_scale = 1.0
	if GameManager.instance:
		time_scale = GameManager.instance.time_scale
	
	elapsed_time += delta * time_scale
	
	# 更新显示
	_update_display(time_left)
	
	# 检查是否完成衰变
	if time_left <= 0.0:
		_complete_decay()

# 开始衰变计时
func start_timer(time: float, target: Card):
	elapsed_time = 0.0
	decay_time = time
	decay_to = target
	
	# 隐藏计时器渲染器
	if timer_renderer:
		timer_renderer.visible = false
	
	# 启用更新
	set_process(true)
	
	# 保存原始颜色
	if art_renderer:
		original_color = art_renderer.modulate
	
	# 更新显示
	_update_display(time)

# 停止计时
func stop_timer():
	decay_time = 0.0
	elapsed_time = 0.0
	set_process(false)
	is_paused = false
	
	# 恢复原始外观
	if art_renderer:
		art_renderer.modulate = original_color
	
	hide_timer()

# 显示计时器
func show_timer():
	if art_renderer:
		art_renderer.modulate = Color.GRAY
	
	if timer_renderer:
		timer_renderer.visible = true

# 隐藏计时器
func hide_timer():
	if art_renderer:
		art_renderer.modulate = original_color
	
	if timer_renderer:
		timer_renderer.visible = false

# 暂停计时
func pause():
	if is_processing():
		is_paused = true
		set_process(false)

# 恢复计时
func unpause():
	if is_paused:
		is_paused = false
		set_process(true)

# 更新显示
func _update_display(time: float):
	# 当时间少于一半时显示计时器
	if timer_renderer and not timer_renderer.visible and (2.0 * time_left) < decay_time:
		show_timer()
	
	# 更新文本
	if time_label:
		time_label.text = "%.1f" % time

# 完成衰变
func _complete_decay():
	stop_timer()
	
	# 通知父卡牌衰变完成
	var card_viz = get_parent() as CardViz
	if card_viz and card_viz.has_method("on_decay_complete"):
		card_viz.on_decay_complete(decay_to)

# 保存衰变状态
func save() -> Dictionary:
	return {
		"duration": decay_time,
		"elapsed_time": elapsed_time,
		"decay_to": decay_to.resource_path if decay_to else "",
		"paused": is_paused,
		"pause_on_hide": pause_on_hide,
		"pause_on_slot": pause_on_slot
	}

# 加载衰变状态
func load_from_dict(save_data: Dictionary):
	if save_data.has("duration"):
		decay_time = save_data.duration
	
	if save_data.has("elapsed_time"):
		elapsed_time = save_data.elapsed_time
	
	if save_data.has("decay_to") and save_data.decay_to != "":
		decay_to = load(save_data.decay_to) as Card
	
	if save_data.has("pause_on_hide"):
		pause_on_hide = save_data.pause_on_hide
	
	if save_data.has("pause_on_slot"):
		pause_on_slot = save_data.pause_on_slot
	
	# 如果有持续时间，启用处理
	if decay_time > 0.0:
		set_process(true)
	
	# 如果保存时是暂停状态，恢复暂停
	if save_data.has("paused") and save_data.paused:
		pause()

# 重置衰变
func reset():
	stop_timer()
	decay_to = null

# 设置衰变时间（不重置已过去时间）
func set_decay_time(time: float):
	decay_time = time
	_update_display(time_left)

# 添加衰变时间
func add_decay_time(time: float):
	decay_time += time
	_update_display(time_left)

# 减少衰变时间
func reduce_decay_time(time: float):
	decay_time = max(0.0, decay_time - time)
	_update_display(time_left)
	
	# 如果时间为0，立即完成衰变
	if decay_time <= elapsed_time:
		_complete_decay()

# 检查是否正在衰变
func is_decaying() -> bool:
	return is_processing() and not is_paused and decay_time > 0.0

# 获取衰变进度（0-1）
func get_decay_progress() -> float:
	if decay_time <= 0.0:
		return 0.0
	return elapsed_time / decay_time

# 获取剩余时间百分比
func get_remaining_percentage() -> float:
	if decay_time <= 0.0:
		return 0.0
	return time_left / decay_time

# 处理可见性变化
func _on_visibility_changed():
	if pause_on_hide:
		var card_viz = get_parent() as CardViz
		if card_viz:
			if card_viz.visible:
				unpause()
			else:
				pause()

# 连接信号
func _connect_signals():
	var card_viz = get_parent() as CardViz
	if card_viz:
		if not card_viz.visibility_changed.is_connected(_on_visibility_changed):
			card_viz.visibility_changed.connect(_on_visibility_changed)

# 获取衰变信息（调试用）
func get_decay_info() -> String:
	if not is_decaying():
		return "CardDecay: 未激活"
	
	return "CardDecay: %.1f/%.1f 秒 -> %s" % [
		time_left, 
		decay_time,
		decay_to.get_display_name() if decay_to else "未知"
	]

# 打印衰变状态（调试用）
func print_decay_status():
	print("=== 卡牌衰变状态 ===")
	print(get_decay_info())
	print("暂停状态: ", is_paused)
	print("进度: %.1f%%" % (get_decay_progress() * 100))
	print("===================")