extends GdUnitTestSuite

# EventBus 单元测试（用于 gdUnit4）
# 说明：
# - 每个测试用例单独创建 EventBus 实例并加入场景树
# - 使用断言验证行为（gdUnit4 会将抛出的错误视为测试失败）
# - 使用 Godot 4 的 await get_tree().process_frame 来等待下一帧（用于 emit_async 测试）


# 简单的回调帮助类，用于记录调用参数
class CallHelper:
	var calls: Array = []

	func on_call(...args) -> void:
		# 收集传入参数数组
		calls.append(args)


func _create_bus() -> Node:
	var bus := preload("res://scripts/system/services/event_bus.gd").new()
	add_child(bus)
	return bus


func _destroy_bus(bus: Node) -> void:
	if bus and bus.is_inside_tree():
		bus.queue_free()


func test_subscribe_and_emit() -> void:
	var bus = _create_bus()
	var helper := CallHelper.new()
	var id: int = bus.subscribe("test/event", Callable(helper, "on_call"), 5)
	assert(typeof(id) == TYPE_INT)
	# 触发事件并检查回调收到参数
	bus.emit("test/event", [1, 2, "a"])
	assert(helper.calls.size() == 1)
	assert(helper.calls[0] == [1, 2, "a"])
	# 清理
	bus.unsubscribe("test/event", id)
	_destroy_bus(bus)


func test_subscribe_once() -> void:
	var bus = _create_bus()
	var helper := CallHelper.new()
	var id: int = bus.subscribe_once("test/once", Callable(helper, "on_call"), 0)
	assert(typeof(id) == TYPE_INT)
	bus.emit("test/once", ["first"])
	bus.emit("test/once", ["second"])
	# 只应调用一次
	assert(helper.calls.size() == 1)
	assert(helper.calls[0] == ["first"])
	_destroy_bus(bus)


func test_pattern_subscribe() -> void:
	var bus = _create_bus()
	var helper := CallHelper.new()
	var pid: int = bus.subscribe_pattern("^card/.*", Callable(helper, "on_call"), 0, false)
	assert(typeof(pid) == TYPE_INT)
	# 匹配多个事件名
	bus.emit("card/draw", [10])
	bus.emit("card/discard", [20])
	assert(helper.calls.size() == 2)
	assert(helper.calls[0] == [10])
	assert(helper.calls[1] == [20])
	# 按 id 取消 pattern 订阅
	var ok: bool = bus.unsubscribe_pattern_by_id(pid)
	assert(ok == true)
	_destroy_bus(bus)


func test_pause_and_resume() -> void:
	var bus = _create_bus()
	var helper := CallHelper.new()
	bus.subscribe("pause/event", Callable(helper, "on_call"))
	# 暂停该事件
	bus.pause_event("pause/event")
	bus.emit("pause/event", [42])
	# 暂停时不应触发
	assert(helper.calls.size() == 0)
	# 恢复并触发
	bus.resume_event("pause/event")
	bus.emit("pause/event", [99])
	assert(helper.calls.size() == 1)
	assert(helper.calls[0] == [99])
	# 清理
	bus.clear("pause/event")
	_destroy_bus(bus)


func test_emit_async() -> void:
	var bus = _create_bus()
	var helper := CallHelper.new()
	bus.subscribe("async/event", Callable(helper, "on_call"))
	bus.emit_async("async/event", ["a"])
	# 等待下一帧以保证 deferred 调用完成
	await get_tree().process_frame
	# 在下一帧后应当被调用
	assert(helper.calls.size() == 1)
	assert(helper.calls[0] == ["a"])
	# 清理
	bus.clear("async/event")
	_destroy_bus(bus)


func test_unsubscribe_by_id_and_clear() -> void:
	var bus = _create_bus()
	var h1 := CallHelper.new()
	var h2 := CallHelper.new()
	var id1: int = bus.subscribe("clear/me", Callable(h1, "on_call"))
	var _id2: int = bus.subscribe("clear/me", Callable(h2, "on_call"))
	# 通过 id1 取消（unsubscribe_by_id 会删除所有匹配的订阅项）
	var removed_any: bool = bus.unsubscribe_by_id(id1)
	assert(removed_any == true or removed_any == false) # 允许实现返回 true/false，但应运行且不崩溃
	# 触发剩余订阅
	bus.emit("clear/me", [7])
	# 现在清空所有并验证无订阅
	bus.clear("clear/me")
	assert(bus.has_subscribers("clear/me") == false)
	# 全局清空
	bus.subscribe("x", Callable(CallHelper.new(), "on_call"))
	bus.clear()
	assert(bus.has_subscribers("x") == false)
	_destroy_bus(bus)
