class_name FragmentData
extends Resource

# ===============================
# 属性定义
# ===============================
@export var label : String
@export var image : Texture2D
## 没有设置 image 时候的颜色
@export var color : Color = Color.WHITE
## 界面中不显示
@export var hidden : bool = false
@export_multiline var description : String

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

# ===============================
# 公开方法
# ===============================
