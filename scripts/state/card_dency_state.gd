extends RefCounted
class_name CardDecayState

var duration: float = 0.0
var elapsed_time: float = 0.0
# 存资源路径或自定义唯一 ID（不要直接保存对象引用）
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

static func from_dict(d: Dictionary) -> CardDecayState:
	var s = CardDecayState.new()
	if d == null:
		return s
	if d.has("duration"):
		s.duration = float(d["duration"])
	if d.has("elapsed_time"):
		s.elapsed_time = float(d["elapsed_time"])
	if d.has("decay_to"):
		s.decay_to_path = str(d["decay_to"])
	if d.has("paused"):
		s.paused = bool(d["paused"])
	return s
