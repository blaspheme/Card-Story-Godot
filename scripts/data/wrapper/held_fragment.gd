extends Resource
class_name HeldFragmentData

# ===============================
# Fragment 的判定资源类，目前是 count
# ===============================
@export var fragment: FragmentData
@export var count: int = 1

#region 内部方法
func _init(_fragment: FragmentData = null, _count: int = 1) -> void:
	fragment = _fragment
	count = _count
#endregion

#region 公开方法
static func adjust_in_list(list: Array[HeldFragmentData], _fragment: FragmentData, level: int) -> int:
	if list == null or _fragment == null:
		return 0

	var matches: Array[HeldFragmentData] = list.filter(func(hf): return hf.fragment == _fragment)
	var found: HeldFragmentData =  matches[0] if matches.size() > 0 else null
	
	if found != null:
		var old_c := found.count
		found.count += level
		if found.count <= 0:
			list.erase(found)
		return max(0, found.count) - old_c
	else:
		if level > 0:
			list.append(HeldFragmentData.new(_fragment, level))
			return level
		else:
			return 0

func add_to_list(list: Array[HeldFragmentData]) -> int:
	return HeldFragmentData.adjust_in_list(list, fragment, count)

func remove_from_list(list: Array[HeldFragmentData]) -> int:
	return HeldFragmentData.adjust_in_list(list, fragment, -count)

func to_fragment(): return fragment

func get_count() -> int: return count

func hidden() -> bool: return fragment.hidden
#endregion
