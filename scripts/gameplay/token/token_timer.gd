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
## 文本显示组件的节点路径
@onready var text_label_path = $Label
## 圆形进度条组件的节点路径
@onready var circular_progress_path = $CircularProgress

# ===============================
# 私有属性
# ===============================
var _duration: float = 3
var _elapsed_time: float = 0.0
var _following_timer: TokenTimer = null
var _enabled: bool = false

# 节点引用（在_ready中初始化）
var _text_label: Label
var _circular_progress: ColorRect
var _circular_material: ShaderMaterial

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
	# 初始化节点引用
	_text_label = text_label_path
	_circular_progress = circular_progress_path
	
	# 获取圆形进度条的着色器材质
	if _circular_progress and _circular_progress.material:
		_circular_material = _circular_progress.material as ShaderMaterial
		if _circular_material == null:
			print("警告: CircularProgress的材质不是ShaderMaterial类型")
	else:
		print("警告: CircularProgress节点或其材质未找到")
	
	# 初始化显示
	if _circular_material:
		_circular_material.set_shader_parameter("progress", 0.0)
	_enabled = true

func _process(delta: float) -> void:
	if not _enabled:
		return
	
	# 更新已用时间（应用时间缩放）	
	_elapsed_time += delta * GameManager.time_scale
	
	# 更新显示
	_update_display(time_left)
	
	# 检查是否完成
	if time_left <= 0.0:
		if _circular_material:
			_circular_material.set_shader_parameter("progress", 1.0)  # 圆形进度条满
		
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
	_elapsed_time = 0.0
	_duration = time
	
	# 开发模式下时间缩放（对应Unity的GameManager.Instance.DevTime）
	if OS.is_debug_build() and GameManager and GameManager.has_method("get_dev_time"):
		_duration = GameManager.get_dev_time(time)
	
	_enabled = true
	_following_timer = null
	
	# 清除并设置回调
	_time_up_callbacks.clear()
	if callback.is_valid():
		_time_up_callbacks.append(callback)
	
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
