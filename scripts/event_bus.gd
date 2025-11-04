extends Node

# 全局事件总线

# 内部订阅项结构体（使用 Dictionary）
# { id: int, callable: Callable, priority: int, once: bool }

# 事件到订阅数组的映射（精确事件名）
var _handlers: Dictionary = {}

# 模式订阅：使用 PatternHandler 封装，便于类型检查与保留原始 pattern 文本
class PatternHandler:
	var id: int
	var pattern: String
	var regex: RegEx
	var callable: Callable
	var priority: int
	var once: bool

	func _init(pid: int, pat: String, rx: RegEx, cb: Callable, prio: int, oonce: bool) -> void:
		self.id = pid
		self.pattern = pat
		self.regex = rx
		self.callable = cb
		self.priority = prio
		self.once = oonce

var _pattern_handlers: Array = [] # Array of PatternHandler

# 异步队列：用于存放延迟到下一帧处理的事件，方便在保存前 flush
var _deferred_queue: Array = []

# 暂停控制
var _paused_events: Dictionary = {}
var _global_paused: bool = false

# 用于分配唯一订阅 id
var _next_id: int = 1

# 调试信号（可选）：每次事件触发时发出，便于工具或测试监听
signal debug_event_emitted(event_name: String, args)

func _ready() -> void:
	# 此节点设计为 Autoload 单例使用；无需强制断言，但建议在项目中注册
	pass

# 订阅精确事件
func subscribe(event_name: String, handler: Callable, priority: int = 0) -> int:
	var id = _next_id
	_next_id += 1
	var list: Array = _handlers.get(event_name, [])
	list.append({
		"id": id,
		"callable": handler,
		"priority": priority,
		"once": false
	})
	# 按优先级降序排序（高优先级先执行）
	list.sort_custom(_sort_by_priority_desc)
	_handlers[event_name] = list
	return id

# 订阅一次性事件
func subscribe_once(event_name: String, handler: Callable, priority: int = 0) -> int:
	var id = _next_id
	_next_id += 1
	var list: Array = _handlers.get(event_name, [])
	list.append({
		"id": id,
		"callable": handler,
		"priority": priority,
		"once": true
	})
	list.sort_custom(_sort_by_priority_desc)
	_handlers[event_name] = list
	return id

# 订阅正则模式，事件名匹配时会触发
func subscribe_pattern(pattern: String, handler: Callable, priority: int = 0, once: bool = false) -> int:
	var regex := RegEx.new()
	var err = regex.compile(pattern)
	# 编译失败时抛出，尽早发现 pattern 问题
	assert(err == OK)
	var id = _next_id
	_next_id += 1
	_pattern_handlers.append(PatternHandler.new(id, pattern, regex, handler, priority, once))
	# 为后续分发效率，可在发射时再次合并排序
	return id

# 取消订阅：支持通过事件名+Callable 或 仅事件名+id 来取消
func unsubscribe(event_name: String, handler_or_id) -> bool:
	var list: Array = _handlers.get(event_name, [])
	if list.size() == 0:
		return false
	var removed := false
	# 支持传入整数 id
	if typeof(handler_or_id) == TYPE_INT:
		var id_to_remove: int = handler_or_id
		for i in range(list.size() - 1, -1, -1):
			if list[i]["id"] == id_to_remove:
				list.remove_at(i)
				removed = true
	else:
		# 假定传入的是 Callable
		for i in range(list.size() - 1, -1, -1):
			if list[i]["callable"] == handler_or_id:
				list.remove_at(i)
				removed = true
	if list.size() == 0:
		_handlers.erase(event_name)
	else:
		_handlers[event_name] = list
	return removed

# 取消基于 id 的 pattern 订阅
func unsubscribe_pattern_by_id(id: int) -> bool:
	for i in range(_pattern_handlers.size() - 1, -1, -1):
		if _pattern_handlers[i].id == id:
			_pattern_handlers.remove_at(i)
			return true
	return false

# 内部排序回调：按 priority 降序
func _sort_by_priority_desc(a: Dictionary, b: Dictionary) -> int:
	# 返回 -1 表示 a 在 b 之前
	if a["priority"] > b["priority"]:
		return -1
	if a["priority"] < b["priority"]:
		return 1
	return 0

# 触发事件（同步调用）
func emit(event_name: String, args := []) -> void:
	# 全局或事件暂停时直接返回（不触发）
	if _global_paused:
		return
	if _paused_events.get(event_name, false):
		return
	# 收集所有匹配的 handlers（精确 + 模式）
	var to_call: Array = []
	if _handlers.has(event_name):
		# 浅拷贝，避免回调中修改原数组导致迭代异常
		to_call += _handlers[event_name].duplicate(true)
	# 模式订阅：遍历所有，匹配则加入
	# 模式订阅：遍历所有，匹配则加入
	for i in range(_pattern_handlers.size()):
		var ph: PatternHandler = _pattern_handlers[i]
		if ph.regex.search(event_name) != null:
			# 适配 to_call 项为 Dictionary 结构（与精确订阅统一）
			to_call.append({
				"id": ph.id,
				"callable": ph.callable,
				"priority": ph.priority,
				"once": ph.once,
				"_pattern_ref": ph
			})
	# 如果没有任何订阅则直接返回
	if to_call.size() == 0:
		return
	# 合并并按优先级排序
	to_call.sort_custom(_sort_by_priority_desc)
	# 发出调试信号
	emit_signal("debug_event_emitted", event_name, args)
	# 执行所有回调（使用浅拷贝以免回调中修改）
	var called_ids: Array = []
	for item in to_call:
		# item 可能来自精确表也可能来自 pattern 表
		var cb: Callable = item["callable"]
		# 调用用户回调
		# 使用 callv 以支持可变参数数组
		cb.callv(args)
		# 如果是一次性订阅，记录 id 以便稍后移除
		if item.get("once", false):
			called_ids.append(item["id"])
	# 清理 once 订阅（先处理精确事件）
	if called_ids.size() > 0:
		if _handlers.has(event_name):
			var remaining := []
			for entry in _handlers[event_name]:
				if entry["id"] in called_ids:
					continue
				remaining.append(entry)
			if remaining.size() == 0:
				_handlers.erase(event_name)
			else:
				_handlers[event_name] = remaining
		# pattern 订阅也可能含有 once
		for rid in called_ids:
			_unsubscribe_pattern_id_if_once(rid)

# 异步触发（延迟到下一个空闲帧）
func emit_async(event_name: String, args := []) -> void:
	# 将事件加入内部队列，下一帧处理；便于在保存前 flush
	_deferred_queue.append({"event": event_name, "args": args})
	# 确保下一帧会处理队列
	call_deferred("_process_deferred")

func _process_deferred() -> void:
	# 使用快照处理，允许回调中产生新事件（新事件会加入队列并在后续循环中处理）
	if _deferred_queue.size() == 0:
		return
	var q := _deferred_queue.duplicate(true)
	_deferred_queue.clear()
	for item in q:
		_deferred_emit(item["event"], item["args"])

func _deferred_emit(event_name: String, args):
	emit(event_name, args)

# 保存前强制立即处理所有待处理异步事件（调用此函数以保证模型一致性）
func flush_deferred() -> void:
	# 立即同步处理队列内所有事件
	while _deferred_queue.size() > 0:
		var item = _deferred_queue.pop_front()
		_deferred_emit(item["event"], item["args"])

# （旧实现已被新的队列实现替换，已删除重复定义）

# 清除事件的所有订阅；如果 event_name 为 null 则清空全部
func clear(event_name: String = "") -> void:
	if event_name == "":
		_handlers.clear()
		_pattern_handlers.clear()
		_paused_events.clear()
		_global_paused = false
	else:
		_handlers.erase(event_name)
		# 也从 pattern 中移除匹配该文字的（仅当 pattern 等于该文字时）
		for i in range(_pattern_handlers.size() - 1, -1, -1):
			var ph: PatternHandler = _pattern_handlers[i]
			# 如果 pattern 原始文本等于传入值，则移除
			if ph.pattern == event_name:
				_pattern_handlers.remove_at(i)

# 暂停/恢复单个事件或全部事件
func pause_event(event_name: String) -> void:
	_paused_events[event_name] = true

func resume_event(event_name: String) -> void:
	_paused_events.erase(event_name)

func pause_all() -> void:
	_global_paused = true

func resume_all() -> void:
	_global_paused = false

# 查询接口
func has_subscribers(event_name: String) -> bool:
	if _handlers.has(event_name) and not _handlers[event_name].empty():
		return true
	for ph in _pattern_handlers:
		# pattern 订阅由于不针对单一事件，不能直接判断是否匹配；此接口仅判断是否存在 pattern 订阅
		if ph != null:
			return true
	return false

func get_subscriber_count(event_name: String) -> int:
	var cnt := 0
	if _handlers.has(event_name):
		cnt += _handlers[event_name].size()
	# 计算匹配的 pattern handlers
	for ph in _pattern_handlers:
		if ph.regex.search(event_name) != null:
			cnt += 1
	return cnt

# 内部辅助：如果 pattern 订阅 id 对应的是 once，则移除
func _unsubscribe_pattern_id_if_once(id: int) -> void:
	for i in range(_pattern_handlers.size() - 1, -1, -1):
		if _pattern_handlers[i].id == id:
			_pattern_handlers.remove_at(i)
			return

# 允许外部通过 id 直接移除任意订阅（会查找精确与 pattern）
func unsubscribe_by_id(id: int) -> bool:
	# 精确表
	for key in _handlers.keys():
		var list: Array = _handlers[key]
		for i in range(list.size() - 1, -1, -1):
			if list[i]["id"] == id:
				list.remove_at(i)
		if list.size() == 0:
			_handlers.erase(key)
		else:
			_handlers[key] = list
	# pattern 表
	return unsubscribe_pattern_by_id(id)
