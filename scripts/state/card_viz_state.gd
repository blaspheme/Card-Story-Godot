class_name CardVizState
extends RefCounted

var id: int = 0
var card: CardData
var frag_save: FragTreeState
var free: bool = false
var face_down: bool = false
var decay_save: CardDecayState
var stacked_cards: Array[int]
var child_cards: Array[int]
var position: Vector2 = Vector2.ZERO

func save(_card_viz: CardViz) -> void:
	id = _card_viz.get_instance_id()
	card = _card_viz.card_data
	frag_save = _card_viz.frag_tree.save_state()
	free = _card_viz.free
	position = _card_viz.position
	
