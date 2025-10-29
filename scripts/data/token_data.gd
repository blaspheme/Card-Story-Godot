class_name TokenData
extends Resource

@export var label : String
@export var image : Texture2D
## 没有设置 image 时候的颜色
@export var color : Color = Color.WHITE
@export_multiline var description : String
@export var text_rules : Array[RuleData]
@export var slot : SlotData
## 在最后一个 act 执行完之后 Destroy
@export var dissolve : bool = false
## 游戏运行时只能存在一个的实例
@export var unique : bool = false
