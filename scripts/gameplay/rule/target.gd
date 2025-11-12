extends RefCounted
class_name Target

#region 属性
var fragment: FragmentData = null 
var cards: Array[CardViz] = []
#endregion

#region 构造函数
func _init_from_fragment(frag: FragmentData) -> void:
	fragment = frag

func _init_from_card_viz(card_viz: CardViz) -> void:
	cards = [card_viz]

func _init_from_cards(_cards: Array[CardViz]) -> void:
	cards = _cards.duplicate(true)

#endregion

#region 静态工厂方法
static func acquire_from_fragment(frag: FragmentData) -> Target:
	var t =  Target.new()
	t._init_from_fragment(frag)
	return t

static func acquire_from_card_viz(card_viz: CardViz) -> Target:
	var t =  Target.new()
	t._init_from_card_viz(card_viz)
	return t

static func acquire_from_cards(_cards: Array[CardViz]) -> Target:
	var t =  Target.new()
	t._init_from_cards(_cards)
	return t
#endregion
