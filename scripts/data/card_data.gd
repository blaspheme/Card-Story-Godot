class_name CardData
extends FragmentData

#region 属性定义
@export_category("Decay(转换)")
## 当该卡被创建时，它会自动衰变为指定的卡
@export var decay_to : CardData
## 衰变完成需要多长时间
@export var lifetime : float
## 当衰变完成时将运行此规则
@export var on_decay_complete : RuleData
## 当其他卡衰变并变为此卡时将运行此规则
@export var on_decay_into : RuleData

@export_category("Unique")
## 游戏运行时只能存在一张这个卡的实例
@export var unique : bool = false

@export_category("Memory")
@export var memory_from_first : bool = false
#endregion
