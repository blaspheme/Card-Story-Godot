extends Node
class_name DragManager

## 管理拖拽状态和输入的单例类

var dragging_viz: Viz = null
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	Manager.DRAG = self

func _input(event: InputEvent) -> void:
	if not dragging_viz:
		return
	if event is InputEventMouseMotion:
		dragging_viz.global_position = dragging_viz.get_global_mouse_position() - drag_offset
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag()

func start_drag(viz: Viz) -> void:
	dragging_viz = viz
	drag_offset = viz.get_global_mouse_position() - viz.global_position
	viz.z_index = 1000
	viz.area.input_pickable = false
	set_process_input(true)
	if viz.mouse_behavior:
		viz.mouse_behavior.on_begin_drag(viz)
	get_viewport().set_input_as_handled()

func _end_drag() -> void:
	if dragging_viz:
		dragging_viz.z_index = dragging_viz.original_z_index
		dragging_viz.area.input_pickable = true
		if dragging_viz.mouse_behavior:
			dragging_viz.mouse_behavior.on_end_drag(dragging_viz)
		dragging_viz = null
	set_process_input(false)
