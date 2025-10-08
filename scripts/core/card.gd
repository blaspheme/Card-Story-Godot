# Card - 实体卡牌类
class_name Card  
extends Fragment

@export_group("Decay - 衰变系统")
@export var decay_to: Card						# 衰变目标卡牌
@export var lifetime: float = 0.0				# 衰变时间
@export var on_decay_complete: Rule				# 衰变完成时执行的规则
@export var on_decay_into: Rule				# 被衰变为此卡时执行的规则

@export_group("Unique - 唯一性")
@export var unique: bool = false				# 全局唯一标识

func _init():
	super._init()

# 重写Fragment的抽象方法
func add_to_tree(fg: FragTree) -> void:
	if fg:
		fg.add_card(self)

func adjust_in_tree(fg: FragTree, level: int) -> int:
	if fg:
		return fg.adjust_card(self, level)
	return 0

func remove_from_tree(fg: FragTree) -> void:
	if fg:
		fg.remove_card(self)

func count_in_tree(fg: FragTree, only_free: bool = false) -> int:
	if fg:
		return fg.count_card(self, only_free)
	return 0

# 检查是否支持衰变
func can_decay() -> bool:
	return decay_to != null and lifetime > 0

# 开始衰变过程
func start_decay(context: Context) -> void:
	if can_decay() and context and context.act_logic:
		# 创建衰变定时器
		var timer = Timer.new()
		timer.wait_time = lifetime
		timer.one_shot = true
		timer.timeout.connect(_on_decay_timeout.bind(context))
		context.act_logic.add_child(timer)
		timer.start()
		
		print("开始衰变: ", get_display_name(), " -> ", decay_to.get_display_name(), " (", lifetime, "秒)")

func _on_decay_timeout(context: Context) -> void:
	print("衰变完成: ", get_display_name())
	
	# 执行衰变完成时的规则
	if on_decay_complete and context:
		on_decay_complete.execute(context)
	
	# 变形为目标卡牌 - 这里需要通过Modifier系统实现
	if decay_to and context:
		# 创建变形修改器
		var transform_modifier = CardModifier.new()
		transform_modifier.op = CardModifier.CardOp.TRANSFORM
		transform_modifier.target = self
		transform_modifier.fragment = decay_to
		transform_modifier.level = 1
		
		# 添加到context的修改器队列
		if context.card_modifiers:
			context.card_modifiers.append(transform_modifier.evaluate(context))

# 检查是否为唯一卡牌
func is_unique() -> bool:
	return unique

# 获取卡牌类型（从fragments中提取）
func get_card_types() -> Array[Fragment]:
	var types: Array[Fragment] = []
	for frag in fragments:
		if frag is Aspect:
			types.append(frag)
	return types

# 检查是否包含指定Aspect
func has_aspect(aspect: Aspect) -> bool:
	return aspect in fragments

# 获取特定Aspect的强度
func get_aspect_strength(aspect: Aspect) -> int:
	for frag in fragments:
		if frag == aspect:
			return 1  # 基础强度为1，如果需要更复杂的计算可以扩展
	return 0