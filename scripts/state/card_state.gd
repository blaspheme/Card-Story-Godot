extends RefCounted
class_name CardState

var data: CardData = preload("res://scripts/data/card_data.gd").new()
var position := Vector2.ZERO
var expired := false
