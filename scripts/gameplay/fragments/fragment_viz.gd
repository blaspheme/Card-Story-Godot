extends Control
class_name FragmentViz

# FragmentViz 的 Godot 迁移实现
# - 从 Unity/C# 的 FragmentViz.cs 移植，保留核心行为：
#   * 显示 fragment（或 card）图像与计数
#   * 响应点击并通过 signal 通知上层 UI（避免在组件内部直接查找/调用单例）
# - 遵循 AGENTS.md 约束：使用 tabs 缩进、显式断言契约、signal 作为通信手段（避免运行时的 has_method 容错）

signal show_aspect(fragment)
signal show_card(card_viz)
signal clicked()

@export var width: float = 120.0
@export var art_node_path: NodePath
@export var count_label_path: NodePath

# 导出当前 fragment（预期为 Resource/Aspect 类型）与 card_viz（若以卡片形式展示）
var fragment = null
var card_viz = null

var _count: int = 0

@onready var art: TextureRect = get_node(art_node_path) if (art_node_path != null and str(art_node_path) != "") else null
@onready var count_label: Label = get_node(count_label_path) if (count_label_path != null and str(count_label_path) != "") else null

func _ready() -> void:
	# 静态契约：确保场景编辑时将必要的子节点赋值给 art_node_path 与 count_label_path
	assert(art != null, "FragmentViz requires a TextureRect assigned to 'art_node_path'")
	assert(count_label != null, "FragmentViz requires a Label assigned to 'count_label_path'")
	_update_visuals()

func set_count(v: int) -> void:
	_count = int(v)
	_update_visuals()

func get_count() -> int:
	return _count

func _update_visuals() -> void:
	# 更新计数文字与大小（尽量简单、可扩展）
	if count_label != null:
		count_label.text = str(_count)

	# 简单尺寸调整：当 _count == 1 时压缩显示，否则完整宽度
	if art != null:
		if _count <= 1:
			art.rect_min_size.x = width * 0.5
			count_label.visible = false
		else:
			art.rect_min_size.x = width
			count_label.visible = true

func load_fragment(frag) -> void:
	# 明确契约：传入的 frag 应该是项目中的 Fragment/Aspect Resource（若不满足，断言失败）
	assert(frag != null)
	fragment = frag
	card_viz = null
	# 约定：frag 应该导出 `art`(Texture2D) 或 `color`(Color)，若不符合请在上层转换
	# 直接访问属性；若属性不存在会触发错误（符合 AGENTS.md 的静态契约风格）
	if fragment.art != null:
		art.texture = fragment.art
		art.modulate = Color(1,1,1,1)
	else:
		art.texture = null
		if fragment.color != null:
			art.modulate = fragment.color

	# fragment 载入时，计数由上层决定；默认设置为 1（上层如需不同计数请调用 set_count）
	set_count(1)

func load_card_viz(cv: Node) -> void:
	# 明确契约：cv 为 CardViz（或含有 `card` 属性的节点），否则断言失败
	assert(cv != null)
	assert(cv.has("card"), "load_card_viz expects a CardViz-like node with a 'card' property")
	card_viz = cv
	fragment = cv.card
	# 使用 fragment 的 art/color 来渲染（与 load_fragment 保持一致）
	if fragment != null:
		if fragment.art != null:
			art.texture = fragment.art
			art.modulate = Color(1,1,1,1)
		elif fragment.color != null:
			art.texture = null
			art.modulate = fragment.color

	set_count(1)

func _gui_input(event) -> void:
	# 响应点击，保留信号以便上层连接（避免组件内直接查找 UI 单例）
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked")
		if card_viz != null:
			emit_signal("show_card", card_viz)
		else:
			emit_signal("show_aspect", fragment)

func set_width(w: float) -> void:
	width = w
	_update_visuals()

func duplicate_visual_state_from(other: FragmentViz) -> void:
	# 小工具：将另一个 FragmentViz 的外观状态复制到当前实例（用于运行时复制）
	assert(other != null)
	fragment = other.fragment
	card_viz = other.card_viz
	set_count(other.get_count())
	if other.art != null and art != null:
		art.texture = other.art.texture
		art.modulate = other.art.modulate
