extends RefCounted
class_name Context

# 按照 AGENTS.md 的静态契约：Context 不再承载旧的兼容字段或代理逻辑。
# 该文件仅作为获取新的 ContextFacade 的工厂入口。

# 池化配置
static var POOL_MAX = 128

# 服务实例（集中管理）
static var _ContextFacadeClass = preload("res://scripts/system/core/context_facade.gd")

static func acquire_from_act_logic(act_logic_arg, keep_matches: bool=false):
	return _ContextFacadeClass.acquire_from_act_logic(act_logic_arg, keep_matches)

static func acquire_from_frag_tree(frag_tree, keep_matches: bool=false):
	return _ContextFacadeClass.acquire_from_frag_tree(frag_tree, keep_matches)

static func acquire_from_card_viz(card_viz, keep_matches: bool=false):
	return _ContextFacadeClass.acquire_from_card_viz(card_viz, keep_matches)
