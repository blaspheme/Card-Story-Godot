extends Label
class_name CardDency

# Godot 实现的卡牌衰变计时器
#
# 功能：
# - start_timer(duration: float, decay_to: CardData)
# - stop_timer()
# - pause()/unpause()
# - show_timer()/hide_timer()
# - time_left(): float
#
# 实现要点：使用一个低频的 Timer (默认 0.1s) 来更新显示和检查完成，避免每帧开销。

signal decay_completed(decay_to)

@export var tick_interval: float = 0.1

var decay_to: Resource = null
var paused: bool = false
var duration: float = 0.0
var elapsed: float = 0.0

var _tick_timer: Timer
var _original_visible: bool = false

func _ready() -> void:
	# 创建并配置内部计时器
	_tick_timer = Timer.new()
	_tick_timer.wait_time = tick_interval
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.connect("timeout", Callable(self, "_on_tick"))

	# 记录初始可见性（用于 stop 时恢复）
	_original_visible = visible
	
	# 默认隐藏计时器，只有在开始衰败时才显示
	hide_timer()

func start_timer(time: float, to: Resource) -> void:
	# 开始一个新的衰变计时器
	if time <= 0.0:
		hide_timer()
		return

	duration = time
	elapsed = 0.0
	decay_to = to
	paused = false

	# 显示计时器
	show_timer()

	# 启动 tick 计时器
	if not _tick_timer.is_stopped():
		_tick_timer.stop()
	_tick_timer.start()

	_update_display()

func stop_timer() -> void:
	# 停止计时器并重置状态
	if _tick_timer:
		_tick_timer.stop()

	duration = 0.0
	elapsed = 0.0
	decay_to = null
	paused = false

	# 隐藏计时器
	hide_timer()

func pause() -> void:
	if duration <= 0.0:
		return
	paused = true
	if _tick_timer:
		_tick_timer.stop()

func unpause() -> void:
	if duration <= 0.0:
		return
	paused = false
	if _tick_timer:
		_tick_timer.start()

func show_timer() -> void:
	visible = true
	# 尝试将父卡背景置灰（如果存在 Background Sprite2D）
	var bg = null
	var p = get_parent()
	if p != null:
		bg = p.get_node_or_null("Background")
	if bg and bg is Sprite2D:
		bg.modulate = Color(0.7, 0.7, 0.7, 1)

func hide_timer() -> void:
	visible = false
	var bg = null
	var p = get_parent()
	if p != null:
		bg = p.get_node_or_null("Background")
	if bg and bg is Sprite2D:
		bg.modulate = Color(1, 1, 1, 1)

func time_left() -> float:
	return max(0.0, duration - elapsed)

func _on_tick() -> void:
	if paused or duration <= 0.0:
		return

	# 增量更新时间（使用计时器的 wait_time，并应用时间缩放）
	elapsed += _tick_timer.wait_time * GameManager.time_scale

	# 更新显示并根据剩余时间决定是否显示计时器
	_update_display()

	if elapsed >= duration:
		# 完成：停止计时器并发出信号/回调
		_tick_timer.stop()
		var target = decay_to
		stop_timer()
		# 通知父节点（如果实现了 on_decay_complete / OnDecayComplete），并发出信号
		if target != null:
			# 尝试多种命名风格的回调以兼容不同实现
			var parent = get_parent()
			if parent != null:
				if parent.has_method("on_decay_complete"):
					parent.call_deferred("on_decay_complete", target)
				elif parent.has_method("OnDecayComplete"):
					parent.call_deferred("OnDecayComplete", target)
			# 发送信号，外部也可以连接
			emit_signal("decay_completed", target)

func _update_display() -> void:
	# 在文本中显示剩余时间，保留一位小数
	var remaining = time_left()
	text = String("%.1f" % remaining)
	
	# 如果时间用完了，隐藏显示（转换会在_on_tick中处理）
	if remaining <= 0.0:
		text = "0.0"
