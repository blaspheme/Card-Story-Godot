extends RefCounted
class_name PoolManager

# 简单的对象池管理器。将对象按类名字符串分组池化。
## 注意：这是一个轻量实现，期望在单线程 Godot 环境中使用。

var _pools: Dictionary = {}

func acquire(class_ref: Object, _pool_max: int = 128) -> Object:
	# class_ref 预期为带有 .new() 的类引用
	var key = "" + str(class_ref)
	if _pools.has(key) and _pools[key].size() > 0:
		return _pools[key].pop_back()
	# 未命中：创建新实例
	if typeof(class_ref) == TYPE_OBJECT and class_ref.has_method("new"):
		return class_ref.new()
	# 退化：尝试直接构造（假设是 GDScript class）
	return class_ref.new()

func release(obj: Object, _pool_max: int = 128) -> void:
	if obj == null:
		return
	var key = obj.get_class()
	if not _pools.has(key):
		_pools[key] = []
	if _pools[key].size() < _pool_max:
		_pools[key].append(obj)
	# 否则丢弃：由 GC 回收

func size_for(class_ref: Object) -> int:
	var key = "" + str(class_ref)
	if _pools.has(key):
		return _pools[key].size()
	return 0
