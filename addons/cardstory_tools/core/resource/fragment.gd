# Fragment基础类 - 所有游戏元素的基类
class_name Fragment
extends Resource

@export var label: String = ""					# 唯一标识符
@export var art: Texture2D						# 显示图像
@export var color: Color = Color.WHITE			# 备用颜色
@export var hidden: bool = false				# 是否在UI中隐藏
@export_multiline var description: String = ""	# 描述文本

# 组合系统
@export var fragments: Array[Fragment] = []		# 子Fragment列表

# 触发器系统
@export var rules: Array[Rule] = []				# Fragment存在时执行的规则

# 插槽系统  
@export var slots: Array[Slot] = []				# Fragment存在时尝试打开的插槽

# 牌堆关联
@export var deck: Deck							# 关联的牌堆

func _init():
	pass


# 虚拟方法（由子类实现）
func add_to_tree(fg: FragTree) -> void:
	pass

func remove_from_tree(fg: FragTree) -> void:
	pass
	
func adjust_in_tree(fg: FragTree, level: int) -> int:
	return 0
	
func count_in_tree(fg: FragTree, only_free: bool = false) -> int:
	return 0

# 获取显示名称（支持本地化）
func get_display_name() -> String:
	return tr(label) if label else "未命名Fragment"

# 获取显示图像
func get_display_texture() -> Texture2D:
	return art

# 获取显示颜色
func get_display_color() -> Color:
	return color if art == null else Color.WHITE

# 检查是否包含指定Fragment
func contains_fragment(target: Fragment) -> bool:
	for frag in fragments:
		if frag == target or frag.contains_fragment(target):
			return true
	return false

# 获取所有子Fragment（递归）
func get_all_fragments() -> Array[Fragment]:
	var result: Array[Fragment] = []
	result.append_array(fragments)
	
	for frag in fragments:
		result.append_array(frag.get_all_fragments())
	
	return result

# 检查Fragment是否有效
func is_valid() -> bool:
	return not label.is_empty()
