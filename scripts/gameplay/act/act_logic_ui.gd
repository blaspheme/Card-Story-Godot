extends Node
class_name ActLogicUI

# UI glue script that connects an ActLogic (flow-only) to the ActWindow (display).
# Responsibilities:
# - Listen to ActLogic signals and call ActWindow methods to update visuals.
# - Keep UI-related code out of ActLogic so flow logic stays testable and headless.

@export var act_logic_path: NodePath
@export var act_window_path: NodePath

@onready var act_logic = get_node(act_logic_path)
@onready var act_window = get_node(act_window_path)

func _ready() -> void:
	# 快速失败：缺少依赖应当尽早暴露
	assert(act_logic != null)
	assert(act_window != null)

	# 连接 ActLogic 的信号到 UI 处理器
	act_logic.connect("act_started", Callable(self, "_on_act_started"))
	act_logic.connect("act_status_changed", Callable(self, "_on_act_status_changed"))
	act_logic.connect("act_update", Callable(self, "_on_act_update"))
	act_logic.connect("act_setup_result_cards", Callable(self, "_on_setup_result_cards"))
	act_logic.connect("act_results_ready", Callable(self, "_on_results_ready"))
	act_logic.connect("act_end_text_changed", Callable(self, "_on_end_text_changed"))
	act_logic.connect("act_timer_started", Callable(self, "_on_timer_started"))
	act_logic.connect("act_timer_stopped", Callable(self, "_on_timer_stopped"))

func _on_act_started(_act) -> void:
	# 将卡片附着到窗口并刷新状态/槽位显示
	act_window.ParentSlotCardsToWindow()
	act_window.ApplyStatus("Running")
	act_window.UpdateSlots()

func _on_act_status_changed(status) -> void:
	act_window.ApplyStatus(status)

func _on_act_update() -> void:
	act_window.UpdateSlots()

func _on_setup_result_cards(direct_cards) -> void:
	act_window.SetupResultCards(direct_cards)

func _on_results_ready(_frag_tree, _active_act) -> void:
	# 可选：展示最终面板或播放动画
	# 这里保持最小实现，交给 ActWindow 来决定如何展示
	act_window.UpdateSlots()

func _on_end_text_changed(text) -> void:
	# 假定 ActWindow 提供 SetEndText 接口，由 ActWindow 实现显示逻辑
	# 若不存在该方法，调用会在运行时失败以便尽快修复契约
	if text != "":
		act_window.SetEndText(text)

func _on_timer_started(_time) -> void:
	# UI 可展示倒计时或变动状态
	# 这里使用 ApplyStatus/UpdateSlots 作为默认行为
	act_window.ApplyStatus("Running")
	act_window.UpdateSlots()

func _on_timer_stopped() -> void:
	# 停止时刷新 UI
	act_window.UpdateSlots()
