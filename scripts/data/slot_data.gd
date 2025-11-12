class_name SlotData
extends Resource

# Slot: 动词
#region 属性定义
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
#endregion

#region 公开方法
# 判断该 Slot 是否应该为某个 ActLogic 打开（Spawn 条件）
func opens(act_logic: ActLogic) -> bool:
	if spawn_tests.size() == 0 and spawn_rule == null:
		return true

	# 创建 Context（依赖 Context 的构造签名）
	var context = null
	if typeof(Context) == TYPE_NIL:
		# 如果项目没有全局 Context class_name，请按项目实现替换此处
		context = null
	else:
		# 期望 Context 可用 Context.new(act_logic)
		# 如果 Context 的构造器签名不同，请调整
		context = Context.new(act_logic)

	# 运行 spawn_tests（若 test.can_fail == false 且失败则阻止打开）
	for test in spawn_tests:
		if test == null:
			continue
		var r = test.attempt(context)
		if not test.can_fail and r == false:
			return false

	# 如果没有 spawn_rule，则通过
	if spawn_rule == null:
		return true
	else:
		# 与 C# 实现一致，评估规则前重置匹配（若实现存在）
		if context and context.has_method("reset_matches"):
			context.reset_matches()
		return spawn_rule.evaluate(context)

# 检查卡片是否满足片段相关的接受条件
func check_frag_rules(card_viz) -> bool:
	if card_viz == null:
		return false

	# essential: 必须对每个 essential 满足 count
	for frag_l in essential:
		if frag_l == null:
			continue
		var c = 0
		if card_viz.frag_tree and card_viz.frag_tree.has_method("count"):
			c = card_viz.frag_tree.count(frag_l)
		if c < int(frag_l.count):
			return false

	# forbidden: 对每个 forbidden 必须小于 count
	for frag_l in forbidden:
		if frag_l == null:
			continue
		var c = 0
		if card_viz.frag_tree and card_viz.frag_tree.has_method("count"):
			c = card_viz.frag_tree.count(frag_l)
		if c >= int(frag_l.count):
			return false

	# required: 如果存在任意一个 required 满足 count 则通过
	for frag_l in required:
		if frag_l == null:
			continue
		var c = 0
		if card_viz.frag_tree and card_viz.frag_tree.has_method("count"):
			c = card_viz.frag_tree.count(frag_l)
		if c >= int(frag_l.count):
			return true

	# 如果没有 required 条目则通过，否则未通过
	return required.empty()

# 判断 Slot 是否接受指定卡片（包含额外的 card_rule 检查）
func accepts_card(card_viz) -> bool:
	if accept_all:
		return true

	if card_viz != null and check_frag_rules(card_viz):
		if card_rule == null:
			return true
		# 使用卡片上下文评估规则（依赖 Context 构造）
		var context = null
		if typeof(Context) != TYPE_NIL:
			context = Context.new(card_viz)
		return card_rule.evaluate(context)

	return false

#endregion
