extends Resource
class_name ActLink

## chance: 尝试此 Act 的百分比概率（0-100）。当候选列表仅含一个元素且其 chance==0 时，视为 100%
@export_range(0, 100) var chance: int = 0
@export var act: ActData
## act_rule: 可选规则资源；若设置此规则则优先使用规则判断（通过则尝试），并忽略 chance 字段
@export var act_rule: RuleData
