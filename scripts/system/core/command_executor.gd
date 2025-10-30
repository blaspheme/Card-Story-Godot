extends RefCounted
class_name CommandExecutor

# 负责按约定执行并回收命令（modifiers），并支持可选的自动池化。
# 静态契约：命令必须实现 execute() 与 release()/dispose()。
# 参数说明：
# - list_ref: Array - 持有要执行的命令对象的数组（按栈顺序 pop_back 执行）
# - data: ContextData / ContextFacade - 传入给命令的上下文
# - pool: PoolManager|null - 可选的池管理器，若提供则在 release() 后把命令对象放回池中
func execute_and_release(list_ref: Array, data, pool: PoolManager = null) -> void:
	assert(list_ref != null)
	# 使用 pop_back 回收以避免中间分配
	while list_ref.size() > 0:
		var cmd = list_ref.pop_back()
		# 静态契约：命令应为对象并实现 execute
		assert(cmd != null and typeof(cmd) == TYPE_OBJECT)
		# 强制契约：命令必须有 execute 方法
		assert(cmd.has_method("execute"))
		# 立刻执行，若抛错则让上层看到异常（按 AGENTS.md 不要静默跳过）
		cmd.execute(data)
		# 回收优先调用 release()，否则尝试 dispose()
		if cmd.has_method("release"):
			cmd.release()
		elif cmd.has_method("dispose"):
			cmd.dispose()
		else:
			assert(false, "Command missing release/dispose method")
		# 自动池化：如果提供了 PoolManager，则将对象放回池中以便复用
		if pool != null:
			# 按契约 pool 应实现 release(obj)
			pool.release(cmd)
	# 确保空（防御）
	list_ref.clear()
