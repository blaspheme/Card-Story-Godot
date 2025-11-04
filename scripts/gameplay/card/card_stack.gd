# 卡牌堆叠组件，负责卡牌堆叠的 UI 显示和用户交互， 作为 CardViz2D 的子节点存在
extends Node
class_name CardStack

# ===============================
# SceneTree引用
# ===============================
## 堆叠计数器的 Node（数量>1时显示）
@onready var stack_counter: Node2D = $"."
## 显示堆叠数量的文本组件
@onready var count_label: Label = $Label

# ===============================
# 属性
# ===============================
# 标记是否正在进行堆叠拖拽（区分从堆叠拖拽还是从单卡拖拽）
var stack_drag : bool = false
## 当前堆叠中的卡牌数量
var count : int = 0
## 持有此 CardStack 的父 CardViz
var parent_node : CardViz
## 堆叠最大数量限制（99张）
const max_count : int = 99

# ===============================
# 信号机制
# ===============================
@warning_ignore("unused_parameter")
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	# 进行堆叠拖拽
	if not stack_drag:
		return

func _on_area_2d_mouse_entered() -> void:
	stack_drag = true

func _on_area_2d_mouse_exited() -> void:
	stack_drag = false
