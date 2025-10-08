# Rule - 游戏规则系统
class_name Rule
extends Resource

# 规则类型枚举
enum RuleType {
	ACTOR = 0,			# 条件满足时自动执行
	INDUCTION = 10,		# 玩家可以选择执行
}

# 条件检查类型枚举
enum CondOp {
	IF_NONE = 0,		# 如果没有满足条件的
	IF_SOME = 10,		# 如果存在满足条件的
	IF_ALL = 20,		# 如果所有都满足条件
}

@export var rule_type: RuleType = RuleType.ACTOR			# 规则类型
@export var label: String = ""								# 显示标签
@export var startingverb: String = ""						# 开始动词
@export var description: String = ""						# 描述文本
@export var verb: String = ""								# 动作动词
@export var preface: String = ""							# 前言
@export var icon: Texture2D									# 图标

# 条件相关
@export var requirements: Array[Test] = []					# 前置条件
@export_group("条件检查")
@export var cond_req: CondOp = CondOp.IF_SOME				# 条件操作类型
@export var cond_fragment: Fragment						# 条件Fragment
@export var cond_test: Test									# 条件测试

# 结果相关
@export_group("执行结果")
@export var resulting: Array[Fragment] = []				# 产生的Fragment
@export var extantreqs: Array[Test] = []					# 存在性测试
@export var burnimage: Texture2D							# 烧毁效果图

# Modifier相关
@export_group("修改器")
@export var effects: Array[ActModifier] = []				# 效果修改器
@export var linked: Array[Rule] = []						# 链接规则
@export var mutations: Array[CardModifier] = []			# 卡牌突变

# 热度和频率
@export_group("调控")
@export var warmth: int = 0									# 热度值
@export var heatcost: int = 1								# 消耗热度
@export var maxexecute: int = -1							# 最大执行次数(-1表示无限)

# 内部状态
var _execute_count: int = 0									# 执行计数

# 检查规则是否可以执行
func can_execute(context: Context) -> bool:
	if not context:
		return false
	
	# 检查执行次数限制
	if maxexecute >= 0 and _execute_count >= maxexecute:
		return false
	
	# 检查热度要求
	if context.get_warmth() < heatcost:
		return false
	
	# 检查前置条件
	if not check_requirements(context):
		return false
	
	# 检查条件Fragment
	if cond_fragment:
		if not check_condition_fragment(context):
			return false
	
	# 检查存在性测试
	if not check_extant_requirements(context):
		return false
	
	return true

# 执行规则
func execute(context: Context) -> bool:
	if not can_execute(context):
		return false
	
	print("执行规则: ", get_display_name())
	
	# 消耗热度
	context.spend_warmth(heatcost)
	
	# 增加执行计数
	_execute_count += 1
	
	# 执行效果修改器
	for effect in effects:
		if effect:
			var computed_effect = effect.evaluate(context)
			computed_effect.execute()
	
	# 执行卡牌突变
	for mutation in mutations:
		if mutation:
			var computed_mutation = mutation.evaluate(context)
			computed_mutation.execute()
	
	# 产生结果Fragment
	for fragment in resulting:
		if fragment:
			context.create_fragment(fragment)
	
	# 执行链接规则
	for linked_rule in linked:
		if linked_rule and linked_rule.can_execute(context):
			linked_rule.execute(context)
	
	return true

# 检查前置条件
func check_requirements(context: Context) -> bool:
	for req in requirements:
		if req and not req.test(context):
			return false
	return true

# 检查条件Fragment
func check_condition_fragment(context: Context) -> bool:
	if not cond_fragment:
		return true
	
	var count = context.count(cond_fragment, 0)
	
	match cond_req:
		CondOp.IF_NONE:
			return count == 0
		CondOp.IF_SOME:
			return count > 0
		CondOp.IF_ALL:
			# 这里需要根据具体游戏逻辑定义"全部"的含义
			return count > 0
		_:
			return true

# 检查存在性测试
func check_extant_requirements(context: Context) -> bool:
	for extant_req in extantreqs:
		if extant_req and not extant_req.test(context):
			return false
	return true

# 获取规则显示名称
func get_display_name() -> String:
	if label:
		return label
	return "Rule_" + str(get_instance_id())

# 获取规则描述
func get_full_description() -> String:
	var text = ""
	
	if startingverb:
		text += startingverb + " "
	
	if description:
		text += description
	
	if verb:
		text += "\n" + verb
	
	if preface:
		text += "\n" + preface
	
	return text

# 获取规则类型描述
func get_type_description() -> String:
	match rule_type:
		RuleType.ACTOR:
			return "自动执行"
		RuleType.INDUCTION:
			return "手动触发"
		_:
			return "未知类型"

# 获取条件操作描述
func get_condition_description() -> String:
	if not cond_fragment:
		return ""
	
	var desc = cond_fragment.get_display_name()
	
	match cond_req:
		CondOp.IF_NONE:
			desc = "没有" + desc
		CondOp.IF_SOME:
			desc = "存在" + desc
		CondOp.IF_ALL:
			desc = "所有" + desc
	
	return desc

# 验证规则配置是否有效
func is_valid() -> bool:
	# 规则必须有某种形式的条件或结果
	var has_condition = not requirements.is_empty() or cond_fragment != null or not extantreqs.is_empty()
	var has_result = not resulting.is_empty() or not effects.is_empty() or not mutations.is_empty() or not linked.is_empty()
	
	return has_condition or has_result

# 重置执行计数（用于新回合或重新开始）
func reset_execution_count() -> void:
	_execute_count = 0