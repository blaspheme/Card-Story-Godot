class_name GameManagerState
extends RefCounted

var cards: Array[CardVizState]
var tokens: Array[TokenVizState]
var decks: Array[DeckInst]
var table: String = ""
#var heap_cards: Array[int]
var heap: FragTreeState

func _init() -> void:
	cards = []
	tokens = []
	decks = []
	table = ""
	#heap_cards = []
	heap = null

## 保存数据
func save(_gm: GameManager) -> void:
	for _card in _gm.cards:
		cards.append(_card.save_state())
