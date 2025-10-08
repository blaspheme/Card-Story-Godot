# TableModifierC - TableModifier的计算执行版本
class_name TableModifierC
extends RefCounted

var op: TableModifier.TableOp
var target: Fragment
var fragment: Fragment
var level: int
var context: Context

# 执行修改器
func execute() -> void:
	if not fragment or not context or not context.scope:
		print("错误: TableModifierC.execute() - 缺少必要参数")
		return
	
	match op:
		TableModifier.TableOp.SITUATION_CREATE:
			execute_situation_create()
		TableModifier.TableOp.SITUATION_DESTROY:
			execute_situation_destroy()
		TableModifier.TableOp.SET_VERB:
			execute_set_verb()
		_:
			print("错误: 未知的TableOp类型: ", op)

func execute_situation_create() -> void:
	# 在桌面创建情境Fragment
	if not fragment is Card:
		print("错误: 情境必须是Card类型")
		return
	
	var situation_card = fragment as Card
	
	# 检查桌面是否已存在此情境
	if context.scope.has_method("has_situation"):
		if context.scope.has_situation(situation_card):
			print("情境已存在: ", situation_card.get_display_name())
			return
	
	# 创建情境到桌面
	if context.scope.has_method("create_situation"):
		context.scope.create_situation(situation_card)
		print("创建情境: ", situation_card.get_display_name())
	else:
		# 备用方法：直接添加到桌面
		context.create_fragment(situation_card, 2)  # 2 = 桌面
	
	EventBus.emit_fragment_created(situation_card, 2)

func execute_situation_destroy() -> void:
	# 销毁桌面上的情境Fragment
	if not context.scope.has_method("get_table_cards"):
		return
	
	var table_cards = context.scope.get_table_cards()
	var destroyed_count = 0
	
	for card_viz in table_cards:
		if card_viz and card_viz.card:
			var should_destroy = false
			
			if target:
				# 销毁包含特定Fragment的卡牌
				should_destroy = card_viz.card.contains_fragment(target)
			else:
				# 销毁匹配Fragment的卡牌
				should_destroy = card_viz.card == fragment or card_viz.card.contains_fragment(fragment)
			
			if should_destroy and destroyed_count < abs(level):
				# 销毁情境
				if context.scope.has_method("destroy_card"):
					context.scope.destroy_card(card_viz)
				else:
					# 备用方法：直接移除
					card_viz.queue_free()
				
				destroyed_count += 1
				print("销毁情境: ", card_viz.card.get_display_name())
				EventBus.emit_card_destroyed(card_viz.card)

func execute_set_verb() -> void:
	# 设置桌面或特定卡牌的动作动词
	var verb_text = ""
	
	if fragment and fragment.has_method("get_verb"):
		verb_text = fragment.get_verb()
	elif fragment:
		verb_text = fragment.get_display_name()
	
	if target:
		# 为特定卡牌设置动词
		set_verb_for_matching_cards(verb_text)
	else:
		# 为整个桌面设置动词
		if context.scope.has_method("set_table_verb"):
			context.scope.set_table_verb(verb_text)
			print("设置桌面动词: ", verb_text)

func set_verb_for_matching_cards(verb_text: String) -> void:
	if not context.scope.has_method("get_table_cards"):
		return
	
	var table_cards = context.scope.get_table_cards()
	
	for card_viz in table_cards:
		if card_viz and card_viz.card and card_viz.card.contains_fragment(target):
			# 为匹配的卡牌设置动词
			if card_viz.has_method("set_verb"):
				card_viz.set_verb(verb_text)
			
			print("为卡牌设置动词: ", card_viz.card.get_display_name(), " -> ", verb_text)