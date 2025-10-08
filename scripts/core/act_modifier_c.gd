# ActModifierC - ActModifier的计算执行版本
class_name ActModifierC
extends RefCounted

var op: ActModifier.ActOp
var target: Fragment
var level: int
var context: Context

# 执行修改器
func execute() -> void:
	if not context:
		print("错误: ActModifierC.execute() - 缺少Context")
		return
	
	match op:
		ActModifier.ActOp.WARMTH:
			execute_warmth()
		ActModifier.ActOp.DRAW_CARDS:
			execute_draw_cards()
		ActModifier.ActOp.SPAWN_ELEMENT:
			execute_spawn_element()
		ActModifier.ActOp.DESTROY_ELEMENT:
			execute_destroy_element()
		ActModifier.ActOp.CHANGE_LOCATION:
			execute_change_location()
		_:
			print("错误: 未知的ActOp类型: ", op)

func execute_warmth() -> void:
	# 修改热度
	context.add_warmth(level)
	print("修改热度: ", level)

func execute_draw_cards() -> void:
	# 抽牌
	if context.scope and context.scope.has_method("draw_cards"):
		var cards_drawn = context.scope.draw_cards(abs(level))
		print("抽牌: ", cards_drawn.size(), " 张")
	else:
		print("警告: 作用域不支持抽牌操作")

func execute_spawn_element() -> void:
	# 生成元素
	if target:
		var location = 2  # 默认生成到桌面
		for i in range(abs(level)):
			context.create_fragment(target, location)
		print("生成元素: ", target.get_display_name(), " x", abs(level))

func execute_destroy_element() -> void:
	# 销毁元素
	if target and context.scope:
		var cards_to_destroy = []
		
		if context.scope.has_method("get_all_cards"):
			var all_cards = context.scope.get_all_cards()
			for card_viz in all_cards:
				if card_viz and card_viz.card and card_viz.card.contains_fragment(target):
					cards_to_destroy.append(card_viz)
					if cards_to_destroy.size() >= abs(level):
						break
		
		for card_viz in cards_to_destroy:
			if context.scope.has_method("destroy_card"):
				context.scope.destroy_card(card_viz)
			else:
				card_viz.queue_free()
		
		print("销毁元素: ", target.get_display_name(), " x", cards_to_destroy.size())

func execute_change_location() -> void:
	# 改变位置
	print("改变位置操作 - 需要具体实现")
	# 这里需要根据具体的游戏逻辑实现位置变更