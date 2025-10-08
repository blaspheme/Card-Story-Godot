# DeckModifier - 牌库修改器
class_name DeckModifier
extends Resource

# 牌库操作类型枚举
enum DeckOp {
	DRAW_CARDS = 0,			# 抽牌
	SHUFFLE_DECK = 10,		# 洗牌
	ADD_TO_DECK = 20,		# 添加卡牌到牌库
	REMOVE_FROM_DECK = 30,	# 从牌库移除卡牌
	SET_DECK_SIZE = 40,		# 设置牌库大小限制
	PEEK_DECK = 50,			# 查看牌库顶部
}

@export var op: DeckOp							# 操作类型
@export var target: Fragment					# 目标Fragment（筛选条件）
@export var fragment: Fragment					# 操作的Fragment
@export var level: int							# 操作数量
@export var reference: Fragment					# 参考Fragment（用于动态计算level）

# 牌库相关属性
@export_group("牌库属性")
@export var deck_position: int = 0				# 操作位置（0=顶部，-1=底部，其他=指定位置）
@export var shuffle_after: bool = false		# 操作后是否洗牌
@export var to_hand: bool = true				# 抽牌是否到手牌

# 计算为执行版本
func evaluate(context: Context) -> DeckModifierC:
	var computed_level = level
	
	# 如果设置了reference，根据其数量计算实际level
	if reference and context:
		var ref_count = context.count(reference, 0)
		computed_level = level * ref_count
	
	var result = DeckModifierC.new()
	result.op = op
	result.target = target
	result.fragment = fragment
	result.level = computed_level
	result.context = context
	result.deck_position = deck_position
	result.shuffle_after = shuffle_after
	result.to_hand = to_hand
	
	return result

# 获取操作类型的描述
func get_op_description() -> String:
	match op:
		DeckOp.DRAW_CARDS:
			return "抽牌"
		DeckOp.SHUFFLE_DECK:
			return "洗牌"
		DeckOp.ADD_TO_DECK:
			return "添加到牌库"
		DeckOp.REMOVE_FROM_DECK:
			return "从牌库移除"
		DeckOp.SET_DECK_SIZE:
			return "设置牌库大小"
		DeckOp.PEEK_DECK:
			return "查看牌库"
		_:
			return "未知操作"

# 验证修改器配置是否有效
func is_valid() -> bool:
	return level > 0 or op == DeckOp.SHUFFLE_DECK