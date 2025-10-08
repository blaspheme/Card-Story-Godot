# Test - 条件测试类
class_name Test
extends Resource

# 操作符枚举
enum ReqOp {
	MORE_OR_EQUAL = 0,	# 大于等于 >=
	EQUAL = 1,			# 等于 ==  
	LESS_OR_EQUAL = 2,	# 小于等于 <=
	MORE = 3,			# 大于 >
	NOT_EQUAL = 4,		# 不等于 !=
	LESS = 5,			# 小于 <
	RANDOM_CHALLENGE = 10, # 随机挑战
	RANDOM_CLASH = 20	# 随机冲突
}

# 位置类型（支持位运算组合）
enum ReqLoc {
	SCOPE = 0,			# 当前作用域
	MATCHED_CARDS = 32,	# 匹配的卡牌 (1 << 5)
	SLOTS = 4,			# 插槽区域 (1 << 2)
	TABLE = 16,			# 桌面区域 (1 << 4)
	HEAP = 8,			# 堆叠区域 (1 << 3)
	FREE = 128,			# 可用区域 (1 << 7)
	ANYWHERE = 64,		# 任意位置 (1 << 6)
}

@export var card_test: bool = false				# 是否为卡牌相关测试
@export var can_fail: bool = false				# 是否允许失败（柔性条件）

# 左操作数
@export var loc1: ReqLoc						# 第一个位置
@export var fragment1: Fragment					# 第一个Fragment

# 操作符
@export var op: ReqOp							# 判定操作符

# 右操作数
@export var constant: int						# 常数值或乘数
@export var loc2: ReqLoc						# 第二个位置
@export var fragment2: Fragment					# 第二个Fragment

# 核心方法
func attempt(context: Context) -> bool:
	if not context:
		print("错误: Test.attempt() - context为空")
		return false
	
	var left_count = get_count(context, loc1, fragment1)
	var right_count = constant
	
	if fragment2:
		right_count = constant * get_count(context, loc2, fragment2)
	
	var result = compare_values(left_count, right_count, op)
	
	# 调试输出
	if fragment1:
		print("测试: ", fragment1.get_display_name(), "(", left_count, ") ", get_op_string(op), " ", right_count, " = ", result)
	
	# 如果是卡牌测试，需要匹配符合条件的卡牌
	if card_test and result and fragment1:
		match_cards(context)
	
	return result

func get_count(context: Context, loc: ReqLoc, fragment: Fragment) -> int:
	if not fragment or not context:
		return 0
		
	var scope = context.resolve_scope(loc)
	if scope:
		return fragment.count_in_tree(scope)
	return 0

func compare_values(left: int, right: int, operator: ReqOp) -> bool:
	match operator:
		ReqOp.MORE_OR_EQUAL:
			return left >= right
		ReqOp.EQUAL:
			return left == right
		ReqOp.LESS_OR_EQUAL:
			return left <= right
		ReqOp.MORE:
			return left > right
		ReqOp.NOT_EQUAL:
			return left != right
		ReqOp.LESS:
			return left < right
		ReqOp.RANDOM_CHALLENGE:
			return randf() < (float(left) / max(right, 1))
		ReqOp.RANDOM_CLASH:
			return randi() % max(left + right, 1) < left
		_:
			return false

func match_cards(context: Context) -> void:
	if not context or not fragment1:
		return
		
	# 匹配符合条件的卡牌到context.matches
	var scope = context.resolve_scope(loc1)
	if scope:
		var cards = scope.get_cards_with_fragment(fragment1)
		context.matches.append_array(cards)

# 获取操作符的字符串表示（用于调试）
func get_op_string(operator: ReqOp) -> String:
	match operator:
		ReqOp.MORE_OR_EQUAL:
			return ">="
		ReqOp.EQUAL:
			return "=="
		ReqOp.LESS_OR_EQUAL:
			return "<="
		ReqOp.MORE:
			return ">"
		ReqOp.NOT_EQUAL:
			return "!="
		ReqOp.LESS:
			return "<"
		ReqOp.RANDOM_CHALLENGE:
			return "随机挑战"
		ReqOp.RANDOM_CLASH:
			return "随机冲突"
		_:
			return "未知"

# 获取位置类型的字符串表示
func get_loc_string(location: ReqLoc) -> String:
	match location:
		ReqLoc.SCOPE:
			return "作用域"
		ReqLoc.MATCHED_CARDS:
			return "匹配卡牌"
		ReqLoc.SLOTS:
			return "插槽区域"
		ReqLoc.TABLE:
			return "桌面区域"
		ReqLoc.HEAP:
			return "堆叠区域"
		ReqLoc.FREE:
			return "可用区域"
		ReqLoc.ANYWHERE:
			return "任意位置"
		_:
			return "未知位置"

# 验证Test配置是否有效
func is_valid() -> bool:
	if not fragment1:
		return false
	
	# 如果设置了fragment2但constant为0，可能有问题
	if fragment2 and constant == 0:
		print("警告: Test设置了fragment2但constant为0")
	
	return true
