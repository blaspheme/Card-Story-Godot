# DeckModifierC - DeckModifier的计算执行版本
class_name DeckModifierC
extends RefCounted

var op: DeckModifier.DeckOp
var target: Fragment
var fragment: Fragment
var level: int
var context: Context
var deck_position: int
var shuffle_after: bool
var to_hand: bool

# 执行修改器
func execute() -> void:
	print("DeckModifier执行: ", DeckModifier.DeckOp.keys()[op])
	# 具体实现根据需要添加