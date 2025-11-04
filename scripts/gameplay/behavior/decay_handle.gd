extends RefCounted
class_name DecayHandler

# handler 对象示例：实现 apply(state, params, dt)
# params 约定：{ "rate": float, "lifetime": float (可选) }

func apply(state, params: Dictionary, dt: float) -> void:
	if state == null:
		return
	var rate = float(params.get("rate", 1.0))
	# state.age 假定存在，若不存在则创建字段
	if not state.has("age"):
		state.age = 0.0
	state.age += rate * dt
	var lifetime = params.get("lifetime", (state.data.lifetime if state.data and state.data.has("lifetime") else 1.0))
	if state.age >= float(lifetime):
		state.expired = true
