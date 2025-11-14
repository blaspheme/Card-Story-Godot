extends Control
class_name FragmentBar

## 碎片栏：显示 FragTree 或 Slot 中的碎片/卡牌列表
## 支持横向/纵向布局、自动更新、对象池管理

#region 导出变量
## 横向布局容器
@onready var horizontal_container: HBoxContainer = $HBoxContainer
## 纵向布局容器
@onready var vertical_container: VBoxContainer = $VBoxContainer

## 自动更新：监听最近父节点的 FragTree 变化
@export var auto_update := false
## 使用纵向布局
@export var vertical := false
## 显示 Aspects
@export var show_aspects := true
## 显示 Cards
@export var show_cards := true
## 显示特殊标记（allowed/forbidden）
@export var show_special := true
## 显示隐藏的碎片
@export var show_hidden := false

## 特殊碎片：允许标记
@export var allowed: AspectData
## 特殊碎片：禁止标记
@export var forbidden: AspectData
## 特殊碎片：抽到的卡牌
@export var drawn: CardData
#endregion

#region 内部变量
## FragmentViz 对象池
var _frag_vizs: Array[FragmentViz] = []
## 当前使用的 FragmentViz 索引
var _index := 0
#endregion

#region 生命周期
func _ready() -> void:
	if auto_update:
		var frag_tree := NodeUtils.get_parent_of_type(self, FragTree) as FragTree
		if frag_tree:
			frag_tree.change_event.connect(load_from_frag_tree.bind(frag_tree))
			load_from_frag_tree(frag_tree)
		else:
			push_warning("FragmentBar: auto_update 已启用但未找到父节点 FragTree")
#endregion

#region 公共方法
## 从 FragTree 加载碎片列表
func load_from_frag_tree(frag_tree: FragTree) -> void:
	unload()
	if frag_tree == null:
		return
	
	_index = 0
	
	if show_cards:
		for card in frag_tree.cards():
			load_variant(card)
	
	if show_aspects:
		for frag in frag_tree.fragments():
			load_variant(frag)

## 从 SlotData 加载需求列表
func load_from_slot(slot: SlotData) -> void:
	unload()
	if not slot:
		return
	
	_index = 0
	
	if slot.required.size() > 0 and show_special and allowed:
		load_variant(allowed)
	
	for frag in slot.required:
		load_variant(frag)
	
	if slot.forbidden.size() > 0 and show_special and forbidden:
		load_variant(forbidden)
	
	for frag in slot.forbidden:
		load_variant(frag)

func load_card_viz(card_viz: CardViz) -> void:
	# showHidden == false 并且卡牌隐藏时，不继续处理
	if not show_hidden and card_viz.card_data.hidden:
		return

	# 情况 1：已有可用 FragViz
	if _index < _frag_vizs.size():
		if card_viz.face_down:
			_frag_vizs[_index].load_variant(drawn)
		else:
			_frag_vizs[_index].load_card_viz(card_viz)
	# 情况 2：数量不够，需要实例化一个新的 FragViz
	else:
		var frag_viz = Manager.GM.fragment_viz.instantiate()
		_frag_vizs.append(frag_viz)
		load_card_viz(card_viz)


func load_variant(frag: Variant) -> void:
	if not show_hidden and frag.hidden():
		return

	if _index < _frag_vizs.size():
		_frag_vizs[_index].load_frag(frag)
		_frag_vizs[_index].visible = true
		_index += 1
	else:
		var frag_viz = Manager.GM.fragment_viz.instantiate()
		_frag_vizs.append(frag_viz)
		load_variant(frag) # 递归


## 卸载所有碎片
func unload() -> void:
	for frag_viz in _frag_vizs:
		frag_viz.visible = false
	
	_index = 0

#endregion
