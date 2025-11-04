extends RefCounted
class_name BehaviorSystem

# 被动式系统，由 GameManager 创建并驱动
# handler: object with apply(state, params, dt) 或 Callable

var registry: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init():
	rng.randomize()

func register_handler(id: String, handler) -> void:
	if id == "":
		push_warning("BehaviorSystem.register_handler: empty id")
		return
	registry[id] = handler

func unregister_handler(id: String) -> void:
	registry.erase(id)

func apply_behaviors(card_states: Array, dt: float) -> void:
	if card_states == null:
		return
	for state in card_states:
		_apply_to_state(state, dt)

func _apply_to_state(state, dt: float) -> void:
	if state == null or state.data == null:
		return
	var behaviors = state.data.behaviors if state.data.has("behaviors") else null
	if behaviors == null:
		return
	for b in behaviors:
		if b == null: continue
		var id = b.behavior_id if typeof(b) == TYPE_OBJECT and b.has("behavior_id") else (b.get("behavior_id", null) if typeof(b) == TYPE_DICTIONARY else null)
		if id == null: continue
		var handler = registry.get(id, null)
		if handler == null: continue
		var params = b.params if typeof(b) == TYPE_OBJECT and b.has("params") else (b.get("params", {}) if typeof(b) == TYPE_DICTIONARY else {})
		if typeof(handler) == TYPE_OBJECT and handler.has_method("apply"):
			handler.apply(state, params, dt)
		elif handler is Callable:
			handler.call_func(state, params, dt)

func set_seed(seed: int) -> void:
	rng.seed = seed

func get_rng() -> RandomNumberGenerator:
	return rng
