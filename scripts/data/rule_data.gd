class_name RuleData
extends Resource

@export var invert : bool
## 所有 TestData 都必须通过
@export var tests : Array[TestData]
## 所有 RuleData 都必须通过
@export var and_tests : Array[RuleData]
## 任一 RuleData 通过
@export var or_tests : Array[RuleData]

@export_category("Modifiers")
@export var act_modifiers: Array[ActModifier]
@export var card_modifiers: Array[CardModifier]
@export var table_modifiers: Array[TableModifier]
@export var path_modifiers: Array[PathModifier]
@export var deck_modifiers: Array[DeckModifier]
@export_category("Furthermore")
@export var furthermore: Array[RuleData]

# ===============================
# Act 上的文本
# ===============================
@export_category("Texts")
@export_multiline var text: String
