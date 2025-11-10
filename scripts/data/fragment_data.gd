class_name FragmentData
extends Resource

#region 属性定义
@export var label : TextData
@export var image : Texture2D
## 没有设置 image 时候的颜色
@export var color : Color = Color.WHITE
## 界面中不显示
@export var hidden : bool = false
@export var description : TextData

@export_category("Fragments")
@export var fragments: Array[FragmentData]

@export_category("Triggers")
## 触发器：当 Act 完成且该 Fragment 在 FragTree 中存在时会运行的规则列表
@export var rules: Array[RuleData]

@export_category("Slots")
## 与 Slot 的关联：当该 Fragment 在 FragTree 中存在时这些 Slot 会尝试打开
@export var slots: Array[SlotData]

@export_category("Deck")
## 可选关联牌堆（例如卡关联的 Deck）
@export var deck: DeckData
#endregion

#region 公开方法
## 在 FragTree 中“加入”时调用
@warning_ignore("unused_parameter")
func add_to_tree(fg: FragTree) -> void:
	# override in subclasses
	pass

# 从 FragTree 中移除时调用
@warning_ignore("unused_parameter")
func remove_from_tree(fg: FragTree) -> void:
	# override in subclasses
	pass

# 在树中按数量调整（+/- level），返回实际变化量（int）
@warning_ignore("unused_parameter")
func adjust_in_tree(fg: FragTree, level: int) -> int:
	# override in subclasses
	return 0

# 在树中统计该 fragment 的数量，only_free 对应只统计 free 的分支
@warning_ignore("unused_parameter")
func count_in_tree(fg: FragTree, only_free: bool=false) -> int:
	# override in subclasses
	return 0

# 返回表示此项的 Fragment（在 Unity 中是引用自身）
func to_fragment():
	return self

# 单位计数（默认 1）
func count() -> int:
	return 1
#endregion
