# Aspect - 属性标签类
class_name Aspect
extends Fragment

func _init():
	super._init()

# 重写Fragment的抽象方法
func add_to_tree(fg: FragTree) -> void:
	if fg:
		fg.add_aspect(self)

func adjust_in_tree(fg: FragTree, level: int) -> int:
	if fg:
		return fg.adjust_aspect(self, level)
	return 0

func remove_from_tree(fg: FragTree) -> void:
	if fg:
		fg.remove_aspect(self)

func count_in_tree(fg: FragTree, only_free: bool = false) -> int:
	if fg:
		return fg.count_aspect(self, only_free)
	return 0

# Aspect特有的列表操作
func adjust_in_list(list: Array, level: int) -> int:
	return HeldFragment.adjust_in_list(list, self, level)

# 检查是否为特定类型的Aspect
func is_type(aspect_type: String) -> bool:
	return label.contains(aspect_type)

# 获取Aspect的强度值
func get_strength_in_list(list: Array) -> int:
	for held in list:
		if held is HeldFragment and held.fragment == self:
			return held.count
	return 0