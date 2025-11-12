class_name ActData
extends Resource

#region 属性定义
@export var label: String = ""
## 限制此 Act 只能在指定的 Token 类型上执行；对于 initial 与 spawned Acts 是必须设置的。
@export var token:  TokenData
## 是否为 Act 链中的第一个，可由玩家按钮触发启动
@export var initial: bool = false
## Act 的执行时间
@export var time: float = 0.0

# ===============================
# Entry Tests: Token 切换到这个 Act 的判断条件
# ===============================
@export_category("Entry Tests")
## 所有 tests 必须通过才能进入该 Act ； Card tests 匹配到的卡会作为 On Complete 的 modifiers 的匹配集。
@export var tests: Array[TestData]
## 所有的 and_rules 规则必须通过才能进入该 Act（不应用 modifiers，匹配卡不在规则间传递）
@export var and_rules: Array[RuleData]
## 任意一个 or_rules 规则通过则可以进入该 Act（不应用 modifiers，匹配卡不在规则间传递）
@export var or_rules: Array[RuleData]

# ===============================
# Act 执行成功之后效果
# ===============================
@export_category("Fragments")
## 在完成 Act 时会把这些 fragments 添加到 Act 的 FragTree（或窗口）
@export var fragments: Array[FragmentData]

@export_category("On Complete")
@export var act_modifiers: Array[ActModifier]
@export var card_modifiers: Array[CardModifier]
@export var table_modifiers: Array[TableModifier]
@export var path_modifiers: Array[PathModifier]
@export var deck_modifiers: Array[DeckModifier]

## 完成时额外运行的规则（matched cards 不在规则间传递）
@export var furthermore: Array[RuleData]

# ===============================
# 使用指定 Slots ，而不使用全局规则的 Slot
# ===============================
@export_category("Slots")
## 仅下列 slots 在 Act 运行时会尝试打开（如果 ignore_global_slots 为 true，则不会尝试全局 slots）
@export var ignore_global_slots: bool = false
@export var slots: Array[SlotData]

# ===============================
# Act链：动态变化、运行结束之后的后续Act
# ===============================
@export_category("Alt / Next / Spawned Acts")
@export var random_alt: bool = false
## 运行时的可选替代（选择替换当前 Act 的变体）
@export var alt_acts: Array[ActLink]
@export var random_next: bool = false
## 当前 Act 完成后顺序/候选的后续 Act 链
@export var next_acts: Array[ActLink]
## 在 Act 完成时会在桌面上生成（spawn）新的 Token 并把这些 Act 赋给新 Token 去运行
@export var spawned_acts: Array[ActLink]

# ===============================
# 生成时触发
# ===============================
@export_category("On Spawn")
## 在此 Act 在新 Token 中生成时会运行的规则
@export var on_spawn: RuleData

# ===============================
# Act 上的文本
# ===============================
@export_category("Texts")
@export_multiline var text: String
@export var text_rules: Array[RuleData]
@export_multiline var end_text: String
@export var end_text_rules: Array[RuleData]
#endregion
