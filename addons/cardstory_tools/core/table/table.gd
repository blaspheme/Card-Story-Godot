# Table - 桌面基类
class_name Table
extends Control

# Fragment树
@export var frag_tree: FragTree

# 最后位置记录
var last_locations: Dictionary = {}

# 抽象接口：转换位置
func to_local_position(grid_pos) -> Vector2:
	push_error("Table.to_local_position() 必须由子类实现")
	return Vector2.ZERO

func from_local_position(local_pos: Vector2):
	push_error("Table.from_local_position() 必须由子类实现")
	return Vector2.ZERO

# 抽象接口：查找空闲位置
func find_free_location(grid_pos, viz: Viz) -> bool:
	push_error("Table.find_free_location() 必须由子类实现")
	return false

# 抽象接口：查找多个空闲位置
func find_free_locations(viz: Viz, viz_list: Array[Viz]) -> Array:
	push_error("Table.find_free_locations() 必须由子类实现")
	return []

# 抽象接口：移除Viz
func remove_viz(viz: Viz):
	push_error("Table.remove_viz() 必须由子类实现")

# 抽象接口：保存/加载
func save() -> String:
	push_error("Table.save() 必须由子类实现")
	return ""

func load(json_data: String):
	push_error("Table.load() 必须由子类实现")

# 拖拽处理
func _can_drop_data(position: Vector2, data) -> bool:
	return data is Viz

func _drop_data(position: Vector2, data):
	if data is Viz:
		on_card_dock(data)

# 点击处理
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 检查是否点击了卡牌
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsPointQueryParameters2D.new()
			query.position = global_position + event.position
			
			var results = space_state.intersect_point(query)
			var has_card = false
			
			for result in results:
				if result.collider is CardViz:
					has_card = true
					break
			
			if not has_card:
				_on_empty_click(event.position)

# 卡牌停靠处理
func on_card_dock(viz: Viz):
	if not viz:
		return
	
	# 获取当前位置
	var current_pos = from_local_position(viz.position)
	
	# 查找空闲位置
	if find_free_location(current_pos, viz):
		place_viz_at(viz, current_pos, GameManager.instance.normal_speed if GameManager.instance else 1.0)
	else:
		# 没有空闲位置，返回到最后位置
		return_to_table(viz)

# 卡牌离开处理
func on_card_undock(viz: Viz):
	pass  # 基类不需要特殊处理

# 放置多个Viz
func place_viz(anchor_viz: Viz, viz_list: Array[Viz]):
	if not anchor_viz or viz_list.is_empty():
		return
	
	var locations = find_free_locations(anchor_viz, viz_list)
	
	if locations.size() >= viz_list.size():
		for i in range(viz_list.size()):
			var viz = viz_list[i]
			var location = locations[i]
			place_viz_at(viz, location, GameManager.instance.normal_speed if GameManager.instance else 1.0)

# 在指定位置放置Viz
func place_viz_at(viz: Viz, grid_pos, move_speed: float):
	if not viz:
		return
	
	# 记录位置
	last_locations[viz] = grid_pos
	
	# 设置父节点
	viz.reparent(self)
	
	# 移动到目标位置
	var target_pos = to_local_position(grid_pos)
	
	if move_speed > 0:
		# 创建移动动画
		var tween = create_tween()
		tween.tween_property(viz, "position", target_pos, move_speed)
	else:
		# 立即移动
		viz.position = target_pos
	
	# 完成放置
	_finalize_placement(viz)

# 返回桌面
func return_to_table(viz: Viz):
	if not viz:
		return
	
	var target_pos
	
	# 尝试使用最后位置
	if last_locations.has(viz):
		target_pos = last_locations[viz]
		if find_free_location(target_pos, viz):
			place_viz_at(viz, target_pos, GameManager.instance.normal_speed if GameManager.instance else 1.0)
			return
	
	# 查找新位置
	target_pos = from_local_position(viz.position)
	if find_free_location(target_pos, viz):
		place_viz_at(viz, target_pos, GameManager.instance.normal_speed if GameManager.instance else 1.0)

# 获取桌面上的卡牌
func get_cards() -> Array[CardViz]:
	var cards: Array[CardViz] = []
	
	if frag_tree:
		cards = frag_tree.cards
	else:
		# 备用方法：遍历子节点
		for child in get_children():
			if child is CardViz:
				cards.append(child)
	
	return cards

# 高亮卡牌
func highlight_cards(cards: Array[CardViz]):
	if not cards or cards.is_empty():
		return
	
	for card in cards:
		if card and card.has_method("set_highlight"):
			card.set_highlight(true)

# 检查最后位置
func has_last_location(viz: Viz) -> bool:
	return last_locations.has(viz)

func get_last_location(viz: Viz):
	return last_locations.get(viz)

# 完成放置（私有方法）
func _finalize_placement(viz: Viz):
	# 更新Viz状态
	if viz.has_method("set_free"):
		viz.set_free(true)
	
	if viz.has_method("set_interactive"):
		viz.set_interactive(true)
	
	# 触发事件
	if viz is CardViz and GameManager.instance:
		GameManager.instance.trigger_card_in_play(viz)

# 空白区域点击处理
func _on_empty_click(local_pos: Vector2):
	# 取消所有UI选择
	if GameManager.instance and GameManager.instance.has_method("clear_selections"):
		GameManager.instance.clear_selections()

# 查找卡牌（受保护方法）
func _find_cards() -> Array[CardViz]:
	return get_cards()

# 清理方法
func clear():
	last_locations.clear()
	
	# 移除所有子Viz
	for child in get_children():
		if child is Viz:
			child.queue_free()

# 获取桌面统计信息
func get_table_stats() -> Dictionary:
	var cards = get_cards()
	var tokens: Array[TokenViz] = []
	
	for child in get_children():
		if child is TokenViz:
			tokens.append(child)
	
	return {
		"card_count": cards.size(),
		"token_count": tokens.size(),
		"total_viz_count": cards.size() + tokens.size()
	}

# 调试方法
func print_table_status():
	var stats = get_table_stats()
	print("=== 桌面状态 ===")
	print("卡牌数量: %d" % stats.card_count)
	print("令牌数量: %d" % stats.token_count)
	print("总计: %d" % stats.total_viz_count)
	print("记录位置: %d" % last_locations.size())
	print("================")