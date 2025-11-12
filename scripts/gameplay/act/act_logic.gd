extends Node
class_name ActLogic

# ===============================
# Act 执行逻辑：管理 Act 链、Slot 开关、规则执行、结果处理
# ===============================

# 组件引用
@onready var frag_tree: FragTree = $"../Root"
@onready var act_window = $".." # ActWindow 是父节点

# 当前激活的 Act
var active_act: ActData = null
# 运行时替代的 Act（alt）
var alt_act: ActData = null

# Act 列表缓存
var alt_acts: Array[ActData] = []
var next_acts: Array[ActData] = []
var spawned_acts: Array[ActData] = []

# 强制执行/回调控制
var force_act: ActData = null
var callback_act: ActData = null
var do_callback: bool = false
var force_rule: RuleData = null

# 文本缓存
var end_text: TextData
var run_text: TextData 
var label: TextData

# 分支与调用栈
var branch_out_act: ActData = null
var call_stack: Array[ActData] = []

#region 属性访问器

var slots_frag_tree: FragTree:
	get: return act_window.slots_frag_tree if act_window else null

var token_viz: TokenViz:
	get: return act_window.token_viz if act_window else null

#endregion

#region 初始化
func _ready() -> void:
	# 组件已通过 @onready 获取
	if frag_tree:
		# 设置创建卡片回调
		frag_tree.on_create_card.connect(_on_create_card)

func _on_create_card(card_viz: CardViz) -> void:
	if act_window:
		card_viz.parent_to(act_window, true)
#endregion

#region Slot 检查与打开
## 返回应该打开的 Slot 列表
func check_for_slots() -> Array[SlotData]:
	var slots_to_attempt: Array[SlotData] = []
	var slots_to_open: Array[SlotData] = []
	
	if active_act != null:
		# 从当前 Act 获取 slots
		for slot in active_act.slots:
			if slot != null:
				slots_to_attempt.append(slot)
		
		# 如果不忽略全局 slots，添加全局 slots
		if not active_act.ignore_global_slots:
			for slot in Manager.GM.slot_sos:
				if slot != null and slot.all_acts:
					slots_to_attempt.append(slot)
	else:
		# 没有 active_act 时的逻辑
		if token_viz != null and token_viz.token != null and token_viz.token.slot != null:
			slots_to_open.append(token_viz.token_data.slot)
		
		# 从 cards 收集 slots
		for card_viz in frag_tree.cards():
			if card_viz.card != null:
				for slot in card_viz.card.slots:
					if slot != null:
						slots_to_attempt.append(slot)
		
		# 从 fragments 收集 slots
		for held_frag in frag_tree.fragments():
			if held_frag.fragment != null:
				for slot in held_frag.fragment.slots:
					if slot != null:
						slots_to_attempt.append(slot)
		
		# 全局 token 相关的 slots
		for slot in Manager.GM.slot_sos:
			if slot != null:
				if slot.all_tokens or (token_viz != null and slot.token == token_viz.token):
					slots_to_attempt.append(slot)
	
	# 检查每个 slot 是否能打开
	for slot in slots_to_attempt:
		if slot != null:
			# 如果 unique 为 false 或者还没在列表中
			if not slot.unique or not slots_to_open.has(slot):
				if slot.opens(self):
					slots_to_open.append(slot)
	
	return slots_to_open
#endregion

#region Act 执行流程
## 运行指定的 Act
func run_act(act: ActData) -> void:
	if act == null:
		return
	
	print("Running act: ", act.resource_path if act.resource_path else act.label)
	active_act = act
	force_act = null
	branch_out_act = null
	
	# 执行强制规则
	if force_rule != null:
		var context = Context.acquire_from_act_logic(self)
		force_rule.run(context)
		context.release()
		force_rule = null
	
	# 将 slot 中的卡移到窗口
	act_window.parent_slot_cards_to_window()
	
	# 更新状态和 slots
	act_window.apply_status(GameEnums.ActStatus.RUNNING)
	act_window.update_slots()
	
	# 填充 alt acts 列表
	populate_act_list(act.alt_acts, alt_acts, act.random_alt)
	attempt_alt_acts()
	
	# 检查是否需要计时
	if act.time > 0:
		token_viz.timer.start_timer(act.time, on_time_up)
		token_viz.show_timer()
		act_window.apply_status(GameEnums.ActStatus.RUNNING)
	else:
		setup_act_results()

## 计时器结束回调
func on_time_up() -> void:
	token_viz.show_timer(false)
	setup_act_results()

## 重置 ActLogic 状态
func reset() -> void:
	active_act = null
	alt_act = null
	end_text = null
	run_text = null
	label = null
	frag_tree.clear()
#endregion

#region Act 列表填充
## 根据 ActLink 列表填充目标 Act 数组
func populate_act_list(source: Array[ActLink], target: Array, random_order: bool = false) -> void:
	if source == null or target == null:
		return
	
	target.clear()
	
	# 特殊情况：单个无条件 ActLink
	if source.size() == 1 and source[0].chance == 0 and source[0].act_rule == null:
		target.append(source[0].act)
		return
	
	# 遍历所有 ActLink
	for act_link in source:
		if act_link == null:
			continue
		
		var passed = false
		
		if act_link.act_rule != null:
			# 使用规则判断
			var context = Context.acquire_from_act_logic(self)
			passed = act_link.act_rule.evaluate(context)
			context.release()
		else:
			# 使用概率判断
			var r = randi_range(0, 99)
			if r < act_link.chance:
				passed = true
		
		if passed:
			if not random_order:
				target.append(act_link.act)
			else:
				# 随机插入位置
				var i = randi_range(0, target.size())
				target.insert(i, act_link.act)
#endregion

#region Act 结果处理
## 设置 Act 执行结果
func setup_act_results() -> void:
	# 如果有替代 Act，切换到替代 Act
	if alt_act != null:
		print("Switched to: ", alt_act.resource_path if alt_act.resource_path else alt_act.label)
		active_act = alt_act
	
	# 将 slot 卡片移到窗口
	act_window.parent_slot_cards_to_window()
	
	# 添加 Act 的 fragments
	for frag in active_act.fragments:
		if frag != null:
			frag.add_to_tree(frag_tree)
	
	# 应用触发器
	apply_triggers()
	
	# 应用 Modifiers
	var context = Context.acquire_from_act_logic(self, true)
	active_act.apply_modifiers(context)
	context.release()
	
	# 生成新的 Acts
	populate_act_list(active_act.spawned_acts, spawned_acts)
	for spawned_act in spawned_acts:
		if spawned_act != null:
			Manager.GM.spawn_act(spawned_act, frag_tree, token_viz)
	
	# 获取结束文本
	var et = get_end_text(active_act)
	if et != "":
		end_text = et
	
	# 检查强制 Act
	if force_act != null:
		force_act_impl(force_act)
		return
	
	# 检查分支 Act
	if branch_out_act != null:
		var branch_context = Context.acquire_from_act_logic(self)
		if attempt_act(branch_out_act, branch_context):
			print("Branching out to act: ", branch_out_act.resource_path if branch_out_act.resource_path else branch_out_act.label)
			call_stack.append(active_act)
			branch_context.release()
			run_act(branch_out_act)
			return
		branch_context.release()
	
	# 检查回调
	if do_callback and callback_act != null:
		do_callback = false
		var callback_context = Context.acquire_from_act_logic(self)
		if attempt_act(callback_act, callback_context):
			callback_context.release()
			run_act(callback_act)
			return
		callback_context.release()
	
	# 尝试下一个 Act
	populate_act_list(active_act.next_acts, next_acts, active_act.random_next)
	
	var next_act = attempt_next_acts()
	# 如果没有找到，回溯调用栈
	while next_act == null and call_stack.size() > 0:
		var stack_act = call_stack[call_stack.size() - 1]
		call_stack.remove_at(call_stack.size() - 1)
		populate_act_list(stack_act.next_acts, next_acts, stack_act.random_next)
		next_act = attempt_next_acts()
	
	if next_act != null:
		run_act(next_act)
	else:
		setup_final_results()

## 设置最终结果（Act 链结束）
func setup_final_results() -> void:
	act_window.setup_result_cards(frag_tree.direct_cards())
	act_window.apply_status(GameEnums.ActStatus.FINISHED)
#endregion

#region Act 控制接口
## 强制执行指定 Act
func force_act_impl(act: ActData) -> void:
	var context = Context.acquire_from_act_logic(self)
	# 保存 matches
	attempt_act(act, context, true)
	context.release()
	run_act(act)

func set_callback(act: ActData) -> void:
	callback_act = act

func do_callback_func() -> void:
	do_callback = true

func set_force_act(act: ActData) -> void:
	force_act = act

func force_rule_func(rule: RuleData) -> void:
	force_rule = rule

func branch_out(act: ActData) -> void:
	if act != null:
		branch_out_act = act
#endregion

#region Act 尝试逻辑
## 尝试初始 Acts
func attempt_initial_acts() -> ActData:
	return attempt_acts(Manager.GM.initial_acts, true)

## 尝试替代 Acts
func attempt_alt_acts() -> ActData:
	alt_act = attempt_acts(alt_acts)
	update_text()
	return alt_act

## 尝试下一个 Acts
func attempt_next_acts() -> ActData:
	return attempt_acts(next_acts)

## 尝试单个 Act
func attempt_act(act: ActData, context, force: bool = false) -> bool:
	context.reset_matches()
	if act.attempt(context, force):
		context.save_matches()
		return true
	else:
		return false

## 尝试 Act 列表
func attempt_acts(acts: Array, match_token: bool = false) -> ActData:
	var context = Context.acquire_from_act_logic(self)
	for act in acts:
		if act != null:
			# 检查 token 匹配
			if match_token and token_viz != null and act.token != token_viz.token:
				continue
			
			if attempt_act(act, context):
				context.release()
				return act
	context.release()
	return null
#endregion

#region 触发器应用
## 注入触发器（外部调用）
func inject_triggers(target) -> void:
	if target == null:
		return
	
	var context = Context.acquire_from_act_logic(self)
	
	if target.fragment != null:
		apply_aspect_triggers(context, target.fragment)
	else:
		for card_viz in target.cards:
			apply_card_triggers(context, card_viz)
	
	context.release()

## 应用 Card 触发器
func apply_card_triggers(context, card_viz: CardViz) -> void:
	if card_viz == null:
		return
	
	context.this_card = card_viz
	context.this_aspect = card_viz.card
	
	for rule in card_viz.card.rules:
		if rule != null:
			rule.run(context)

## 应用 Aspect 触发器
func apply_aspect_triggers(context, fragment: FragmentData) -> void:
	if fragment == null:
		return
	
	context.this_aspect = fragment
	
	for rule in fragment.rules:
		if rule != null:
			rule.run(context)

## 应用所有触发器
func apply_triggers() -> void:
	var context = Context.acquire_from_act_logic(self)
	
	# 应用所有 Card 的触发器
	for card_viz in context.scope.cards():
		apply_card_triggers(context, card_viz)
	
	context.this_card = null
	
	# 应用所有 Fragment 的触发器
	for held_frag in context.scope.fragments():
		apply_aspect_triggers(context, held_frag.fragment)
	
	context.release()
#endregion

#region 文本处理
## 更新运行时文本
func update_text() -> void:
	var new_run_text = get_text(alt_act) if alt_act else get_text(active_act)
	var new_label = alt_act.label if alt_act else active_act.label
	
	if new_run_text != "":
		run_text = new_run_text
	if new_label != "":
		label = new_label

## 字符串插值
func interpolate_string(s: String) -> String:
	return frag_tree.interpolate_string(s) if frag_tree else s

## Token 描述
func token_description() -> String:
	if token_viz == null or token_viz.token == null:
		return ""
	return get_text_with_rules(token_viz.token.text_rules, token_viz.token.description)

## 获取 Act 文本
func get_text(act: ActData) -> String:
	if act == null:
		return ""
	return get_text_with_rules(act.text_rules, act.text)

## 获取 Act 结束文本
func get_end_text(act: ActData) -> String:
	if act == null:
		return ""
	return get_text_with_rules(act.end_text_rules, act.end_text)

## 根据规则获取文本
func get_text_with_rules(text_rules: Array, default_text: String) -> String:
	if text_rules != null and text_rules.size() > 0:
		var context = Context.acquire_from_act_logic(self)
		
		for rule in text_rules:
			if rule != null and rule.evaluate(context):
				var result = interpolate_string(rule.text)
				context.release()
				return result
		
		context.release()
	
	return interpolate_string(default_text)
#endregion

#region 保存/加载
## 保存状态
func save_state() -> Dictionary:
	return {
		"frag_save": frag_tree.save_state() if frag_tree else {},
		"active_act": active_act.resource_path if active_act else "",
		"callback_act": callback_act.resource_path if callback_act else "",
		"branch_out_act": branch_out_act.resource_path if branch_out_act else "",
		"call_stack": call_stack.map(func(act): return act.resource_path if act else ""),
		"alt_act": alt_act.resource_path if alt_act else "",
		"end_text": end_text,
		"run_text": run_text,
		"label": label
	}

## 加载状态
func load_state(save: Dictionary) -> void:
	if frag_tree and save.has("frag_save"):
		frag_tree.load_state(save.frag_save)
	
	active_act = load(save.active_act) if save.get("active_act", "") != "" else null
	callback_act = load(save.callback_act) if save.get("callback_act", "") != "" else null
	branch_out_act = load(save.branch_out_act) if save.get("branch_out_act", "") != "" else null
	
	call_stack.clear()
	if save.has("call_stack"):
		for path in save.call_stack:
			if path != "":
				call_stack.append(load(path))
	
	alt_act = load(save.alt_act) if save.get("alt_act", "") != "" else null
	
	if active_act != null:
		populate_act_list(active_act.alt_acts, alt_acts, active_act.random_alt)
	
	end_text = save.get("end_text", "")
	run_text = save.get("run_text", "")
	label = save.get("label", "")
#endregion
