extends Node2D
class_name TokenTimer

## 游戏计时器组件（对应Unity的Timer类）
## 提供计时显示、进度条、事件回调和存档功能

# ===============================
# 信号定义
# ===============================
## 计时器时间到达时发出
signal time_up

# ===============================
# 导出属性
# ===============================
## Tick更新间隔（秒）
@export var tick_interval: float = 0.01

# ===============================
# 私有属性
# ===============================
var _duration: float = 0.0
var _elapsed_time: float = 0.0
var _following_timer: TokenTimer = null
var _enabled: bool = false

# 节点引用（在_ready中初始化）
@onready var _text_label: Label = $Label
@onready var _circular_progress: ColorRect = $CircularProgress
@onready var _circular_material: ShaderMaterial = $CircularProgress.material
var _tick_timer: Timer

# 回调函数列表（替代Unity的UnityEvent）
var _time_up_callbacks: Array[Callable] = []

# ===============================
# 公开属性（只读）
# ===============================
## 获取剩余时间
var time_left: float:
	get:
		if _following_timer != null:
			return _following_timer.time_left
		return max(0.0, _duration - _elapsed_time)

## 获取总时长
var duration: float:
	get:
		if _following_timer != null:
			return _following_timer.duration
		return _duration

# ===============================
# 生命周期方法
# ===============================
func _ready() -> void:

	# 创建并配置内部tick计时器
	_tick_timer = Timer.new()
	_tick_timer.wait_time = tick_interval
	_tick_timer.one_shot = false
	add_child(_tick_timer)
	_tick_timer.connect("timeout", Callable(self, "_on_tick"))
	
	# 初始化显示
	if _circular_material:
		_circular_material.set_shader_parameter("progress", 0.0)

func _on_tick() -> void:
	if not _enabled:
		return
	
	# 更新已用时间（应用时间缩放）
	_elapsed_time += _tick_timer.wait_time * GameManager.time_scale
	
	# 更新显示
	_update_display(time_left)
	
	# 检查是否完成
	if time_left <= 0.0:
		if _circular_material:
			_circular_material.set_shader_parameter("progress", 1.0)
		
		# 停止计时器
		_tick_timer.stop()
		
		# 隐藏进度条
		_circular_progress.visible = false
		_text_label.visible = false
		
		# 如果不是跟随计时器，重置状态
		if _following_timer == null:
			_duration = 0.0
			_elapsed_time = 0.0
			_enabled = false
		
		# 触发回调和信号
		_invoke_time_up_callbacks()
		time_up.emit()

# ===============================
# 公开接口
# ===============================
## 开始计时器
## @param time: 计时时长（秒）
## @param callback: 时间到达时的回调函数（可选）
func start_timer(time: float, callback: Callable = Callable()) -> void:
	_circular_progress.visible = true
	_text_label.visible = true
	
	_elapsed_time = 0.0
	_duration = time
	
	_enabled = true
	_following_timer = null
	
	# 清除并设置回调
	_time_up_callbacks.clear()
	if callback.is_valid():
		_time_up_callbacks.append(callback)
	
	# 启动tick计时器
	if not _tick_timer.is_stopped():
		_tick_timer.stop()
	_tick_timer.start()
	
	# 初始显示更新
	_update_display(time)

## 设置跟随其他计时器
## @param timer: 要跟随的计时器
func set_following(timer: TokenTimer) -> void:
	# 防止循环跟随
	if timer != self and (timer == null or timer._following_timer != self):
		_following_timer = timer
		_enabled = true

## 添加时间到达回调
## @param callback: 回调函数
func add_time_up_callback(callback: Callable) -> void:
	if callback.is_valid() and not _time_up_callbacks.has(callback):
		_time_up_callbacks.append(callback)

## 移除时间到达回调
## @param callback: 要移除的回调函数
func remove_time_up_callback(callback: Callable) -> void:
	_time_up_callbacks.erase(callback)

## 清除所有时间到达回调
func clear_time_up_callbacks() -> void:
	_time_up_callbacks.clear()

# ===============================
# 私有方法
# ===============================

## 更新显示UI
## @param time: 当前剩余时间
func _update_display(time: float) -> void:
	# 更新文本显示（对应Unity的time.ToString("0.0")）
	_text_label.text = "%.1f" % time
	
	# 更新进度条（对应Unity的fillAmount逻辑）
	if duration > 0.0:
		# 更新圆形进度条着色器（进度从0到1，时间越少进度越大）
		var circular_progress = 1.0 - (time / duration)
		_circular_material.set_shader_parameter("progress", circular_progress)
	else:
		_circular_material.set_shader_parameter("progress", 1.0)  # 时间结束，圆形满


## 触发所有时间到达回调
func _invoke_time_up_callbacks() -> void:
	for callback in _time_up_callbacks:
		if callback.is_valid():
			callback.call()
