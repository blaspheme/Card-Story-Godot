# CardModifier - 卡牌修改器
class_name CardModifier
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
enum CardOp {
	FRAGMENT_ADDITIVE = 0,	# 添加/移除Fragment到卡牌
	TRANSFORM = 10,			# 变形为其他卡牌
	DECAY = 100,			# 开始衰变过程
	SET_MEMORY = 140,		# 设置卡牌记忆
}

@export var op: CardOp						# 操作类型
@export var target: Fragment				# 目标Fragment（决定作用于哪些卡牌）
@export var fragment: Fragment				# 操作的Fragment或卡牌
@export var level: int						# 操作数量
@export var reference: Fragment				# 参考Fragment（用于动态计算level）

# 执行卡牌修改器
func execute(context: Context) -> void:
	if not context or not context.scope:
		return
	
	# 解析目标卡牌
	var target_obj = context.resolve_target(target)
	var target_cards = context.resolve_target_cards(target_obj, context.scope)
	var what = context.resolve_target(fragment)
	var resolved_level = context.count(reference, level)
	
	if not target_cards or not what:
		return
	
	match op:
		CardOp.FRAGMENT_ADDITIVE:
			_execute_fragment_additive(target_cards, what, resolved_level)
		CardOp.TRANSFORM:
			_execute_transform(target_cards, what, resolved_level, context)
		CardOp.DECAY:
			_execute_decay(target_cards, what, resolved_level)
		CardOp.SET_MEMORY:
			_execute_set_memory(target_cards, what)

# 添加/移除Fragment到卡牌
func _execute_fragment_additive(target_cards: Array, what: Target, resolved_level: int) -> void:
	for target_card in target_cards:
		if target_card and target_card.frag_tree:
			target_card.frag_tree.adjust(what, resolved_level)

# 变形卡牌
func _execute_transform(target_cards: Array, what: Target, resolved_level: int, context: Context) -> void:
	if resolved_level > 0:
		for target_card in target_cards:
			if what.fragment is Card:
				target_card.transform(what.fragment as Card)
				context.scope.adjust(target_card, resolved_level - 1)
			elif what.cards != null:
				for card_viz in what.cards:
					target_card.transform(card_viz.card)
					context.scope.adjust(target_card, resolved_level - 1)

# 开始衰变过程
func _execute_decay(target_cards: Array, what: Target, resolved_level: int) -> void:
	for target_card in target_cards:
		if what.fragment is Card:
			target_card.decay(what.fragment as Card, resolved_level)
		else:
			target_card.decay(target_card.card.decay_to, target_card.card.lifetime)

# 设置卡牌记忆
func _execute_set_memory(target_cards: Array, what: Target) -> void:
	for target_card in target_cards:
		if what.fragment is Aspect:
			target_card.frag_tree.memory_fragment = what.fragment
		elif what.cards != null and what.cards.size() > 0:
			target_card.frag_tree.memory_fragment = what.cards[0].frag_tree.memory_fragment

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		CardOp.FRAGMENT_ADDITIVE:
			return "添加/移除Fragment"
		CardOp.TRANSFORM:
			return "变形"
		CardOp.DECAY:
			return "衰变"
		CardOp.SET_MEMORY:
			return "设置记忆"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return target != null and fragment != null