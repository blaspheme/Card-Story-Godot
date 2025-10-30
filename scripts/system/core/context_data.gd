
extends RefCounted
class_name ContextData

# 轻量的数据持有对象，仅保存上下文相关字段，不包含复杂行为

var act_logic = null
var scope = null

var this_aspect = null
var this_card = null
var matches: Array = []

var act_modifiers: Array = []
var card_modifiers: Array = []
var table_modifiers: Array = []
var path_modifiers: Array = []
var deck_modifiers: Array = []

var _to_destroy: Array = []

var _disposed: bool = false
var _pooled: bool = false
var _in_pool: bool = false

func mark_pooled() -> void:
	_pooled = true
	_in_pool = false

func mark_in_pool() -> void:
	_in_pool = true

func mark_unpooled() -> void:
	_pooled = false
	_in_pool = false

func _clear_for_pool() -> void:
	act_logic = null
	scope = null
	this_aspect = null
	this_card = null
	if matches != null: matches.clear()
	if act_modifiers != null: act_modifiers.clear()
	if card_modifiers != null: card_modifiers.clear()
	if table_modifiers != null: table_modifiers.clear()
	if path_modifiers != null: path_modifiers.clear()
	if deck_modifiers != null: deck_modifiers.clear()
	_to_destroy.clear()

func is_disposed() -> bool:
	return _disposed

func mark_disposed() -> void:
	_disposed = true

func clear_modifier_lists() -> void:
	# 将 modifiers 列表的清理集中到 ContextData，按静态契约假定数组已初始化
	act_modifiers.clear()
	card_modifiers.clear()
	table_modifiers.clear()
	path_modifiers.clear()
	deck_modifiers.clear()

func destroy(card_viz) -> void:
	if card_viz != null:
		_to_destroy.append(card_viz)

func reset_matches() -> void:
	if scope != null and "cards" in scope:
		matches.clear()
		matches.append_array(scope.cards)
	else:
		matches.clear()

func save_matches() -> void:
	if scope != null:
		scope.matches = matches
