# DeckManager - 牌库管理器
class_name DeckManager
extends Node

# 单例实例
static var instance: DeckManager

# 牌库实例列表
@export var deck_instances: Array[DeckInst] = []

# 牌库字典映射
var deck_dict: Dictionary = {}

func _ready():
	# 设置单例
	if instance == null:
		instance = self
		deck_dict = {}
	else:
		queue_free()

# 获取牌库实例
func get_deck_inst(deck: Deck) -> DeckInst:
	if deck_dict.has(deck):
		return deck_dict[deck]
	else:
		var deck_inst = DeckInst.new(deck)
		deck_dict[deck] = deck_inst
		deck_instances.append(deck_inst)
		return deck_inst

# 从保存数据加载
func load_decks(decks: Array):
	deck_instances = decks
	deck_dict.clear()
	
	for deck_inst in deck_instances:
		if deck_inst is DeckInst:
			deck_dict[deck_inst.deck] = deck_inst

# 重置管理器
func reset():
	deck_instances.clear()
	deck_dict.clear()

# 获取指定牌库的剩余卡牌数量
func get_remaining_count(deck: Deck) -> int:
	var deck_inst = get_deck_inst(deck)
	return deck_inst.get_remaining_count() if deck_inst else 0

# 获取所有牌库的状态信息
func get_deck_status() -> Dictionary:
	var status = {}
	for deck in deck_dict.keys():
		var deck_inst = deck_dict[deck]
		status[deck.get_display_name()] = {
			"remaining": deck_inst.get_remaining_count(),
			"total": deck_inst.get_total_count(),
			"infinite": deck_inst.deck.infinite,
			"replenish": deck_inst.deck.replenish
		}
	return status

# 重新洗牌指定牌库
func reshuffle_deck(deck: Deck):
	var deck_inst = get_deck_inst(deck)
	if deck_inst:
		deck_inst.reshuffle()

# 向指定牌库添加卡牌
func add_to_deck(deck: Deck, fragment: Fragment):
	var deck_inst = get_deck_inst(deck)
	if deck_inst:
		deck_inst.add(fragment)

# 调试方法：打印所有牌库状态
func print_deck_status():
	print("=== 牌库状态 ===")
	var status = get_deck_status()
	for deck_name in status.keys():
		var info = status[deck_name]
		print("%s: %d/%d 张卡牌 (无限:%s, 补充:%s)" % [
			deck_name, info.remaining, info.total, 
			info.infinite, info.replenish
		])