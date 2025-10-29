class_name TokenData
extends Resource

@export var label : String
@export var image : Texture2D
## 没有设置 image 时候的颜色
@export var color : Color = Color.WHITE

@export_category("Description")
@export_multiline var description : String
@export var text_rules : Array[RuleData]

@export_category("Slot")
## 当没有运行的 Act 的时候，第一个打开的 Slot
@export var slot : SlotData

@export_category("Options")
## 在最后一个 act 执行完之后 Destroy
@export var dissolve : bool = false
## 游戏运行时只能存在一个的实例
@export var unique : bool = false
