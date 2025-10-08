# UIManager - UI管理器
class_name UIManager
extends Node

# 单例实例
static var instance: UIManager

# UI 组件引用
@export var card_info: CardInfo
@export var aspect_info: AspectInfo
@export var main_menu: Control
@export var game_hud: Control
@export var pause_menu: Control
@export var settings_panel: Control

# UI 状态
var current_ui_state: UIState = UIState.MAIN_MENU
var ui_stack: Array[UIState] = []
var is_ui_locked: bool = false

# UI 状态枚举
enum UIState {
	MAIN_MENU,
	GAME_HUD,
	PAUSE_MENU,
	SETTINGS,
	CARD_INFO,
	ASPECT_INFO,
	LOADING
}

# 信号
signal ui_state_changed(old_state: UIState, new_state: UIState)
signal ui_locked_changed(locked: bool)

func _ready():
	# 设置单例
	if instance == null:
		instance = self
	else:
		queue_free()
		return
	
	# 初始化UI状态
	_initialize_ui()

func _initialize_ui():
	# 隐藏所有UI面板
	_hide_all_panels()
	
	# 显示主菜单
	switch_to_state(UIState.MAIN_MENU)

# 切换UI状态
func switch_to_state(new_state: UIState, push_current: bool = false):
	if is_ui_locked:
		push_warning("UI被锁定，无法切换状态")
		return
	
	var old_state = current_ui_state
	
	# 可选择保存当前状态到栈中
	if push_current and current_ui_state != new_state:
		ui_stack.push_back(current_ui_state)
	
	# 隐藏当前状态的UI
	_hide_state_ui(old_state)
	
	# 更新状态
	current_ui_state = new_state
	
	# 显示新状态的UI
	_show_state_ui(new_state)
	
	# 发送状态改变信号
	ui_state_changed.emit(old_state, new_state)
	
	print("UI状态切换: ", _get_state_name(old_state), " -> ", _get_state_name(new_state))

# 返回上一个UI状态
func pop_state():
	if ui_stack.is_empty():
		push_warning("UI栈为空，无法返回")
		return
	
	var previous_state = ui_stack.pop_back()
	switch_to_state(previous_state)

# 锁定/解锁UI
func lock_ui():
	is_ui_locked = true
	ui_locked_changed.emit(true)

func unlock_ui():
	is_ui_locked = false
	ui_locked_changed.emit(false)

# 显示卡牌信息
func show_card_info(card: Card):
	if card_info:
		card_info.load_card(card)
		switch_to_state(UIState.CARD_INFO, true)

# 显示Aspect信息  
func show_aspect_info(aspect: Aspect):
	if aspect_info:
		aspect_info.load_aspect(aspect)
		switch_to_state(UIState.ASPECT_INFO, true)

# 隐藏信息面板
func hide_info_panels():
	if current_ui_state == UIState.CARD_INFO or current_ui_state == UIState.ASPECT_INFO:
		pop_state()

# 显示暂停菜单
func show_pause_menu():
	switch_to_state(UIState.PAUSE_MENU, true)

# 隐藏暂停菜单
func hide_pause_menu():
	if current_ui_state == UIState.PAUSE_MENU:
		pop_state()

# 显示设置面板
func show_settings():
	switch_to_state(UIState.SETTINGS, true)

# 隐藏设置面板
func hide_settings():
	if current_ui_state == UIState.SETTINGS:
		pop_state()

# 开始游戏
func start_game():
	switch_to_state(UIState.GAME_HUD)

# 返回主菜单
func return_to_main_menu():
	ui_stack.clear()
	switch_to_state(UIState.MAIN_MENU)

# 显示加载画面
func show_loading():
	switch_to_state(UIState.LOADING)

# 重置UI
func reset_ui():
	ui_stack.clear()
	unlock_ui()
	
	if card_info and card_info.has_method("unload"):
		card_info.unload()
	
	if aspect_info and aspect_info.has_method("unload"):
		aspect_info.unload()
	
	return_to_main_menu()

# 私有方法 - 隐藏所有面板
func _hide_all_panels():
	if main_menu:
		main_menu.hide()
	if game_hud:
		game_hud.hide()
	if pause_menu:
		pause_menu.hide()
	if settings_panel:
		settings_panel.hide()
	if card_info:
		card_info.hide()
	if aspect_info:
		aspect_info.hide()

# 私有方法 - 根据状态隐藏UI
func _hide_state_ui(state: UIState):
	match state:
		UIState.MAIN_MENU:
			if main_menu:
				main_menu.hide()
		UIState.GAME_HUD:
			if game_hud:
				game_hud.hide()
		UIState.PAUSE_MENU:
			if pause_menu:
				pause_menu.hide()
		UIState.SETTINGS:
			if settings_panel:
				settings_panel.hide()
		UIState.CARD_INFO:
			if card_info:
				card_info.hide()
		UIState.ASPECT_INFO:
			if aspect_info:
				aspect_info.hide()

# 私有方法 - 根据状态显示UI
func _show_state_ui(state: UIState):
	match state:
		UIState.MAIN_MENU:
			if main_menu:
				main_menu.show()
		UIState.GAME_HUD:
			if game_hud:
				game_hud.show()
		UIState.PAUSE_MENU:
			if pause_menu:
				pause_menu.show()
		UIState.SETTINGS:
			if settings_panel:
				settings_panel.show()
		UIState.CARD_INFO:
			if card_info:
				card_info.show()
		UIState.ASPECT_INFO:
			if aspect_info:
				aspect_info.show()
		UIState.LOADING:
			# 加载状态可能需要特殊处理
			pass

# 私有方法 - 获取状态名称
func _get_state_name(state: UIState) -> String:
	match state:
		UIState.MAIN_MENU:
			return "主菜单"
		UIState.GAME_HUD:
			return "游戏界面"
		UIState.PAUSE_MENU:
			return "暂停菜单"
		UIState.SETTINGS:
			return "设置"
		UIState.CARD_INFO:
			return "卡牌信息"
		UIState.ASPECT_INFO:
			return "Aspect信息"
		UIState.LOADING:
			return "加载中"
		_:
			return "未知状态"

# 输入处理
func _unhandled_input(event):
	# ESC键处理
	if event.is_action_pressed("ui_cancel"):
		match current_ui_state:
			UIState.GAME_HUD:
				show_pause_menu()
			UIState.PAUSE_MENU, UIState.SETTINGS, UIState.CARD_INFO, UIState.ASPECT_INFO:
				pop_state()
		
		# 阻止事件继续传播
		get_viewport().set_input_as_handled()

# 工具方法
func is_in_game() -> bool:
	return current_ui_state == UIState.GAME_HUD

func is_menu_open() -> bool:
	return current_ui_state in [UIState.PAUSE_MENU, UIState.SETTINGS]

func is_info_panel_open() -> bool:
	return current_ui_state in [UIState.CARD_INFO, UIState.ASPECT_INFO]

func get_current_state_name() -> String:
	return _get_state_name(current_ui_state)

# UI动画方法
func fade_in_panel(panel: Control, duration: float = 0.3):
	if not panel:
		return
	
	panel.modulate.a = 0.0
	panel.show()
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, duration)

func fade_out_panel(panel: Control, duration: float = 0.3):
	if not panel:
		return
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	tween.tween_callback(panel.hide)

func slide_in_panel(panel: Control, direction: Vector2, duration: float = 0.3):
	if not panel:
		return
	
	var original_pos = panel.position
	panel.position = original_pos + direction
	panel.show()
	
	var tween = create_tween()
	tween.tween_property(panel, "position", original_pos, duration)

# 调试方法
func print_ui_state():
	print("当前UI状态: ", _get_state_name(current_ui_state))
	print("UI栈: ", ui_stack.map(_get_state_name))
	print("UI锁定: ", is_ui_locked)
