extends RefCounted
class_name CardDecayState

var duration: float = 0.0
var elapsed_time: float = 0.0
var decay_to_path: String = ""
# var decay_to: CardData = null
var paused: bool = false

func to_dict() -> Dictionary:
	# 返回可直接用于 JSON.Print 的 Dictionary
	return {
		"duration": duration,
		"elapsed_time": elapsed_time,
		"decay_to": decay_to_path,
		"paused": paused
	}

static func from_dict(data: Dictionary) -> CardDecayState:
	var state := CardDecayState.new()

	state.duration = data.get("duration", 0.0)
	state.elapsed_time = data.get("elapsed_time", 0.0)
	state.decay_to_path = data.get("decay_to", "")
	state.paused = data.get("paused", false)

	return state
