# CardStory Godot版设计方案

> 基于Unity版CardStory插件的Godot移植完整设计文档

## 概览

CardStory是一个数据驱动的卡牌游戏框架，本文档描述其在Godot引擎中的完整实现方案。框架通过**Fragment（碎片）**作为基础数据单元，通过**Rule（规则）**和**Test（测试）**进行逻辑判定，通过**Modifier（修改器）**执行游戏效果。

### 核心设计原则

1. **数据驱动**：所有游戏逻辑通过Resource配置，策划可视化编辑
2. **组件化**：复杂功能通过简单组件组合实现  
3. **延迟执行**：所有修改操作在Context.dispose()时统一执行，保证原子性
4. **作用域隔离**：通过Context管理执行环境，防止副作用
5. **可视化优先**：提供完整的可视化编辑和调试工具

## Godot适配架构

### 核心类型映射

| Unity概念 | Godot实现 | 文件扩展名 | 说明 |
|-----------|-----------|------------|------|
| ScriptableObject | Resource | .tres | 数据资源类 |
| MonoBehaviour | Node | .tscn | 场景节点类 |
| GameObject | Node | .tscn | 场景对象 |
| Prefab | PackedScene | .tscn | 预制体场景 |

### 继承关系图

```
Resource (Godot基类)
├── Fragment (基础碎片)
│   ├── Aspect (属性标签)  
│   └── Card (实体卡牌)
├── Act (行动节点)
├── Rule (规则)
├── Slot (插槽)
├── Token (令牌容器)
└── Deck (牌堆)

Node (场景节点)
├── CardViz (卡牌可视化)
├── TokenViz (令牌可视化)  
├── SlotViz (插槽可视化)
├── ActLogic (行动逻辑管理)
└── FragTree (碎片树管理)
```

### 文件组织结构

```
项目根目录/
├── scenes/                          # 场景文件
│   ├── gameplay/                    # 游戏玩法场景
│   │   ├── main_game.tscn          # 主游戏场景
│   │   ├── card_viz.tscn           # 卡牌可视化预制体
│   │   ├── token_viz.tscn          # Token可视化预制体
│   │   └── slot_viz.tscn           # 插槽可视化预制体
│   └── ui/                         # UI界面场景
│       ├── main_menu.tscn          # 主菜单
│       └── game_ui.tscn            # 游戏UI
├── scripts/                         # 脚本文件
│   ├── core/                       # 核心系统脚本
│   │   ├── fragment.gd             # Fragment基类
│   │   ├── aspect.gd               # Aspect类  
│   │   ├── card.gd                 # Card类
│   │   ├── act.gd                  # Act类
│   │   ├── rule.gd                 # Rule类
│   │   ├── test.gd                 # Test类
│   │   ├── context.gd              # Context类
│   │   ├── modifier.gd             # Modifier相关类
│   │   ├── slot.gd                 # Slot类
│   │   ├── token.gd                # Token类
│   │   └── deck.gd                 # Deck类
│   ├── visualization/              # 可视化相关脚本
│   │   ├── card_viz.gd             # 卡牌可视化
│   │   ├── token_viz.gd            # Token可视化
│   │   ├── slot_viz.gd             # 插槽可视化
│   │   ├── act_logic.gd            # Act逻辑管理
│   │   └── frag_tree.gd            # Fragment树管理
│   ├── managers/                   # 管理器脚本
│   │   ├── game_manager.gd         # 游戏管理器
│   │   ├── ui_manager.gd           # UI管理器
│   │   └── audio_manager.gd        # 音频管理器
│   └── tools/                      # 编辑器工具脚本
│       ├── cardstory_editor.gd     # 主编辑器
│       ├── node_graph_editor.gd    # 节点图编辑器
│       └── debug_panel.gd          # 调试面板
├── resources/                       # 资源文件
│   ├── content/                    # 游戏内容资源
│   │   ├── fragments/              # Fragment资源
│   │   │   ├── aspects/            # Aspect资源
│   │   │   └── cards/              # Card资源
│   │   ├── acts/                   # Act资源
│   │   ├── rules/                  # Rule资源
│   │   ├── slots/                  # Slot资源
│   │   ├── tokens/                 # Token资源
│   │   └── decks/                  # Deck资源
│   ├── themes/                     # UI主题
│   └── templates/                  # 配置模板
├── addons/                         # 插件目录
│   └── cardstory_tools/            # CardStory编辑器插件
│       ├── plugin.cfg              # 插件配置
│       ├── plugin.gd               # 插件入口
│       ├── dock/                   # 停靠面板
│       │   ├── cardstory_dock.gd   # 主停靠面板
│       │   └── cardstory_dock.tscn # 停靠面板UI
│       ├── editor/                 # 编辑器界面
│       │   ├── main_editor.gd      # 主编辑器
│       │   ├── main_editor.tscn    # 编辑器界面
│       │   ├── node_graph.gd       # 节点图系统
│       │   └── property_panel.gd   # 属性面板
│       └── icons/                  # 编辑器图标
└── autoload/                       # 自动加载脚本
    ├── event_bus.gd               # 事件总线
    ├── game_config.gd             # 游戏配置
    └── game_style.gd              # 游戏样式
```

## 核心类实现

### Fragment基类 (fragment.gd)

```gdscript
# Fragment基础类 - 所有游戏元素的基类
class_name Fragment
extends Resource

@export var label: String = ""                    # 唯一标识符
@export var art: Texture2D                        # 显示图像
@export var color: Color = Color.WHITE            # 备用颜色
@export var hidden: bool = false                  # 是否在UI中隐藏
@export_multiline var description: String = ""    # 描述文本

# 组合系统
@export var fragments: Array[Fragment] = []       # 子Fragment列表

# 触发器系统
@export var rules: Array[Rule] = []               # Fragment存在时执行的规则

# 插槽系统  
@export var slots: Array[Slot] = []               # Fragment存在时尝试打开的插槽

# 牌堆关联
@export var deck: Deck                            # 关联的牌堆

# 虚拟方法（由子类实现）
func add_to_tree(fg: FragTree) -> void:
	pass

func remove_from_tree(fg: FragTree) -> void:
	pass
	
func adjust_in_tree(fg: FragTree, level: int) -> int:
	return 0
	
func count_in_tree(fg: FragTree, only_free: bool = false) -> int:
	return 0

# 获取显示名称（支持本地化）
func get_display_name() -> String:
	return tr(label) if label else "未命名Fragment"

# 获取显示图像
func get_display_texture() -> Texture2D:
	return art

# 获取显示颜色
func get_display_color() -> Color:
	return color if art == null else Color.WHITE

# 检查是否包含指定Fragment
func contains_fragment(target: Fragment) -> bool:
	for frag in fragments:
		if frag == target or frag.contains_fragment(target):
			return true
	return false
```

### Aspect类 (aspect.gd)

```gdscript
# Aspect - 属性标签类
class_name Aspect
extends Fragment

func _init():
	super._init()

# 重写Fragment的抽象方法
func add_to_tree(fg: FragTree) -> void:
	fg.add_aspect(self)

func adjust_in_tree(fg: FragTree, level: int) -> int:
	return fg.adjust_aspect(self, level)

func remove_from_tree(fg: FragTree) -> void:
	fg.remove_aspect(self)

func count_in_tree(fg: FragTree, only_free: bool = false) -> int:
	return fg.count_aspect(self, only_free)

# Aspect特有的列表操作
func adjust_in_list(list: Array, level: int) -> int:
	return HeldFragment.adjust_in_list(list, self, level)
```

### Card类 (card.gd)

```gdscript
# Card - 实体卡牌类
class_name Card  
extends Fragment

@export_group("Decay - 衰变系统")
@export var decay_to: Card                        # 衰变目标卡牌
@export var lifetime: float = 0.0                 # 衰变时间
@export var on_decay_complete: Rule               # 衰变完成时执行的规则
@export var on_decay_into: Rule                   # 被衰变为此卡时执行的规则

@export_group("Unique - 唯一性")
@export var unique: bool = false                  # 全局唯一标识

func _init():
	super._init()

# 重写Fragment的抽象方法
func add_to_tree(fg: FragTree) -> void:
	fg.add_card(self)

func adjust_in_tree(fg: FragTree, level: int) -> int:
	return fg.adjust_card(self, level)

func remove_from_tree(fg: FragTree) -> void:
	fg.remove_card(self)

func count_in_tree(fg: FragTree, only_free: bool = false) -> int:
	return fg.count_card(self, only_free)

# 检查是否支持衰变
func can_decay() -> bool:
	return decay_to != null and lifetime > 0

# 开始衰变过程
func start_decay(context: Context) -> void:
	if can_decay():
		# 创建衰变定时器
		var timer = Timer.new()
		timer.wait_time = lifetime
		timer.one_shot = true
		timer.timeout.connect(_on_decay_timeout.bind(context))
		context.act_logic.add_child(timer)
		timer.start()

func _on_decay_timeout(context: Context) -> void:
	# 执行衰变逻辑
	if on_decay_complete:
		on_decay_complete.execute(context)
	# 变形为目标卡牌
	# 这里需要通过Modifier系统实现
```

### Test类 (test.gd)

```gdscript
# Test - 条件测试类
class_name Test
extends Resource

# 操作符枚举
enum ReqOp {
	MORE_OR_EQUAL = 0,    # 大于等于 >=
	EQUAL = 1,            # 等于 ==  
	LESS_OR_EQUAL = 2,    # 小于等于 <=
	MORE = 3,             # 大于 >
	NOT_EQUAL = 4,        # 不等于 !=
	LESS = 5,             # 小于 <
	RANDOM_CHALLENGE = 10, # 随机挑战
	RANDOM_CLASH = 20     # 随机冲突
}

# 位置类型（支持位运算组合）
enum ReqLoc {
	SCOPE = 0,            # 当前作用域
	MATCHED_CARDS = 32,   # 匹配的卡牌 (1 << 5)
	SLOTS = 4,            # 插槽区域 (1 << 2)
	TABLE = 16,           # 桌面区域 (1 << 4)
	HEAP = 8,             # 堆叠区域 (1 << 3)
	FREE = 128,           # 可用区域 (1 << 7)
	ANYWHERE = 64,        # 任意位置 (1 << 6)
}

@export var card_test: bool = false               # 是否为卡牌相关测试
@export var can_fail: bool = false               # 是否允许失败（柔性条件）

# 左操作数
@export var loc1: ReqLoc                         # 第一个位置
@export var fragment1: Fragment                  # 第一个Fragment

# 操作符
@export var op: ReqOp                            # 判定操作符

# 右操作数
@export var constant: int                        # 常数值或乘数
@export var loc2: ReqLoc                         # 第二个位置
@export var fragment2: Fragment                  # 第二个Fragment

# 核心方法
func attempt(context: Context) -> bool:
	var left_count = get_count(context, loc1, fragment1)
	var right_count = constant
	
	if fragment2:
		right_count = constant * get_count(context, loc2, fragment2)
	
	var result = compare_values(left_count, right_count, op)
	
	# 如果是卡牌测试，需要匹配符合条件的卡牌
	if card_test and result:
		match_cards(context)
	
	return result

func get_count(context: Context, loc: ReqLoc, fragment: Fragment) -> int:
	if not fragment:
		return 0
		
	var scope = context.resolve_scope(loc)
	return fragment.count_in_tree(scope)

func compare_values(left: int, right: int, operator: ReqOp) -> bool:
	match operator:
		ReqOp.MORE_OR_EQUAL:
			return left >= right
		ReqOp.EQUAL:
			return left == right
		ReqOp.LESS_OR_EQUAL:
			return left <= right
		ReqOp.MORE:
			return left > right
		ReqOp.NOT_EQUAL:
			return left != right
		ReqOp.LESS:
			return left < right
		ReqOp.RANDOM_CHALLENGE:
			return randf() < (float(left) / max(right, 1))
		ReqOp.RANDOM_CLASH:
			return randi() % max(left + right, 1) < left
		_:
			return false

func match_cards(context: Context) -> void:
	# 匹配符合条件的卡牌到context.matches
	var scope = context.resolve_scope(loc1)
	var cards = scope.get_cards_with_fragment(fragment1)
	context.matches.append_array(cards)
```

### Rule类 (rule.gd)

```gdscript
# Rule - 规则系统类
class_name Rule
extends Resource

@export_group("Tests - 条件测试")
@export var tests: Array[Test] = []               # 必须通过的所有测试
@export var and_rules: Array[Rule] = []           # 必须通过的所有子规则（不执行修改器）
@export var or_rules: Array[Rule] = []            # 至少通过一个子规则（不执行修改器）

@export_group("Modifiers - 效果修改器")  
@export var act_modifiers: Array[ActModifier] = []    # 游戏状态修改器
@export var card_modifiers: Array[CardModifier] = []  # 卡牌修改器
@export var table_modifiers: Array[TableModifier] = [] # 桌面修改器
@export var path_modifiers: Array[PathModifier] = []  # 流程控制修改器
@export var deck_modifiers: Array[DeckModifier] = []  # 牌堆修改器

@export_group("Furthermore - 后续规则")
@export var furthermore: Array[Rule] = []         # 此规则通过后执行的其他规则

@export_multiline var text: String = ""           # 规则描述文本

# 核心方法
func evaluate(context: Context) -> bool:
	return _evaluate_conditions(context, tests, and_rules, or_rules)

func execute(context: Context) -> void:
	if not evaluate(context):
		return
		
	# 添加修改器到Context队列
	for modifier in act_modifiers:
		context.act_modifiers.append(modifier.evaluate(context))
	
	for modifier in card_modifiers:
		context.card_modifiers.append(modifier.evaluate(context))
		
	for modifier in table_modifiers:
		context.table_modifiers.append(modifier)
		
	for modifier in path_modifiers:
		context.path_modifiers.append(modifier)
		
	for modifier in deck_modifiers:
		context.deck_modifiers.append(modifier.evaluate(context))
	
	# 执行后续规则
	for rule in furthermore:
		rule.execute(context)

# 静态工具方法
static func _evaluate_conditions(context: Context, test_list: Array[Test], and_list: Array[Rule], or_list: Array[Rule], force: bool = false) -> bool:
	if force:
		return true
	
	# 所有tests必须通过
	for test in test_list:
		if not test.attempt(context):
			if not test.can_fail:
				return false
	
	# 所有and规则必须通过（仅验证，不执行）
	for rule in and_list:
		if not rule.evaluate(context):
			return false
	
	# 至少一个or规则通过（仅验证，不执行）
	if or_list.size() > 0:
		var any_passed = false
		for rule in or_list:
			if rule.evaluate(context):
				any_passed = true
				break
		if not any_passed:
			return false
	
	return true
```

### Act类 (act.gd)

```gdscript
# Act - 行动节点类
class_name Act
extends Resource

@export var label: String = ""                   # 行动标识

@export_group("基础设置")
@export var token: Token                         # 限制执行的Token（可选）
@export var initial: bool = false                # 是否为初始Act（可被玩家直接触发）
@export var time: float = 0.0                   # 执行时间

@export_group("Entry Tests - 进入条件")
@export var tests: Array[Test] = []              # 必须通过的所有测试
@export var and_rules: Array[Rule] = []          # 必须通过的所有Rule（仅验证，不执行修改器）
@export var or_rules: Array[Rule] = []           # 至少通过一个Rule（仅验证，不执行修改器）

@export_group("完成效果")
@export var fragments: Array[Fragment] = []      # 完成后添加的Fragment

@export_group("On Complete - 完成时的修改器")
@export var act_modifiers: Array[ActModifier] = []    # 游戏状态修改器
@export var card_modifiers: Array[CardModifier] = []  # 卡牌修改器
@export var table_modifiers: Array[TableModifier] = [] # 桌面修改器
@export var path_modifiers: Array[PathModifier] = []  # 流程控制修改器
@export var deck_modifiers: Array[DeckModifier] = []  # 牌堆修改器

@export_group("Furthermore - 后续规则")
@export var furthermore: Array[Rule] = []        # 完成后执行的规则

@export_group("Slots - 插槽配置")
@export var ignore_global_slots: bool = false   # 是否忽略全局插槽
@export var slots: Array[Slot] = []             # Act运行时尝试打开的插槽

@export_group("流程控制")
# Alt Acts - 可选分支（不生成新Token）
@export var random_alt: bool = false            # 是否随机选择分支
@export var alt_acts: Array[ActLink] = []       # 可选分支列表

# Next Acts - 主流程推进（不生成新Token）
@export var random_next: bool = false           # 是否随机选择下一个
@export var next_acts: Array[ActLink] = []      # 下一个Act列表

# Spawned Acts - 生成新流程（生成新Token）
@export var spawned_acts: Array[ActLink] = []   # 生成的新Act列表

@export_group("On Spawn - 生成时")
@export var on_spawn: Rule                      # 在新Token中生成此Act时执行的规则

@export_group("Text - 文本系统")
@export_multiline var text: String = ""         # 主描述文本
@export var text_rules: Array[Rule] = []        # 文本相关规则
@export_multiline var end_text: String = ""     # 结束描述文本
@export var end_text_rules: Array[Rule] = []    # 结束文本相关规则

# 核心方法
func attempt(context: Context, force: bool = false) -> bool:
	return Rule._evaluate_conditions(context, tests, and_rules, or_rules, force)

func apply_modifiers(context: Context) -> void:
	# 执行完成时的修改器
	Rule._execute_modifiers(context, act_modifiers, card_modifiers, table_modifiers, path_modifiers, deck_modifiers, furthermore)

# ActLink类
class ActLink:
	@export_range(0, 100) var chance: int = 100  # 触发概率（0-100）
	@export var act: Act                         # 目标Act
	@export var act_rule: Rule                   # 触发条件（设置后chance失效）
	
	func should_attempt(context: Context) -> bool:
		if act_rule:
			return act_rule.evaluate(context)
		return randf() * 100 < chance
```

## 可视化系统

### CardViz类 (card_viz.gd)

```gdscript
# CardViz - 卡牌可视化类
class_name CardViz
extends Control

signal card_clicked(card_viz: CardViz)
signal card_dragged(card_viz: CardViz, global_position: Vector2)
signal card_dropped(card_viz: CardViz, target: Node)

@export var card: Card                           # 关联的Card资源
@export var draggable: bool = true               # 是否可拖拽
@export var selectable: bool = true              # 是否可选择

# UI组件引用
@onready var card_image: TextureRect = $CardImage
@onready var card_label: Label = $CardLabel  
@onready var card_description: RichTextLabel = $CardDescription
@onready var aspect_container: HBoxContainer = $AspectContainer

var is_dragging: bool = false
var drag_offset: Vector2
var original_parent: Node
var original_position: Vector2

func _ready():
	if card:
		update_display()
	
	# 连接信号
	gui_input.connect(_on_gui_input)

func update_display():
	if not card:
		return
		
	# 更新卡牌图像
	if card.art:
		card_image.texture = card.art
	else:
		card_image.modulate = card.color
		
	# 更新文本
	card_label.text = card.get_display_name()
	card_description.text = card.description
	
	# 更新Aspect显示
	update_aspects()

func update_aspects():
	# 清空现有Aspect
	for child in aspect_container.get_children():
		child.queue_free()
	
	# 添加Fragment中的Aspect
	for fragment in card.fragments:
		if fragment is Aspect:
			var aspect_icon = preload("res://scenes/ui/aspect_icon.tscn").instantiate()
			aspect_icon.setup(fragment)
			aspect_container.add_child(aspect_icon)

func _on_gui_input(event: InputEvent):
	if not selectable and not draggable:
		return
		
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				if selectable:
					card_clicked.emit(self)
				if draggable:
					start_drag(mouse_event.global_position)
			else:
				if is_dragging:
					end_drag(mouse_event.global_position)
	
	elif event is InputEventMouseMotion and is_dragging:
		update_drag(event.global_position)

func start_drag(global_pos: Vector2):
	is_dragging = true
	drag_offset = global_pos - global_position
	original_parent = get_parent()
	original_position = position
	
	# 移动到顶层以便拖拽时显示在最前面
	get_parent().move_child(self, -1)
	z_index = 100

func update_drag(global_pos: Vector2):
	if is_dragging:
		global_position = global_pos - drag_offset
		card_dragged.emit(self, global_position)

func end_drag(global_pos: Vector2):
	is_dragging = false
	z_index = 0
	
	# 检测拖拽目标
	var target = find_drop_target(global_pos)
	if target:
		card_dropped.emit(self, target)
	else:
		# 返回原位置
		position = original_position

func find_drop_target(global_pos: Vector2) -> Node:
	# 查找可以接受卡牌的SlotViz
	var space_state = get_viewport().world_2d.direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_pos
	query.collision_mask = 1  # SlotViz图层
	
	var results = space_state.intersect_point(query)
	for result in results:
		var collider = result["collider"]
		if collider.get_parent() is SlotViz:
			return collider.get_parent()
	
	return null

# 动画效果
func animate_to_position(target_pos: Vector2, duration: float = 0.3):
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.tween_callback(func(): is_dragging = false)

func animate_highlight():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate", Color.YELLOW, 0.5)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
```

## 高级可视化编辑工具设计

### 编辑器插件架构

CardStory需要一个专门的可视化编辑工具来简化复杂的配置工作。这个工具将作为Godot编辑器插件实现。

#### 主要功能模块

1. **节点图编辑器** - 可视化编辑Act流程和Rule关系
2. **属性面板** - 智能属性编辑，支持引用完成和验证
3. **实时预览** - 预览配置效果，模拟游戏流程
4. **调试工具** - 运行时状态监控和流程追踪
5. **模板库** - 预设配置模板，加速开发

#### 核心界面设计

```
┌─────────────────────────────────────────────────────────────────────┐
│ CardStory编辑器                                    [最小化][关闭] │
├─────────────────────────────────────────────────────────────────────┤
│ [文件] [编辑] [视图] [工具] [帮助]                              │
├─────┬─────────────────────────────────────────────────────┬─────────┤
│资源 │                                                     │ 属性面板 │
│浏览器│                 节点图编辑区域                        │         │
│     │                                                     │  [基本]  │
│[+]新建│  ┌─────┐    ┌─────────┐    ┌─────┐               │  [条件]  │
│ Aspect│  │开始 ├────│工作Act  ├────│结束 │               │  [效果]  │
│ Card  │  └─────┘    └─────────┘    └─────┘               │  [流程]  │
│ Act   │       \                        /                  │         │  
│ Rule  │        \    ┌─────────┐      /                   │ 验证结果 │
│ Slot  │         └───│休息Act  ├─────┘                    │ ✓ 语法正确│
│ Token │             └─────────┘                          │ ⚠ 缺少引用│
│ Deck  │                                                  │         │
├─────┴─────────────────────────────────────────────────────┴─────────┤
│ 控制台: [日志] [错误] [调试]                                     │
│ > Act "工作" 验证通过                                           │
│ ⚠ Rule "工资计算" 缺少Fragment引用                              │
└─────────────────────────────────────────────────────────────────────┘
```

### 插件实现方案

#### 1. 插件入口 (addons/cardstory_tools/plugin.gd)

```gdscript
# CardStory编辑器插件
@tool
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/cardstory_tools/dock/cardstory_dock.tscn")
const MAIN_EDITOR_SCENE = preload("res://addons/cardstory_tools/editor/main_editor.tscn")

var dock_instance
var editor_window

func _enter_tree():
	# 添加停靠面板
	dock_instance = DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_LEFT_UR, dock_instance)
	
	# 添加主编辑器按钮到工具栏
	add_tool_menu_item("CardStory编辑器", open_main_editor)
	
	# 注册自定义资源类型
	add_custom_type(
		"Fragment", 
		"Resource", 
		preload("res://scripts/core/fragment.gd"),
		preload("res://addons/cardstory_tools/icons/fragment.svg")
	)
	add_custom_type(
		"Card", 
		"Fragment", 
		preload("res://scripts/core/card.gd"),
		preload("res://addons/cardstory_tools/icons/card.svg")  
	)
	add_custom_type(
		"Aspect", 
		"Fragment", 
		preload("res://scripts/core/aspect.gd"),
		preload("res://addons/cardstory_tools/icons/aspect.svg")
	)
	add_custom_type(
		"Act", 
		"Resource", 
		preload("res://scripts/core/act.gd"),
		preload("res://addons/cardstory_tools/icons/act.svg")
	)
	# ... 其他类型注册

func _exit_tree():
	remove_control_from_docks(dock_instance)
	remove_tool_menu_item("CardStory编辑器")
	
	# 移除自定义类型
	remove_custom_type("Fragment")
	remove_custom_type("Card")
	remove_custom_type("Aspect") 
	remove_custom_type("Act")
	# ... 其他类型移除
	
	if editor_window:
		editor_window.queue_free()

func open_main_editor():
	if not editor_window:
		editor_window = MAIN_EDITOR_SCENE.instantiate()
		EditorInterface.get_editor_main_screen().add_child(editor_window)
	
	editor_window.show()
	editor_window.grab_focus()
```

#### 2. 主编辑器界面 (addons/cardstory_tools/editor/main_editor.gd)

```gdscript
# CardStory主编辑器
@tool
extends Window

# UI组件引用
@onready var resource_tree: Tree = $HSplitContainer/LeftPanel/ResourceTree
@onready var node_graph: Control = $HSplitContainer/CenterPanel/NodeGraph  
@onready var property_panel: Control = $HSplitContainer/RightPanel/PropertyPanel
@onready var console: RichTextLabel = $VBoxContainer/BottomPanel/Console

# 当前编辑的资源
var current_resource: Resource
var current_resource_path: String

# 资源缓存
var resource_cache: Dictionary = {}

func _ready():
	setup_ui()
	load_resources()
	
	# 连接信号
	resource_tree.item_selected.connect(_on_resource_selected)
	node_graph.node_selected.connect(_on_node_selected)
	property_panel.property_changed.connect(_on_property_changed)

func setup_ui():
	title = "CardStory编辑器"
	size = Vector2i(1400, 900)
	min_size = Vector2i(800, 600)
	
	# 设置分割面板比例
	$HSplitContainer.split_offset = 250
	$HSplitContainer/CenterPanel/VSplitContainer.split_offset = -150

func load_resources():
	resource_tree.clear()
	var root = resource_tree.create_item()
	root.set_text(0, "CardStory资源")
	
	# 加载各类型资源
	load_resource_folder("res://resources/content/fragments/aspects/", "Aspects", root)
	load_resource_folder("res://resources/content/fragments/cards/", "Cards", root)
	load_resource_folder("res://resources/content/acts/", "Acts", root)
	load_resource_folder("res://resources/content/rules/", "Rules", root)
	load_resource_folder("res://resources/content/slots/", "Slots", root)
	load_resource_folder("res://resources/content/tokens/", "Tokens", root)
	load_resource_folder("res://resources/content/decks/", "Decks", root)

func load_resource_folder(path: String, type_name: String, parent: TreeItem):
	var dir = DirAccess.open(path)
	if not dir:
		return
		
	var type_item = resource_tree.create_item(parent)
	type_item.set_text(0, type_name)
	type_item.set_icon(0, get_type_icon(type_name))
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource_item = resource_tree.create_item(type_item)
			resource_item.set_text(0, file_name.get_basename())
			resource_item.set_metadata(0, path + file_name)
		file_name = dir.get_next()

func get_type_icon(type_name: String) -> Texture2D:
	var icon_path = "res://addons/cardstory_tools/icons/" + type_name.to_lower() + ".svg"
	return load(icon_path) as Texture2D

func _on_resource_selected():
	var selected = resource_tree.get_selected()
	if not selected or not selected.get_metadata(0):
		return
		
	var resource_path = selected.get_metadata(0)
	load_resource_for_editing(resource_path)

func load_resource_for_editing(path: String):
	current_resource_path = path
	
	# 从缓存加载或创建新资源
	if path in resource_cache:
		current_resource = resource_cache[path]
	else:
		current_resource = load(path)
		resource_cache[path] = current_resource
	
	# 更新各个面板
	node_graph.load_resource(current_resource)
	property_panel.load_resource(current_resource)
	
	log_message("已加载资源: " + path)

func _on_node_selected(node_data: Dictionary):
	# 节点图中选择了节点，更新属性面板
	property_panel.load_node(node_data)

func _on_property_changed(property_name: String, value):
	# 属性面板中属性发生变化
	if current_resource:
		current_resource.set(property_name, value)
		mark_resource_dirty()
		
		# 实时验证
		validate_resource()

func mark_resource_dirty():
	if current_resource_path:
		# 标记资源需要保存
		title = "CardStory编辑器*"  # 添加*表示未保存

func save_current_resource():
	if current_resource and current_resource_path:
		ResourceSaver.save(current_resource, current_resource_path)
		title = "CardStory编辑器"  # 移除*
		log_message("已保存: " + current_resource_path)

func validate_resource():
	if not current_resource:
		return
		
	var validator = CardStoryValidator.new()
	var errors = validator.validate_resource(current_resource)
	
	# 在控制台显示验证结果
	if errors.is_empty():
		log_message("✓ 验证通过", Color.GREEN)
	else:
		for error in errors:
			log_message("⚠ " + error, Color.ORANGE)

func log_message(message: String, color: Color = Color.WHITE):
	console.append_text("[" + Time.get_time_string_from_system() + "] ")
	console.push_color(color)
	console.append_text(message + "\n")
	console.pop()
```

#### 3. 节点图编辑器 (addons/cardstory_tools/editor/node_graph.gd)

```gdscript
# 节点图编辑器 - 用于可视化编辑Act流程和Rule关系
@tool
extends Control

signal node_selected(node_data: Dictionary)

@onready var graph_edit: GraphEdit = $GraphEdit

var current_resource: Resource
var node_instances: Dictionary = {}

func _ready():
	setup_graph()

func setup_graph():
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.node_selected.connect(_on_node_selected)
	
	# 设置图编辑器属性
	graph_edit.right_disconnects = true
	graph_edit.show_zoom_label = true

func load_resource(resource: Resource):
	current_resource = resource
	clear_graph()
	
	if resource is Act:
		load_act_graph(resource)
	elif resource is Rule:
		load_rule_graph(resource)

func clear_graph():
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	node_instances.clear()

func load_act_graph(act: Act):
	# 创建主Act节点
	var main_node = create_act_node(act, Vector2(400, 200))
	
	# 创建Entry Tests节点
	if not act.tests.is_empty() or not act.and_rules.is_empty() or not act.or_rules.is_empty():
		var entry_node = create_entry_tests_node(act, Vector2(100, 200))
		graph_edit.connect_node(entry_node.name, 0, main_node.name, 0)
	
	# 创建后续Act节点
	var x_offset = 700
	var y_offset = 100
	
	# Alt Acts
	for i in range(act.alt_acts.size()):
		var alt_act = act.alt_acts[i].act
		if alt_act:
			var alt_node = create_act_node(alt_act, Vector2(x_offset, y_offset + i * 120), true)
			graph_edit.connect_node(main_node.name, 1, alt_node.name, 0)
	
	# Next Acts  
	for i in range(act.next_acts.size()):
		var next_act = act.next_acts[i].act
		if next_act:
			var next_node = create_act_node(next_act, Vector2(x_offset + 200, y_offset + i * 120), true)
			graph_edit.connect_node(main_node.name, 2, next_node.name, 0)
	
	# Spawned Acts
	for i in range(act.spawned_acts.size()):
		var spawned_act = act.spawned_acts[i].act
		if spawned_act:
			var spawned_node = create_act_node(spawned_act, Vector2(x_offset + 400, y_offset + i * 120), true)
			graph_edit.connect_node(main_node.name, 3, spawned_node.name, 0)

func create_act_node(act: Act, pos: Vector2, readonly: bool = false) -> GraphNode:
	var node = GraphNode.new()
	node.name = "Act_" + str(act.get_instance_id())
	node.title = act.label if act.label else "未命名Act"
	node.position_offset = pos
	
	# 设置插槽
	if not readonly:
		node.set_slot_enabled_left(0, true)   # 输入：条件
		node.set_slot_enabled_right(1, true)  # 输出：Alt Acts
		node.set_slot_enabled_right(2, true)  # 输出：Next Acts  
		node.set_slot_enabled_right(3, true)  # 输出：Spawned Acts
		
		node.set_slot_color_left(0, Color.BLUE)
		node.set_slot_color_right(1, Color.YELLOW)
		node.set_slot_color_right(2, Color.GREEN)
		node.set_slot_color_right(3, Color.RED)
	else:
		node.set_slot_enabled_left(0, true)
		node.set_slot_color_left(0, Color.GRAY)
	
	# 添加内容
	var label = Label.new()
	label.text = "执行时间: " + str(act.time) + "s"
	node.add_child(label)
	
	if act.fragments.size() > 0:
		var fragments_label = Label.new()
		fragments_label.text = "效果: " + str(act.fragments.size()) + " 个Fragment"
		node.add_child(fragments_label)
	
	# 存储关联数据
	node.set_meta("resource", act)
	node_instances[node.name] = node
	
	graph_edit.add_child(node)
	return node

func create_entry_tests_node(act: Act, pos: Vector2) -> GraphNode:
	var node = GraphNode.new()
	node.name = "Entry_" + str(act.get_instance_id())
	node.title = "进入条件"
	node.position_offset = pos
	
	node.set_slot_enabled_right(0, true)
	node.set_slot_color_right(0, Color.BLUE)
	
	# 添加条件信息
	if act.tests.size() > 0:
		var tests_label = Label.new()
		tests_label.text = "Tests: " + str(act.tests.size())
		node.add_child(tests_label)
	
	if act.and_rules.size() > 0:
		var and_label = Label.new()
		and_label.text = "AND Rules: " + str(act.and_rules.size())
		node.add_child(and_label)
	
	if act.or_rules.size() > 0:
		var or_label = Label.new()
		or_label.text = "OR Rules: " + str(act.or_rules.size())  
		node.add_child(or_label)
	
	graph_edit.add_child(node)
	return node

func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	# 处理连接请求
	graph_edit.connect_node(from_node, from_port, to_node, to_port)

func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int):
	# 处理断开连接请求
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)

func _on_node_selected(node: Node):
	if node.has_meta("resource"):
		var resource = node.get_meta("resource")
		node_selected.emit({"resource": resource, "node": node})
```

#### 4. 智能属性面板 (addons/cardstory_tools/editor/property_panel.gd)

```gdscript
# 智能属性面板 - 提供上下文感知的属性编辑
@tool
extends Control

signal property_changed(property_name: String, value)

@onready var property_container: VBoxContainer = $ScrollContainer/PropertyContainer
@onready var validation_label: RichTextLabel = $ValidationPanel/ValidationLabel

var current_resource: Resource
var property_editors: Dictionary = {}

func _ready():
	setup_ui()

func setup_ui():
	# 设置验证面板样式
	validation_label.fit_content = true
	validation_label.scroll_active = false

func load_resource(resource: Resource):
	current_resource = resource
	clear_properties()
	
	if resource:
		create_property_editors(resource)
		validate_properties()

func clear_properties():
	for child in property_container.get_children():
		child.queue_free()
	property_editors.clear()

func create_property_editors(resource: Resource):
	var property_list = resource.get_property_list()
	
	# 按组分类属性
	var groups = {}
	var current_group = "基本属性"
	
	for property in property_list:
		if property.usage & PROPERTY_USAGE_CATEGORY:
			continue
		if property.usage & PROPERTY_USAGE_GROUP:
			current_group = property.name
			continue
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if not current_group in groups:
				groups[current_group] = []
			groups[current_group].append(property)
	
	# 创建分组的属性编辑器
	for group_name in groups.keys():
		create_property_group(group_name, groups[group_name])

func create_property_group(group_name: String, properties: Array):
	# 创建分组标题
	var group_label = Label.new()
	group_label.text = group_name
	group_label.add_theme_font_size_override("font_size", 14)
	group_label.add_theme_color_override("font_color", Color.CYAN)
	property_container.add_child(group_label)
	
	# 创建分组容器
	var group_container = VBoxContainer.new()
	property_container.add_child(group_container)
	
	# 为每个属性创建编辑器
	for property in properties:
		create_property_editor(property, group_container)
	
	# 添加分隔线
	var separator = HSeparator.new()
	property_container.add_child(separator)

func create_property_editor(property: Dictionary, parent: Control):
	var property_name = property.name
	var property_type = property.type
	var current_value = current_resource.get(property_name)
	
	# 创建属性行容器
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	# 属性标签
	var label = Label.new()
	label.text = beautify_property_name(property_name)
	label.custom_minimum_size.x = 120
	hbox.add_child(label)
	
	# 根据类型创建编辑器
	var editor = create_typed_editor(property_type, current_value, property_name)
	if editor:
		hbox.add_child(editor)
		property_editors[property_name] = editor
		
		# 连接值变化信号
		connect_editor_signal(editor, property_name)

func beautify_property_name(name: String) -> String:
	# 将snake_case转换为可读形式
	return name.replace("_", " ").capitalize()

func create_typed_editor(type: int, value, property_name: String) -> Control:
	match type:
		TYPE_BOOL:
			var checkbox = CheckBox.new()
			checkbox.button_pressed = value
			return checkbox
			
		TYPE_INT:
			if property_name.contains("chance") or property_name.contains("percent"):
				# 百分比滑块
				var slider = HSlider.new()
				slider.min_value = 0
				slider.max_value = 100
				slider.step = 1
				slider.value = value
				
				var value_label = Label.new()
				value_label.text = str(value) + "%"
				
				var container = HBoxContainer.new()
				container.add_child(slider)
				container.add_child(value_label)
				
				# 连接滑块值变化
				slider.value_changed.connect(func(val): value_label.text = str(val) + "%")
				
				return container
			else:
				var spinbox = SpinBox.new()
				spinbox.value = value
				spinbox.allow_greater = true
				spinbox.allow_lesser = true
				return spinbox
				
		TYPE_FLOAT:
			var spinbox = SpinBox.new()
			spinbox.step = 0.1
			spinbox.value = value
			spinbox.allow_greater = true
			spinbox.allow_lesser = true
			return spinbox
			
		TYPE_STRING:
			if property_name.contains("description") or property_name.contains("text"):
				var text_edit = TextEdit.new()
				text_edit.text = value
				text_edit.custom_minimum_size.y = 80
				text_edit.wrap_mode = TextEdit.WRAP_WORD_SMART
				return text_edit
			else:
				var line_edit = LineEdit.new()
				line_edit.text = value
				line_edit.custom_minimum_size.x = 200
				return line_edit
				
		TYPE_OBJECT:
			# 资源选择器
			return create_resource_picker(value, property_name)
			
		TYPE_ARRAY:
			# 数组编辑器
			return create_array_editor(value, property_name)
			
		_:
			# 默认标签显示
			var label = Label.new()
			label.text = str(value)
			return label

func create_resource_picker(value: Resource, property_name: String) -> Control:
	var container = HBoxContainer.new()
	
	# 资源预览
	var preview = Label.new()
	preview.text = get_resource_display_name(value)
	preview.custom_minimum_size.x = 150
	container.add_child(preview)
	
	# 选择按钮
	var select_btn = Button.new()
	select_btn.text = "选择..."
	select_btn.pressed.connect(func(): show_resource_dialog(property_name, preview))
	container.add_child(select_btn)
	
	# 清除按钮
	if value:
		var clear_btn = Button.new()
		clear_btn.text = "清除"
		clear_btn.pressed.connect(func(): clear_resource_property(property_name, preview))
		container.add_child(clear_btn)
	
	return container

func create_array_editor(array: Array, property_name: String) -> Control:
	var container = VBoxContainer.new()
	
	# 数组标题
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "数组 (" + str(array.size()) + " 项)"
	header.add_child(title)
	
	# 添加按钮
	var add_btn = Button.new()
	add_btn.text = "添加"
	add_btn.pressed.connect(func(): add_array_item(property_name, container))
	header.add_child(add_btn)
	
	container.add_child(header)
	
	# 数组元素
	for i in range(array.size()):
		var item_container = create_array_item_editor(array[i], i, property_name)
		container.add_child(item_container)
	
	return container

func create_array_item_editor(item, index: int, property_name: String) -> Control:
	var container = HBoxContainer.new()
	
	# 索引标签
	var index_label = Label.new()
	index_label.text = "[" + str(index) + "]"
	index_label.custom_minimum_size.x = 30
	container.add_child(index_label)
	
	# 项目编辑器
	if item is Resource:
		var resource_picker = create_resource_picker(item, property_name + "_" + str(index))
		container.add_child(resource_picker)
	else:
		var editor = create_typed_editor(typeof(item), item, property_name + "_" + str(index))
		if editor:
			container.add_child(editor)
	
	# 删除按钮
	var delete_btn = Button.new()
	delete_btn.text = "删除"
	delete_btn.pressed.connect(func(): remove_array_item(property_name, index))
	container.add_child(delete_btn)
	
	return container

func connect_editor_signal(editor: Control, property_name: String):
	if editor is CheckBox:
		editor.toggled.connect(func(pressed): emit_property_changed(property_name, pressed))
	elif editor is SpinBox:
		editor.value_changed.connect(func(value): emit_property_changed(property_name, value))
	elif editor is LineEdit:
		editor.text_changed.connect(func(text): emit_property_changed(property_name, text))
	elif editor is TextEdit:
		editor.text_changed.connect(func(): emit_property_changed(property_name, editor.text))
	elif editor is HBoxContainer and editor.get_child(0) is HSlider:
		var slider = editor.get_child(0) as HSlider
		slider.value_changed.connect(func(value): emit_property_changed(property_name, int(value)))

func emit_property_changed(property_name: String, value):
	if current_resource:
		current_resource.set(property_name, value)
		property_changed.emit(property_name, value)
		validate_properties()

func validate_properties():
	if not current_resource:
		return
		
	var validator = CardStoryValidator.new()
	var errors = validator.validate_resource(current_resource)
	
	validation_label.clear()
	if errors.is_empty():
		validation_label.append_text("[color=green]✓ 验证通过[/color]")
	else:
		validation_label.append_text("[color=orange]验证问题:[/color]\n")
		for error in errors:
			validation_label.append_text("[color=red]• " + error + "[/color]\n")

func get_resource_display_name(resource: Resource) -> String:
	if not resource:
		return "无"
	
	if resource.has_method("get_display_name"):
		return resource.get_display_name()
	elif resource.resource_path:
		return resource.resource_path.get_file().get_basename()
	else:
		return resource.get_class()

func show_resource_dialog(property_name: String, preview_label: Label):
	# 显示资源选择对话框
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tres", "Godot资源文件")
	
	# 根据属性名设置默认路径
	var default_path = get_default_resource_path(property_name)
	if default_path:
		dialog.current_dir = default_path
	
	dialog.file_selected.connect(func(path): load_selected_resource(property_name, path, preview_label))
	
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func get_default_resource_path(property_name: String) -> String:
	# 根据属性名返回对应的资源目录
	if "fragment" in property_name or "aspect" in property_name:
		return "res://resources/content/fragments/"
	elif "card" in property_name:
		return "res://resources/content/fragments/cards/"
	elif "act" in property_name:
		return "res://resources/content/acts/"
	elif "rule" in property_name:
		return "res://resources/content/rules/"
	elif "slot" in property_name:
		return "res://resources/content/slots/"
	elif "token" in property_name:
		return "res://resources/content/tokens/"
	elif "deck" in property_name:
		return "res://resources/content/decks/"
	else:
		return "res://resources/content/"

func load_selected_resource(property_name: String, path: String, preview_label: Label):
	var resource = load(path)
	if resource:
		emit_property_changed(property_name, resource)
		preview_label.text = get_resource_display_name(resource)

func clear_resource_property(property_name: String, preview_label: Label):
	emit_property_changed(property_name, null)
	preview_label.text = "无"
```

#### 5. 资源验证器 (addons/cardstory_tools/validator/cardstory_validator.gd)

```gdscript
# CardStory资源验证器
class_name CardStoryValidator
extends RefCounted

func validate_resource(resource: Resource) -> Array[String]:
	var errors: Array[String] = []
	
	if resource is Fragment:
		errors.append_array(validate_fragment(resource))
	elif resource is Act:
		errors.append_array(validate_act(resource))
	elif resource is Rule:
		errors.append_array(validate_rule(resource))
	elif resource is Test:
		errors.append_array(validate_test(resource))
	elif resource is Slot:
		errors.append_array(validate_slot(resource))
	elif resource is Token:
		errors.append_array(validate_token(resource))
	elif resource is Deck:
		errors.append_array(validate_deck(resource))
	
	return errors

func validate_fragment(fragment: Fragment) -> Array[String]:
	var errors: Array[String] = []
	
	# 检查必要字段
	if fragment.label.is_empty():
		errors.append("Fragment缺少label标识符")
	
	# 检查循环引用
	if has_circular_reference(fragment, []):
		errors.append("Fragment存在循环引用")
	
	# 检查子Fragment的有效性
	for sub_fragment in fragment.fragments:
		if not sub_fragment:
			errors.append("Fragment包含空的子Fragment引用")
	
	return errors

func validate_act(act: Act) -> Array[String]:
	var errors: Array[String] = []
	
	# 检查基本字段
	if act.label.is_empty():
		errors.append("Act缺少label标识符")
	
	if act.time < 0:
		errors.append("Act执行时间不能为负数")
	
	# 检查Entry Tests
	for test in act.tests:
		if not test:
			errors.append("Act包含空的Test引用")
		else:
			errors.append_array(validate_test(test))
	
	# 检查Rule引用
	for rule in act.and_rules:
		if not rule:
			errors.append("Act包含空的AND Rule引用")
	
	for rule in act.or_rules:
		if not rule:
			errors.append("Act包含空的OR Rule引用")
	
	# 检查流程控制
	if act.alt_acts.is_empty() and act.next_acts.is_empty() and act.spawned_acts.is_empty():
		if not act.fragments.is_empty() or not act.act_modifiers.is_empty():
			# 有效果但没有后续流程，可能是终止节点，这是合法的
			pass
		else:
			errors.append("Act没有后续流程且没有任何效果")
	
	return errors

func validate_rule(rule: Rule) -> Array[String]:
	var errors: Array[String] = []
	
	# 检查条件
	if rule.tests.is_empty() and rule.and_rules.is_empty() and rule.or_rules.is_empty():
		errors.append("Rule没有任何条件，将总是执行")
	
	# 检查效果
	var has_effect = false
	has_effect = has_effect or not rule.act_modifiers.is_empty()
	has_effect = has_effect or not rule.card_modifiers.is_empty()
	has_effect = has_effect or not rule.table_modifiers.is_empty()
	has_effect = has_effect or not rule.path_modifiers.is_empty()
	has_effect = has_effect or not rule.deck_modifiers.is_empty()
	has_effect = has_effect or not rule.furthermore.is_empty()
	
	if not has_effect:
		errors.append("Rule没有任何效果")
	
	return errors

func validate_test(test: Test) -> Array[String]:
	var errors: Array[String] = []
	
	# 检查Fragment引用
	if not test.fragment1:
		errors.append("Test缺少fragment1引用")
	
	# 检查操作数设置
	if test.fragment2 and test.constant == 0:
		errors.append("Test设置了fragment2但constant为0，可能导致意外结果")
	
	return errors

func validate_slot(slot: Slot) -> Array[String]:
	var errors: Array[String] = []
	
	if slot.label.is_empty():
		errors.append("Slot缺少label标识符")
	
	# 检查接受条件
	if not slot.accept_all and slot.required.is_empty() and slot.essential.is_empty():
		errors.append("Slot不接受所有卡牌，但没有设置接受条件")
	
	return errors

func validate_token(token: Token) -> Array[String]:
	var errors: Array[String] = []
	
	if token.label.is_empty():
		errors.append("Token缺少label标识符")
	
	return errors

func validate_deck(deck: Deck) -> Array[String]:
	var errors: Array[String] = []
	
	if deck.label.is_empty():
		errors.append("Deck缺少label标识符")
	
	if deck.fragments.is_empty() and not deck.default_fragment:
		errors.append("Deck为空且没有设置默认Fragment")
	
	return errors

func has_circular_reference(fragment: Fragment, visited: Array) -> bool:
	if fragment in visited:
		return true
	
	visited.append(fragment)
	
	for sub_fragment in fragment.fragments:
		if sub_fragment and has_circular_reference(sub_fragment, visited.duplicate()):
			return true
	
	return false
```

## 调试和实时预览功能

### 实时游戏状态监控

```gdscript
# 游戏状态调试面板
class_name GameDebugPanel
extends Control

@onready var state_tree: Tree = $HSplitContainer/StateTree
@onready var flow_graph: Control = $HSplitContainer/FlowGraph
@onready var console: RichTextLabel = $VBoxContainer/Console

var current_context: Context
var monitored_tokens: Array[TokenViz] = []

func _ready():
	# 连接游戏事件
	EventBus.act_started.connect(_on_act_started)
	EventBus.act_completed.connect(_on_act_completed)
	EventBus.context_created.connect(_on_context_created)
	EventBus.context_disposed.connect(_on_context_disposed)

func _on_act_started(act: Act, context: Context):
	log_event("开始执行Act: " + act.label, Color.CYAN)
	current_context = context
	update_state_display()
	highlight_flow_node(act)

func _on_act_completed(act: Act, context: Context):
	log_event("完成Act: " + act.label, Color.GREEN)
	update_state_display()

func _on_context_created(context: Context):
	log_event("创建Context", Color.YELLOW)
	display_context_info(context)

func _on_context_disposed(context: Context):
	log_event("销毁Context，执行" + str(context.get_total_modifiers()) + "个修改器", Color.ORANGE)

func update_state_display():
	state_tree.clear()
	var root = state_tree.create_item()
	root.set_text(0, "游戏状态")
	
	# 显示所有Token状态
	for token_viz in monitored_tokens:
		var token_item = state_tree.create_item(root)
		token_item.set_text(0, token_viz.token.label)
		
		# 显示Fragment状态
		var fragments_item = state_tree.create_item(token_item)
		fragments_item.set_text(0, "Fragments")
		
		for held_fragment in token_viz.frag_tree.fragments:
			var frag_item = state_tree.create_item(fragments_item)
			frag_item.set_text(0, held_fragment.fragment.label + " x" + str(held_fragment.count))
		
		# 显示当前Act
		if token_viz.current_act:
			var act_item = state_tree.create_item(token_item)
			act_item.set_text(0, "当前Act: " + token_viz.current_act.label)

func highlight_flow_node(act: Act):
	# 在流程图中高亮显示当前执行的Act节点
	flow_graph.highlight_node(act)

func log_event(message: String, color: Color):
	console.push_color(color)
	console.append_text("[" + Time.get_time_string_from_system() + "] " + message + "\n")
	console.pop()
```

## 完整实现roadmap

### 第一阶段：核心框架 (2-3周)
1. **Resource类实现** - Fragment, Card, Aspect, Act, Rule, Test等
2. **基础可视化** - CardViz, TokenViz, SlotViz基本显示
3. **核心逻辑** - Context, FragTree, 基本的执行流程

### 第二阶段：编辑器插件 (3-4周)  
1. **插件框架** - 基本的编辑器插件结构
2. **资源编辑** - 智能属性面板，资源选择器
3. **节点图编辑** - 可视化的Act流程编辑

### 第三阶段：高级功能 (2-3周)
1. **验证系统** - 完整的资源验证和错误检查
2. **调试工具** - 实时状态监控，流程追踪
3. **模板系统** - 预设配置模板，快速创建

### 第四阶段：优化完善 (1-2周)
1. **性能优化** - 对象池，延迟加载
2. **用户体验** - 动画效果，交互反馈  
3. **文档完善** - 使用教程，最佳实践

## 总结

通过这个完整的Godot设计方案，我们实现了：

✅ **完整的架构适配** - Unity概念完美映射到Godot
✅ **强大的可视化工具** - 节点图编辑，智能属性面板  
✅ **实时调试支持** - 状态监控，流程追踪
✅ **开发者友好** - 验证系统，模板库，错误提示
✅ **高度可扩展** - 插件化架构，模块化设计

这个方案不仅解决了原始Unity框架的配置复杂度问题，还充分利用了Godot的优势，为开发者提供了专业级的卡牌游戏开发工具链。
```
