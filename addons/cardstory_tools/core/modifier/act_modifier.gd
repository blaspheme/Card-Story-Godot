# ActModifier - 游戏状态修改器
class_name ActModifier
extends Resource

# 目标类，用于表示修改器的作用目标
class Target:
	var fragment: Fragment
	var cards: Array[CardViz]
	
	func _init(target = null):
		if target is Fragment:
			fragment = target
		elif target is CardViz:
			cards = [target]
		elif target is Array:
			cards = target.duplicate()

# 操作类型枚举
enum ActOp {
	ADJUST = 0,			# 调整Fragment/卡牌数量
	GRAB = 20,			# 抓取/移动卡牌
	SET_MEMORY = 40,	# 设置记忆Fragment
	RUN_TRIGGERS = 50	# 触发Fragment的规则
}

@export var op: ActOp							# 操作类型
@export var fragment: Fragment					# 目标Fragment
@export var level: int							# 操作数值或乘数
@export var ref_loc: Test.ReqLoc				# 参考位置
@export var reference: Fragment					# 参考Fragment（用于动态计算level）

# 执行行动修改器
func execute(context: Context) -> void:
	if not context or not context.scope:
		return
	
	var target_obj = context.resolve_target(fragment)
	var frag = context.resolve_fragment(reference)
	var resolved_level = level
	
	if frag != null:
		resolved_level = level * Test.get_count(context, ref_loc, frag)
	
	# 仅用于 Grab 操作
	var all = level == 0
	
	if not target_obj:
		return
	
	match op:
		ActOp.ADJUST:
			_execute_adjust(target_obj, resolved_level, context)
		ActOp.GRAB:
			_execute_grab(target_obj, resolved_level, all, context)
		ActOp.SET_MEMORY:
			_execute_set_memory(target_obj, context)
		ActOp.RUN_TRIGGERS:
			_execute_run_triggers(target_obj, context)

# 调整Fragment/卡牌数量
func _execute_adjust(target_obj: Target, resolved_level: int, context: Context) -> void:
	if target_obj.cards != null:
		for card_viz in target_obj.cards:
			var count = context.scope.adjust(card_viz, resolved_level)
			if resolved_level < 0 and count < 0:
				context.destroy(card_viz)
	elif target_obj.fragment is Card and resolved_level < 0:
		var cards = context.scope.find_all(target_obj.fragment as Card)
		var count = context.scope.adjust(target_obj.fragment, resolved_level)
		if count < 0:
			count = -count
			for i in range(min(count, cards.size())):
				context.destroy(cards[i])
	else:
		context.scope.adjust(target_obj.fragment, resolved_level)

# 抓取/移动卡牌
func _execute_grab(target_obj: Target, resolved_level: int, all: bool, context: Context) -> void:
	var target_cards_y = context.resolve_target_cards(target_obj, GameManager.instance.root)
	if target_cards_y != null:
		var target_cards: Array[CardViz] = []
		for card_viz in target_cards_y:
			var target_card = card_viz.stack if card_viz.stack else card_viz
			if target_card.visible:
				target_cards.append(target_card)
		
		resolved_level = target_cards.size() if all else resolved_level
		for i in range(min(resolved_level, target_cards.size())):
			context.act_logic.token_viz.grab(target_cards[i])

# 设置记忆Fragment
func _execute_set_memory(target_obj: Target, context: Context) -> void:
	if target_obj.fragment != null:
		context.scope.memory_fragment = target_obj.fragment
	elif target_obj.cards.size() > 0:
		context.scope.memory_fragment = target_obj.cards[0].frag_tree.memory_fragment

# 触发Fragment的规则
func _execute_run_triggers(target_obj: Target, context: Context) -> void:
	if context.act_logic:
		context.act_logic.inject_triggers(target_obj)

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		ActOp.ADJUST:
			return "调整数量"
		ActOp.GRAB:
			return "抓取移动"
		ActOp.SET_MEMORY:
			return "设置记忆"
		ActOp.RUN_TRIGGERS:
			return "运行触发器"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return fragment != null
