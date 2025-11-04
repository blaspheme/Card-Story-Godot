extends RefCounted
class_name ModifierCommandBase

# 抽象命令基类：定义命令对象的基本契约（setup / execute / release）
# 子类必须实现 execute(context) 与 release()；setup 可按需覆盖。
# 按 AGENTS.md 约定：使用断言作为静态契约检查，不使用 has_method/has_node 等动态容错。

# 子类可自行实现 setup(...) 接受任意参数签名，基类提供一个通用 varargs 签名以兼容不同子类实现
func setup(..._varargs: Array) -> void:
	# 可被子类覆盖以接收已评估的数据；默认无操作
	pass

func execute(_context) -> void:
	# 抽象方法：必须由子类实现
	assert(false, "ModifierCommandBase.execute must be implemented by subclass")

func release() -> void:
	# 抽象/可选覆写的回收方法，子类应在这里清理自己的字段并准备被池化或 GC
	pass

func assert_context(context) -> void:
	# 常用断言帮助方法，子类在需要时可调用
	assert(context != null, "Context is required by Modifier command")
