extends Node2D
class_name Table

# 抽象 Table 基类，游戏桌面，管理 Viz 的位置
#region 属性
## 用于管理卡牌集合
var frag_tree : FragTree
## 记录每个 Viz 对象的上次位置（key: Viz, value: Variant 类型的位置）
var last_locations := {}
#endregion

#region 抽象方法（子类必须实现）
## 将位置 t 转换为本地坐标（相对于 Table）
## @param t: 位置类型（Vector2Int、Vector2 等）
## @return: 本地坐标（Vector2）
@warning_ignore("unused_parameter")
func to_local_position(t: Variant) -> Vector2:
	push_error("Table.to_local_position() 必须由子类实现")
	return Vector2.ZERO

## 将本地坐标转换为位置 t
## @param pos: 本地坐标（Vector2）
## @return: 位置类型（Vector2Int、Vector2 等）
@warning_ignore("unused_parameter")
func from_local_position(pos: Vector2) -> Variant:
	push_error("Table.from_local_position() 必须由子类实现")
	return null

## 在 t 位置或其附近找到一个空闲位置
## @param t: 引用参数（数组包装），输入初始位置，输出找到的空闲位置
## @param viz: 要放置的对象
## @return: 是否找到空闲位置
@warning_ignore("unused_parameter")
func find_free_location(t: Variant, viz: Viz) -> bool:
	push_error("Table.find_free_location() 必须由子类实现")
	return false

## 为多个对象找到空闲位置
## @param viz: 搜索起点附近的对象
## @param list: 要放置的对象列表
## @return: 位置列表（Array[Variant]）
@warning_ignore("unused_parameter")
func find_free_locations(viz: Viz, list: Array[Viz]) -> Array:
	push_error("Table.find_free_locations() 必须由子类实现")
	return []

## 从桌面移除对象
@warning_ignore("unused_parameter")
func remove(viz: Viz) -> void:
	push_error("Table.remove() 必须由子类实现")

## 保存桌面状态为 JSON
func save() -> String:
	push_error("Table.save() 必须由子类实现")
	return ""

## 从 JSON 加载桌面状态
@warning_ignore("unused_parameter")
func load(json_str: String) -> void:
	push_error("Table.load() 必须由子类实现")
#endregion

#region 虚方法（子类可选重写）
## 处理拖放事件
func on_drop(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var dragging_viz = _get_dragging_viz()
			if dragging_viz and dragging_viz.is_dragging:
				on_card_dock(dragging_viz)

## 处理点击事件
func on_pointer_down(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var card_viz = _get_card_at_position(event.position)
			if card_viz == null:
				EventBus.card_info_unload.emit()
				EventBus.aspect_info_unload.emit()

## 卡牌停靠到桌面
func on_card_dock(viz: Viz) -> void:
	if not viz:
		return
	
	var local_pos := viz.global_position - global_position
	var loc = from_local_position(local_pos)
	
	if find_free_location(loc, viz):
		place(viz, loc, Manager.GM.fast_speed)
	else:
		push_error("无法在桌面上找到空闲位置")
	

## 卡牌离开桌面（对应 Unity 的 OnCardUndock）
@warning_ignore("unused_parameter")
func on_card_undock(viz: Viz) -> void:
	pass

## 在桌面上放置多个对象
func place_multiple(viz: Viz, list: Array[Viz]) -> void:
	var locations := find_free_locations(viz, list)
	var i := 0
	for lviz in list:
		if i >= locations.size():
			push_error("桌面空间不足，无法放置所有对象")
			break
		place(lviz, locations[i], Manager.GM.normal_speed)
		i += 1

## 将 Viz 放置在指定位置 t，并以给定速度移动过去
## @param viz: 要放置的 Viz 对象
## @param t: 目标位置（位置类型根据 Table 子类而定）
## @param move_speed: 移动速度（像素/秒）
func place(viz: Viz, t: Variant, move_speed: float) -> void:
	if frag_tree:
		viz.reparent(frag_tree)
	else:
		viz.reparent(self)
	_do_move(viz, t, move_speed)
	last_locations[viz] = t

## 返回到上次位置或最近位置
func return_to_table(viz: Viz) -> void:
	if viz == null:
		return
	
	if viz in last_locations:
		var loc = last_locations[viz]
		if find_free_location(loc, viz):
			place(viz, loc, Manager.GM.normal_speed)
	else:
		on_card_dock(viz)

## 获取桌面上的所有卡牌
func get_cards() -> Array[CardViz]:
	if frag_tree:
		return frag_tree.cards()
	return []

## 高亮显示卡牌列表
func highlight_cards(cards: Array[CardViz]) -> void:
	if cards.is_empty():
		return
	
	_highlight_cards_async(cards)

## 检查是否记录了 viz 的上次位置
func last_location_exists(viz: Viz) -> bool:
	return viz in last_locations

## 获取 viz 的上次位置（带输出参数）
func get_last_location(viz: Viz) -> Variant:
	if viz in last_locations:
		return last_locations[viz]
	return null
#endregion

#region 受保护方法（供子类使用）
## 最终确定对象在桌面上的位置
func _put_on(viz: Viz) -> void:
	# 确保卡片在 frag_tree 下
	if frag_tree and viz.get_parent() != frag_tree:
		viz.reparent(frag_tree)
	var local_pos := viz.position
	viz.position = Vector2(local_pos.x, local_pos.y)

## 查找桌面上的所有卡牌
func _find_cards() -> Array[CardViz]:
	var cards: Array[CardViz] = []
	var all_children := NodeUtils.find_children_recursive(self, CardViz, true)
	for child in all_children:
		if child is CardViz:
			cards.append(child)
	return cards

## 执行移动动画
func _do_move(viz: Viz, t: Variant, speed: float) -> void:
	var target_pos := to_local_position(t) + global_position
	
	var tween := create_tween()
	tween.tween_property(viz, "global_position", target_pos, speed)
	tween.tween_callback(func(): _put_on(viz))

## 高亮卡牌的异步协程
func _highlight_cards_async(cards: Array[CardViz]) -> void:
	for card in cards:
		if card:
			card.set_highlight(true)
	
	await get_tree().create_timer(1.0).timeout
	
	for card in cards:
		if card:
			card.set_highlight(false)
#endregion

#region 辅助方法
## 获取当前正在拖拽的 Viz 对象
func _get_dragging_viz() -> Viz:
	for child in get_children():
		if child is Viz and child.is_dragging:
			return child
	return null

## 获取指定位置的 CardViz
func _get_card_at_position(pos: Vector2) -> CardViz:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = pos
	var results := space_state.intersect_point(query)
	
	for result in results:
		var collider = result.collider
		if collider is Area2D:
			var card = collider.get_parent()
			if card is CardViz:
				return card
	return null
#endregion
