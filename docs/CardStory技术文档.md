# CardStory 卡牌游戏框架设计文档

> 基于Unity版本CardStory插件的完整技术分析，适用于Godot移植

## 概览

CardStory是一个数据驱动的卡牌游戏框架，参考《密教模拟器》的设计理念。核心思想是通过**Fragment（碎片）**作为基础数据单元，通过**Rule（规则）**和**Test（测试）**进行逻辑判定，通过**Modifier（修改器）**执行游戏效果。

### 核心设计原则

1. **数据驱动**：所有游戏逻辑通过ScriptableObject配置，无需编程
2. **组件化**：复杂功能通过简单组件组合实现
3. **延迟执行**：所有修改操作在Context.Dispose()时统一执行，保证原子性
4. **作用域隔离**：通过Context管理执行环境，防止副作用

## 核心架构

### 继承关系图

```
ScriptableObject
├── Fragment (基础碎片)
│   ├── Aspect (属性标签)
│   └── Card (实体卡牌)
├── Act (行动节点)
├── Rule (规则)
├── Slot (插槽)
├── Token (令牌容器)
└── Deck (牌堆)

MonoBehaviour (运行时对象)
├── CardViz (卡牌可视化)
├── TokenViz (令牌可视化)
├── SlotViz (插槽可视化)
├── ActLogic (行动逻辑管理)
└── FragTree (碎片树管理)
```

### 执行流程

1. **Token** 作为容器承载游戏状态
2. **Act** 定义具体的行动和流程节点
3. **Slot** 在Token中打开，接受特定的Card
4. **Test** 进行条件判定，匹配符合条件的Card
5. **Rule** 组合多个Test，定义复杂的逻辑条件
6. **Modifier** 在Rule通过后执行具体的游戏效果
7. **Context** 管理整个执行过程的状态和作用域

## 核心类详解

### Fragment（碎片系统）

Fragment是整个系统的基础数据单元，代表游戏中的任何元素。

```csharp
public class Fragment : ScriptableObject, IFrag
{
    [Multiline] public string label;           // 标识符
    public Sprite art;                         // 显示图像
    public Color color;                        // 备用颜色（无图像时使用）
    public bool hidden;                        // 是否在UI中隐藏
    [TextArea(3, 10)] public string description; // 描述文本
    
    // 组合系统
    public List<Fragment> fragments;           // 子Fragment列表
    
    // 触发器系统
    public List<Rule> rules;                   // Fragment存在时执行的规则
    
    // 插槽系统
    public List<Slot> slots;                   // Fragment存在时尝试打开的插槽
    
    // 牌堆关联
    public Deck deck;                          // 关联的牌堆
    
    // 虚拟方法（由子类实现）
    public virtual void AddToTree(FragTree fg) {}
    public virtual void RemoveFromTree(FragTree fg) {}
    public virtual int AdjustInTree(FragTree fg, int level) { return 0; }
    public virtual int CountInTree(FragTree fg, bool onlyFree=false) { return 0; }
}
```

**设计理念**：
- **组合优于继承**：通过fragments列表实现复杂结构
- **数据与逻辑分离**：Fragment只存储数据，逻辑由Rule处理
- **灵活的触发机制**：通过rules实现Fragment的被动效果

#### HeldFragment（带数量的Fragment容器）

```csharp
[Serializable]
public class HeldFragment : IFrag
{
    public Fragment fragment;                  // 关联的Fragment
    public int count;                         // 数量/强度
    
    // 核心操作方法
    public static int AdjustInList(List<HeldFragment> list, Fragment fragment, int level);
    public int AddToList(List<HeldFragment> list);
    public int RemoveFromList(List<HeldFragment> list);
}
```

**作用**：管理Fragment的数量，支持堆叠、增减等操作。

### Aspect（属性标签）

```csharp
[CreateAssetMenu(menuName = "CardStory/Aspect")]
public class Aspect : Fragment
{
    // 重写Fragment的抽象方法
    public override void AddToTree(FragTree fg) => fg.Add(this);
    public override int AdjustInTree(FragTree fg, int level) => fg.Adjust(this, level);
    public override void RemoveFromTree(FragTree fg) => fg.Remove(this);
    public override int CountInTree(FragTree fg, bool onlyFree=false) => fg.Count(this, onlyFree);
    
    // Aspect特有的列表操作
    public int AdjustInList(List<HeldFragment> list, int level) => HeldFragment.AdjustInList(list, this, level);
}
```

**特点**：
- 代表抽象的属性或状态
- 主要用于逻辑判定和分类
- 不具备独立的可视化表现
- 可以动态添加/移除

### Card（实体卡牌）

```csharp
[CreateAssetMenu(menuName = "CardStory/Card")]
public class Card : Fragment
{
    [Header("Decay - 衰变系统")]
    public Card decayTo;                      // 衰变目标卡牌
    public float lifetime;                    // 衰变时间
    public Rule onDecayComplete;              // 衰变完成时执行的规则
    public Rule onDecayInto;                  // 被衰变为此卡时执行的规则
    
    [Header("Unique - 唯一性")]
    public bool unique;                       // 全局唯一标识
    
    // 重写Fragment的抽象方法
    public override void AddToTree(FragTree fg) => fg.Add(this);
    public override int AdjustInTree(FragTree fg, int level) => fg.Adjust(this, level);
    public override void RemoveFromTree(FragTree fg) => fg.Remove(this);
    public override int CountInTree(FragTree fg, bool onlyFree=false) => fg.Count(this, onlyFree);
}
```

**特点**：
- 代表具体的游戏实体
- 具有独立的生命周期和可视化
- 支持衰变转换机制
- 可以被直接操作（抽取、打出、消耗等）

### Act（行动节点）

Act是游戏流程的核心节点，定义了一个完整的行动过程。

```csharp
[CreateAssetMenu(menuName = "CardStory/Act")]
public class Act : ScriptableObject
{
    public string label;                      // 行动标识
    
    [Header("基础设置")]
    public Token token;                       // 限制执行的Token（可选）
    public bool initial;                      // 是否为初始Act（可被玩家直接触发）
    public float time;                        // 执行时间
    
    [Header("Entry Tests - 进入条件")]
    public List<Test> tests;                  // 必须通过的所有测试
    public List<Rule> and;                    // 必须通过的所有Rule（仅验证，不执行修改器）
    public List<Rule> or;                     // 至少通过一个Rule（仅验证，不执行修改器）
    
    [Header("完成效果")]
    public List<Fragment> fragments;          // 完成后添加的Fragment
    
    [Header("On Complete - 完成时的修改器")]
    public List<ActModifier> actModifiers;    // 游戏状态修改器
    public List<CardModifier> cardModifiers;  // 卡牌修改器
    public List<TableModifier> tableModifiers; // 桌面修改器
    public List<PathModifier> pathModifiers;  // 流程控制修改器
    public List<DeckModifier> deckModifiers;  // 牌堆修改器
    
    [Header("Furthermore - 后续规则")]
    public List<Rule> furthermore;            // 完成后执行的规则（不携带匹配的卡牌）
    
    [Header("Slots - 插槽配置")]
    public bool ignoreGlobalSlots;            // 是否忽略全局插槽
    public List<Slot> slots;                  // Act运行时尝试打开的插槽
    
    [Header("流程控制")]
    // Alt Acts - 可选分支（不生成新Token）
    public bool randomAlt;                    // 是否随机选择分支
    public List<ActLink> altActs;             // 可选分支列表
    
    // Next Acts - 主流程推进（不生成新Token）
    public bool randomNext;                   // 是否随机选择下一个
    public List<ActLink> nextActs;            // 下一个Act列表
    
    // Spawned Acts - 生成新流程（生成新Token）
    public List<ActLink> spawnedActs;         // 生成的新Act列表
    
    [Header("On Spawn - 生成时")]
    public Rule onSpawn;                      // 在新Token中生成此Act时执行的规则
    
    [Header("Text - 文本系统")]
    [TextArea(3, 10)] public string text;     // 主描述文本
    public List<Rule> textRules;              // 文本相关规则
    [TextArea(3, 10)] public string endText;  // 结束描述文本
    public List<Rule> endTextRules;           // 结束文本相关规则
    
    // 核心方法
    public bool Attempt(Context context, bool force = false) => Rule.Evaluate(context, tests, and, or, force);
    public void ApplyModifiers(Context context) => Rule.Execute(context, actModifiers, cardModifiers, tableModifiers, pathModifiers, deckModifiers, furthermore);
}
```

#### ActLink（Act连接器）

```csharp
[Serializable]
public class ActLink
{
    [Tooltip("% chance of attempting this Act. If there is only one element 0% becomes 100%")]
    [Range(0, 100)] public int chance;        // 触发概率（0-100）
    public Act act;                          // 目标Act
    [Tooltip("Rule's tests must pass to attempt this Act. If this is set, 'Chance' field is disregarded.")]
    public Rule actRule;                     // 触发条件（设置后chance失效）
}
```

**Act流程类型**：
1. **Alt Acts**：分支选择，同一层级的不同可能性
2. **Next Acts**：顺序推进，主线剧情的连续执行
3. **Spawned Acts**：并行生成，创建新的Token和流程线

### Rule（规则系统）

Rule组合多个Test和Modifier，实现复杂的条件判断和效果执行。

```csharp
[CreateAssetMenu(menuName = "CardStory/Rule")]
public class Rule : ScriptableObject
{
    [Header("Tests - 条件测试")]
    public List<Test> tests;                  // 必须通过的所有测试
    public List<Rule> and;                    // 必须通过的所有子规则（不执行修改器）
    public List<Rule> or;                     // 至少通过一个子规则（不执行修改器）
    
    [Header("Modifiers - 效果修改器")]
    public List<ActModifier> actModifiers;    // 游戏状态修改器
    public List<CardModifier> cardModifiers;  // 卡牌修改器
    public List<TableModifier> tableModifiers; // 桌面修改器
    public List<PathModifier> pathModifiers;  // 流程控制修改器
    public List<DeckModifier> deckModifiers;  // 牌堆修改器
    
    [Header("Furthermore - 后续规则")]
    public List<Rule> furthermore;            // 此规则通过后执行的其他规则
    
    [TextArea(3, 10)] public string text;     // 规则描述文本
    
    // 核心方法
    public bool Evaluate(Context context) => Evaluate(context, tests, and, or);
    public void Execute(Context context) => Execute(context, actModifiers, cardModifiers, tableModifiers, pathModifiers, deckModifiers, furthermore);
    
    // 静态工具方法
    public static bool Evaluate(Context context, List<Test> tests, List<Rule> and, List<Rule> or, bool force = false);
    public static void Execute(Context context, List<ActModifier> actMods, List<CardModifier> cardMods, List<TableModifier> tableMods, List<PathModifier> pathMods, List<DeckModifier> deckMods, List<Rule> furthermore);
}
```

**规则组合逻辑**：
- `tests` AND `and` AND (`or`中至少一个) = true 时规则通过
- 子规则的Modifier不会执行，仅用于条件判断
- 通过后执行自身的Modifier和furthermore规则

### Test（测试系统）

Test是条件判定的最小单元，实现具体的逻辑比较。

```csharp
// 操作符枚举
public enum ReqOp
{
    MoreOrEqual = 0,        // 大于等于 >=
    Equal = 1,              // 等于 ==  
    LessOrEqual = 2,        // 小于等于 <=
    More = 3,               // 大于 >
    NotEqual = 4,           // 不等于 !=
    Less = 5,               // 小于 <
    RandomChallenge = 10,   // 随机挑战
    RandomClash = 20        // 随机冲突
}

// 位置类型（支持位运算组合）
public enum ReqLoc
{
    Scope = 0,              // 当前作用域
    MatchedCards = 1 << 5,  // 匹配的卡牌
    Slots = 1 << 2,         // 插槽区域
    Table = 1 << 4,         // 桌面区域
    Heap = 1 << 3,          // 堆叠区域
    Free = 1 << 7,          // 可用区域
    Anywhere = 1 << 6,      // 任意位置
}

[Serializable]
public class Test
{
    public bool cardTest;                     // 是否为卡牌相关测试
    public bool canFail;                      // 是否允许失败（柔性条件）
    
    // 左操作数
    public ReqLoc loc1;                       // 第一个位置
    public Fragment fragment1;                // 第一个Fragment
    
    // 操作符
    public ReqOp op;                          // 判定操作符
    
    // 右操作数
    [Tooltip("Fragment2 not set - value. Fragment2 set - multiplier. Accepts negative values.")]
    public int constant;                      // 常数值或乘数
    public ReqLoc loc2;                       // 第二个位置
    public Fragment fragment2;                // 第二个Fragment
    
    // 核心方法
    public bool Attempt(Context context);     // 执行测试
}
```

**测试类型**：
1. **数值比较**：`fragment1`的数量与`constant`比较
2. **Fragment间比较**：`fragment1`的数量与`fragment2*constant`比较
3. **卡牌匹配**：`cardTest=true`时，匹配符合条件的卡牌到`context.matches`

**使用示例**：
```csharp
// 基本数值比较：当前作用域的火焰Aspect数量 >= 3
Test test = {
    fragment1: 火焰Aspect,
    loc1: Scope,
    op: MoreOrEqual,
    constant: 3
};

// Fragment间比较：攻击力 > 防御力
Test test = {
    fragment1: 攻击力Aspect,
    loc1: Scope,
    fragment2: 防御力Aspect,
    loc2: Scope,
    op: More,
    constant: 1  // 乘数
};
```

### Context（执行上下文）

Context是流程执行的临时环境，管理作用域、匹配对象和修改器队列。

```csharp
public class Context : IDisposable
{
    // 执行环境
    public ActLogic actLogic;                 // 当前Act逻辑管理器
    public FragTree scope;                    // 作用域Fragment树
    
    // 上下文对象
    public Fragment thisAspect;               // 当前操作的Aspect
    public CardViz thisCard;                  // 当前操作的卡牌
    public List<CardViz> matches;             // Test匹配到的卡牌列表
    
    // 修改器队列（延迟执行）
    public List<ActModifierC> actModifiers = new List<ActModifierC>();
    public List<CardModifierC> cardModifiers = new List<CardModifierC>();  
    public List<TableModifier> tableModifiers = new List<TableModifier>();
    public List<PathModifier> pathModifiers = new List<PathModifier>();
    public List<DeckModifierC> deckModifiers = new List<DeckModifierC>();
    
    // 销毁队列
    private List<CardViz> toDestroy = new List<CardViz>();
    
    // 构造函数
    public Context(ActLogic actLogic, bool keepMatches = false);
    public Context(FragTree fragments, bool keepMatches = false);
    public Context(CardViz cardViz, bool keepMatches = false);
    public Context(Context context, bool keepMatches = false);
    
    // 核心方法
    public void Dispose();                    // 统一执行所有修改器
    public void Destroy(CardViz cardViz);     // 标记卡牌待销毁
    
    // 解析方法
    public Fragment ResolveFragment(Fragment fragment);
    public Target ResolveTarget(Fragment fragment);
    public List<CardViz> ResolveTargetCards(Target target, FragTree scope);
    public FragTree ResolveScope(ReqLoc loc);
    public int Count(Fragment reference, int defaultValue);
}
```

**核心机制**：
1. **延迟执行**：所有Modifier不立即执行，在Dispose时统一应用
2. **作用域管理**：通过scope限定操作范围
3. **匹配跟踪**：matches列表跟踪Test匹配的卡牌
4. **资源安全**：自动处理销毁和清理操作

### Modifier体系

Modifier是具体效果执行的载体，分为5种类型。每种Modifier都有配置版本和计算版本（带C后缀）。

#### ActModifier（游戏状态修改器）

```csharp
public enum ActOp
{
    Adjust = 0,           // 调整Fragment/卡牌数量
    Grab = 20,           // 抓取/移动卡牌
    SetMemory = 40,      // 设置记忆Fragment
    RunTriggers = 50,    // 触发Fragment的规则
}

[Serializable]
public struct ActModifier
{
    public ActOp op;                          // 操作类型
    public Fragment fragment;                 // 目标Fragment
    [Tooltip("Reference not set - value. Reference set - multiplier. Accepts negative values.")]
    public int level;                         // 操作数值或乘数
    public ReqLoc refLoc;                     // 参考位置
    public Fragment reference;                // 参考Fragment（用于动态计算level）
    
    public ActModifierC Evaluate(Context context); // 计算为执行版本
}
```

#### CardModifier（卡牌修改器）

```csharp
public enum CardOp
{
    FragmentAdditive = 0,  // 添加/移除Fragment到卡牌
    Transform = 10,        // 变形为其他卡牌
    Decay = 100,          // 开始衰变过程
    SetMemory = 140,      // 设置卡牌记忆
}

[Serializable]
public struct CardModifier
{
    public CardOp op;                         // 操作类型
    public Fragment target;                   // 目标Fragment（决定作用于哪些卡牌）
    public Fragment fragment;                 // 操作的Fragment或卡牌
    public int level;                         // 操作数量
    public Fragment reference;                // 参考Fragment（用于动态计算level）
    
    public CardModifierC Evaluate(Context context); // 计算为执行版本
}
```

#### 其他Modifier类型

- **TableModifier**：桌面操作（生成Token、生成Act等）
- **PathModifier**：流程控制（分支跳转、强制Act、回调等）
- **DeckModifier**：牌堆操作（抽牌、加牌、洗牌等）

### Slot（插槽系统）

Slot定义了卡牌的放置位置和接受条件。

```csharp
[CreateAssetMenu(menuName = "CardStory/Slot")]
public class Slot : ScriptableObject
{
    public string label;                      // 插槽标识
    [TextArea(3, 10)] public string description; // 描述文本
    [Tooltip("Fragments will be added to the Act window whenever Card is slotted.")]
    public List<Fragment> fragments;          // 卡牌放入时添加的Fragment
    
    [Header("Spawn - 生成条件")]
    public Token token;                       // 生成的目标Token
    public bool unique;                       // 每个窗口只能开一个
    public bool allTokens;                    // 在所有Token中尝试生成
    public bool allActs;                      // 在所有运行的Act中尝试生成
    
    [Header("Spawn Tests - 生成测试")]
    public List<Test> spawnTests;             // 生成必须通过的测试
    public Rule spawnRule;                    // 生成必须通过的规则
    
    [Header("Accepted Fragments - 接受条件")]
    public List<HeldFragment> required;       // 需要的Fragment（至少一个）
    public List<HeldFragment> essential;      // 必需的Fragment（全部）
    public List<HeldFragment> forbidden;      // 禁止的Fragment（少于指定数量）
    
    [Header("Card Rule - 卡牌规则")]
    public Rule cardRule;                     // 额外的卡牌接受规则
    
    [Header("Options - 选项")]
    public bool acceptAll;                    // 接受所有卡牌
    public bool grab;                         // 自动抓取卡牌
    public bool cardLock;                     // 卡牌锁定（无法移除）
    
    // 核心方法
    public bool Opens(ActLogic actLogic);     // 判断是否应该打开
    public bool Accepts(CardViz cardViz);     // 判断是否接受卡牌
}
```

### Token（令牌容器）

Token是承载游戏状态和Act执行的容器。

```csharp
[CreateAssetMenu(menuName = "CardStory/Token")]
public class Token : ScriptableObject
{
    [Tooltip("Label to display when no Act is running.")]
    public string label;                      // 显示标签
    public Sprite art;                        // 显示图像
    public Color color;                       // 备用颜色
    
    [Header("Description - 描述")]
    [TextArea(3, 10)]
    public string description;                // 描述文本
    public List<Rule> textRules;              // 文本相关规则
    
    [Header("Slot - 插槽")]
    [Tooltip("First Slot to open for this Token when no Act is running.")]
    public Slot slot;                         // 无Act时打开的插槽
    
    [Header("Options - 选项")]
    public bool dissolve;                     // 完成最后一个Act后销毁
    public bool unique;                       // 全局唯一
}
```

### Deck（牌堆系统）

Deck管理卡牌集合，支持抽牌、洗牌等操作。

```csharp
[CreateAssetMenu(menuName = "CardStory/Deck")]
public class Deck : ScriptableObject
{
    public string label;                      // 牌堆标识
    [TextArea(3, 10)] public string text;     // 描述文本
    
    [Header("Fragments - 内容")]
    [Tooltip("Deck content.")]
    public List<Fragment> fragments;          // 牌堆内容
    [Tooltip("Fragment to draw when Deck is empty.")]
    public Fragment defaultFragment;          // 空牌堆时的默认Fragment
    
    [Header("After Draw - 抽牌后")]
    [Tooltip("Fragments added to every Fragment drawn from this Deck.")]
    public List<Fragment> tagOn;              // 为每张抽出的牌添加的Fragment
    public Fragment memoryFragment;           // 记忆Fragment
    
    [Header("Options - 选项")]
    public bool shuffle;                      // 洗牌
    public bool replenish;                    // 耗尽时补充
    public bool infinite;                     // 无限模式（不移除）
    
    // 核心方法
    public Fragment Draw();                   // 抽牌
    public Fragment DrawOffset(Fragment frag, int di); // 相对抽牌
    public void Add(Fragment frag);           // 加牌
}
```

## 数据流设计

### 1. 初始化阶段

```
Token创建 → 打开初始Slot → 等待Card放入
```

### 2. 交互阶段

```
玩家放置Card到Slot → 触发Slot的fragments → 检查Act的entry tests
```

### 3. 执行阶段

```
Act.Attempt(Context) → Rule.Evaluate(tests, and, or) → Test.Attempt(Context)
↓
Act.ApplyModifiers(Context) → Rule.Execute(modifiers) → Context.Dispose()
```

### 4. 流程控制

```
Act完成 → 检查altActs/nextActs/spawnedActs → 创建新的Act或Token
```

### 5. 延迟执行机制

```
Rule执行 → Modifier加入Context队列 → Context.Dispose() → 统一执行所有修改
```

## 记忆机制

记忆机制通过`memoryFragment`在不同层级存储状态信息：

1. **FragTree.memoryFragment**：作用域级记忆
2. **Deck.memoryFragment**：牌堆级记忆  
3. **TokenViz.memoryFragment**：Token级记忆
4. **GameManager.memoryFragment**：全局记忆

使用场景：
- 状态传递：记录上一个行动的结果
- 条件标记：标记某个事件已发生
- 数据暂存：临时存储计算结果

## 最佳实践

### 1. 命名规范

- **Act**：使用动词，如`work`、`sleep`、`buy_flower`
- **Aspect**：使用名词，如`疲劳`、`金钱`、`社交`
- **Card**：使用具体名称，如`工作证`、`咖啡`、`手机`
- **label**：使用英文和下划线，如`work_card`、`fire_aspect`

### 2. 架构设计

- **自底向上**：先创建基础Aspect，再组合成Card，最后设计Act
- **单一职责**：每个Act只负责一个明确的游戏行为
- **数据驱动**：逻辑通过配置实现，避免硬编码

### 3. 测试策略

- **渐进式**：先测试简单的单个Act，再组合复杂流程
- **隔离测试**：使用Context确保测试环境独立
- **边界条件**：测试空值、边界值和异常情况

### 4. 性能优化

- **对象池**：复用Context和CardViz等频繁创建的对象
- **延迟执行**：批量执行修改操作，减少中间状态
- **作用域限制**：合理使用ReqLoc限制搜索范围

## Godot移植指南

### Unity → Godot 概念映射

| Unity概念 | Godot对应概念 | 说明 |
|-----------|---------------|------|
| ScriptableObject | Resource | 数据资源类 |
| MonoBehaviour | Node | 场景节点类 |
| GameObject | Node | 场景对象 |
| Prefab | PackedScene | 预制体 |
| Canvas | Control | UI容器 |

### 核心适配要点

1. **资源系统**：
   - 用Godot的Resource替代ScriptableObject
   - 用`class_name`关键字导出类型
   - 用`@export`替代Unity的字段序列化

2. **场景管理**：
   - 用Node树替代GameObject层级
   - 用Signal替代事件系统
   - 用PackedScene替代Prefab

3. **脚本语言**：
   - 将C#代码转换为GDScript
   - 适配Godot的命名规范（snake_case）
   - 使用Godot的内置类型和方法

4. **UI系统**：
   - 用Control节点替代Canvas系统
   - 适配Godot的锚点和边距系统
   - 重新设计拖放交互逻辑

### 实现优先级

1. **第一阶段**：核心数据结构（Fragment、Card、Aspect、Act等）
2. **第二阶段**：逻辑系统（Rule、Test、Context、Modifier）
3. **第三阶段**：可视化系统（CardViz、TokenViz、SlotViz）
4. **第四阶段**：交互系统（拖放、点击、UI界面）
5. **第五阶段**：管理系统（存档、设置、调试工具）

---

*本文档基于Unity版CardStory插件的源代码分析，为Godot移植提供详细的技术参考。*