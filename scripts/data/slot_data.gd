class_name SlotData
extends Resource

# Slot: 动词

@export var label : String
@export_multiline var description : String
## 当Card插入Slot的时候，fragments会被添加到 Act window
@export var fragments : Array[FragmentData]

# ===============================
# Spawn : Slot 在 Token 和 Act 上生成的规则
# ===============================
@export_category("Spawn")
## 这个 Slot 只会尝试在与该字段引用的 Token 资源相同的 Token 实例/类型上打开（即“只在指定类型的 Token 上尝试生成/打开此槽”）
@export var token: TokenData
## 每个 window 只有一个此 Slot 的实例
@export var unique: bool = false
## 尝试在所有 Token 上生成 slot
@export var all_tokens: bool = false 
## 尝试在所有正在运行的 act 上生成 slot
@export var all_acts: bool = false

@export_category("Spawn Tests")
## 所有的 spawn_tests 必须通过，否则不生成当前 Slot
@export var spawn_tests: Array[TestData]
## spawn_rule 必须通过，否则不生成当前 Slot
@export var spawn_rule: RuleData

# ===============================
# Card 可插入 Slot 规则：1、相关 Fragment 数量限制；2、card_rule
# ===============================
@export_category("Accepted Fragments")
## Card 必须至少包含“required”列表中任一 Fragment，且该 Fragment 数量 >= 指定的 count，才能被该 Slot 接纳
@export var required: Array[HeldFragmentData]
## Card 必须对 essential 列表中的每个 Fragment，至少拥有指定数量，才会被该 Slot 接纳
@export var essential: Array[HeldFragmentData]
## Card 要被该 Slot 接纳，forbidden 列表中的每一项 Fragment 数量必须 < 指定的阈值
@export var forbidden: Array[HeldFragmentData]

@export_category("Card Rule")
## 额外 Card 可插入 Slot 规则，不会展示在UI中
@export var card_rule: RuleData

# ===============================
# Options
# ===============================
@export_category("Options")
## 允许在 Slot 中放所有的 Card
@export var accept_all: bool = false
## Card 不能从 Slot 中移除
@export var card_lock: bool = false
## Slot 会自动收集 Card，从全局桌面抓取
@export var grab_from_global: bool = false
## 从当前 Act 窗口内抓取卡片（只在本窗口的卡里寻找并插入槽）
@export var grab_from_window : bool = false
