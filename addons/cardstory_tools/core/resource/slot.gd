# Slot - 卡槽系统
class_name Slot
extends Resource

# 槽位类型枚举
enum SlotType {
	NORMAL = 0,			# 普通槽位
	LOCKED = 10,		# 锁定槽位
	SPECIAL = 20,		# 特殊槽位
	TEMPORARY = 30,		# 临时槽位
}

# 槽位状态枚举
enum SlotState {
	EMPTY = 0,			# 空槽
	OCCUPIED = 10,		# 已占用
	RESERVED = 20,		# 已预留
	DISABLED = 30,		# 已禁用
}

@export var slot_type: SlotType = SlotType.NORMAL		# 槽位类型
@export var label: String = ""							# 显示标签
@export var description: String = ""					# 描述文本
@export var icon: Texture2D								# 槽位图标

# 容量相关
@export_group("容量")
@export var max_capacity: int = 1						# 最大容量
@export var allow_stacking: bool = false				# 是否允许堆叠
@export var stack_limit: int = 1						# 堆叠上限

# 限制条件
@export_group("限制条件")
@export var allowed_fragments: Array[Fragment] = []	# 允许的Fragment类型
@export var forbidden_fragments: Array[Fragment] = []	# 禁止的Fragment类型
@export var required_aspects: Array[Aspect] = []		# 需要的Aspect
@export var access_requirements: Array[Test] = []		# 访问条件

# 效果相关
@export_group("效果")
@export var on_enter_effects: Array[ActModifier] = []	# 放入时效果
@export var on_exit_effects: Array[ActModifier] = []	# 取出时效果
@export var passive_effects: Array[ActModifier] = []	# 持续效果
@export var linked_slots: Array[Slot] = []				# 链接槽位

# 内部状态
var _state: SlotState = SlotState.EMPTY					# 当前状态
var _contents: Array[Fragment] = []						# 槽位内容
var _reserved_for: Fragment								# 预留给特定Fragment
var _context: Context									# 当前上下文

# 检查是否可以放置Fragment
func can_place(fragment: Fragment, context: Context = null) -> bool:
	if not fragment:
		return false
	
	# 检查槽位状态
	if _state == SlotState.DISABLED:
		return false
	
	if _state == SlotState.RESERVED and _reserved_for != fragment:
		return false
	
	# 检查容量限制
	if not allow_stacking and not _contents.is_empty():
		return false
	
	if _contents.size() >= max_capacity:
		return false
	
	# 检查堆叠限制
	if allow_stacking:
		var same_fragment_count = _contents.count(fragment)
		if same_fragment_count >= stack_limit:
			return false
	
	# 检查Fragment类型限制
	if not allowed_fragments.is_empty():
		if fragment not in allowed_fragments:
			return false
	
	if fragment in forbidden_fragments:
		return false
	
	# 检查Aspect要求
	if fragment is Card:
		var card = fragment as Card
		for required_aspect in required_aspects:
			if not card.has_aspect(required_aspect):
				return false
	
	# 检查访问条件
	if context:
		for requirement in access_requirements:
			if requirement and not requirement.test(context):
				return false
	
	return true

# 放置Fragment到槽位
func place(fragment: Fragment, context: Context = null) -> bool:
	if not can_place(fragment, context):
		return false
	
	_contents.append(fragment)
	_state = SlotState.OCCUPIED
	_context = context
	
	# 触发放入效果
	if context:
		for effect in on_enter_effects:
			if effect:
				var computed_effect = effect.evaluate(context)
				computed_effect.execute()
	
	print("放置Fragment到槽位: ", fragment.get_display_name(), " -> ", get_display_name())
	EventBus.emit_signal("slot_fragment_placed", self, fragment)
	
	return true

# 从槽位取出Fragment
func remove(fragment: Fragment, context: Context = null) -> bool:
	if fragment not in _contents:
		return false
	
	_contents.erase(fragment)
	
	# 更新状态
	if _contents.is_empty():
		_state = SlotState.EMPTY
		_reserved_for = null
	
	# 触发取出效果
	if context:
		for effect in on_exit_effects:
			if effect:
				var computed_effect = effect.evaluate(context)
				computed_effect.execute()
	
	print("从槽位取出Fragment: ", fragment.get_display_name(), " <- ", get_display_name())
	EventBus.emit_signal("slot_fragment_removed", self, fragment)
	
	return true

# 清空槽位
func clear(context: Context = null) -> Array[Fragment]:
	var removed_fragments = _contents.duplicate()
	
	# 为每个Fragment触发取出效果
	if context:
		for fragment in _contents:
			for effect in on_exit_effects:
				if effect:
					var computed_effect = effect.evaluate(context)
					computed_effect.execute()
	
	_contents.clear()
	_state = SlotState.EMPTY
	_reserved_for = null
	
	EventBus.emit_signal("slot_cleared", self, removed_fragments)
	return removed_fragments

# 预留槽位给特定Fragment
func reserve(fragment: Fragment) -> bool:
	if _state != SlotState.EMPTY:
		return false
	
	_reserved_for = fragment
	_state = SlotState.RESERVED
	
	EventBus.emit_signal("slot_reserved", self, fragment)
	return true

# 取消预留
func unreserve() -> void:
	if _state == SlotState.RESERVED:
		_reserved_for = null
		_state = SlotState.EMPTY
		EventBus.emit_signal("slot_unreserved", self)

# 设置槽位状态
func set_state(new_state: SlotState) -> void:
	var old_state = _state
	_state = new_state
	
	if new_state == SlotState.EMPTY:
		_reserved_for = null
	
	EventBus.emit_signal("slot_state_changed", self, old_state, new_state)

# 获取槽位内容
func get_contents() -> Array[Fragment]:
	return _contents.duplicate()

func get_first_content() -> Fragment:
	if _contents.is_empty():
		return null
	return _contents[0]

func get_content_count() -> int:
	return _contents.size()

func has_content(fragment: Fragment) -> bool:
	return fragment in _contents

# 状态查询
func is_empty() -> bool:
	return _contents.is_empty()

func is_full() -> bool:
	return _contents.size() >= max_capacity

func is_available() -> bool:
	return _state == SlotState.EMPTY or (_state == SlotState.OCCUPIED and allow_stacking and not is_full())

func is_reserved_for(fragment: Fragment) -> bool:
	return _state == SlotState.RESERVED and _reserved_for == fragment

# 持续效果处理
func apply_passive_effects(context: Context) -> void:
	if _contents.is_empty() or not context:
		return
	
	for effect in passive_effects:
		if effect:
			var computed_effect = effect.evaluate(context)
			computed_effect.execute()

# 获取显示信息
func get_display_name() -> String:
	if label:
		return label
	return "Slot_" + str(get_instance_id())

func get_state_description() -> String:
	match _state:
		SlotState.EMPTY:
			return "空槽"
		SlotState.OCCUPIED:
			return "已占用(" + str(_contents.size()) + "/" + str(max_capacity) + ")"
		SlotState.RESERVED:
			return "已预留给" + (_reserved_for.get_display_name() if _reserved_for else "未知")
		SlotState.DISABLED:
			return "已禁用"
		_:
			return "未知状态"

func get_type_description() -> String:
	match slot_type:
		SlotType.NORMAL:
			return "普通槽位"
		SlotType.LOCKED:
			return "锁定槽位"
		SlotType.SPECIAL:
			return "特殊槽位"
		SlotType.TEMPORARY:
			return "临时槽位"
		_:
			return "未知类型"

# 获取内容描述
func get_contents_description() -> String:
	if _contents.is_empty():
		return "空"
	
	var descriptions = []
	for fragment in _contents:
		descriptions.append(fragment.get_display_name())
	
	return " | ".join(descriptions)

# 验证槽位配置
func is_valid() -> bool:
	return max_capacity > 0 and stack_limit > 0

# 调试信息
func get_debug_info() -> Dictionary:
	return {
		"label": label,
		"type": get_type_description(),
		"state": get_state_description(),
		"contents": get_contents_description(),
		"capacity": str(_contents.size()) + "/" + str(max_capacity),
		"stacking": allow_stacking,
		"restrictions": {
			"allowed_fragments": allowed_fragments.size(),
			"forbidden_fragments": forbidden_fragments.size(),
			"required_aspects": required_aspects.size(),
			"access_requirements": access_requirements.size()
		}
	}
