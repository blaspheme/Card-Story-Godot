# HeldFragment - 带数量的Fragment容器
class_name HeldFragment
extends Resource

@export var fragment: Fragment					# 关联的Fragment
@export var count: int = 1						# 数量/强度

func _init(frag: Fragment = null, amount: int = 1):
	fragment = frag
	count = amount

# 核心操作方法 - 在列表中调整指定Fragment的数量
static func adjust_in_list(list: Array, fragment: Fragment, level: int) -> int:
	if not fragment:
		return 0
	
	# 查找已存在的HeldFragment
	for held_frag in list:
		if held_frag is HeldFragment and held_frag.fragment == fragment:
			held_frag.count += level
			
			# 如果数量降到0或以下，从列表中移除
			if held_frag.count <= 0:
				var final_count = held_frag.count
				list.erase(held_frag)
				return final_count
			
			return held_frag.count
	
	# 如果不存在且level为正数，创建新的HeldFragment
	if level > 0:
		var new_held = HeldFragment.new(fragment, level)
		list.append(new_held)
		return level
	
	return 0

# 添加到列表
func add_to_list(list: Array) -> int:
	return HeldFragment.adjust_in_list(list, fragment, count)

# 从列表中移除
func remove_from_list(list: Array) -> int:
	return HeldFragment.adjust_in_list(list, fragment, -count)

# 获取显示文本
func get_display_text() -> String:
	if fragment:
		var name = fragment.get_display_name()
		if count > 1:
			return name + " x" + str(count)
		else:
			return name
	return "空Fragment"

# 检查是否有效
func is_valid() -> bool:
	return fragment != null and count > 0
