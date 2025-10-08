# 游戏机制和平衡性参数配置
# 统一管理所有游戏机制相关的数值参数和平衡性设置
# 不包含样式和动效参数
extends Node

# 动画速度配置
const NORMAL_SPEED: float = 0.5  # 普通动画速度（秒）
const FAST_SPEED: float = 0.2    # 快速动画速度（秒）
const SLOW_SPEED: float = 1.0    # 慢速动画速度（秒）

# 卡牌机制参数
const MAX_HAND_SIZE: int = 7          # 最大手牌数量
const DEFAULT_DECK_SIZE: int = 40     # 默认牌组大小
const MAX_DECK_SIZE: int = 60         # 最大牌组大小
const MIN_DECK_SIZE: int = 20         # 最小牌组大小

# 游戏流程参数
const MAX_TURNS: int = 50             # 最大回合数
const TURN_TIME_LIMIT: float = 60.0  # 回合时间限制（秒）
const DRAW_CARDS_PER_TURN: int = 1    # 每回合抽牌数量

# 战斗机制参数
const BASE_HEALTH: int = 20           # 基础生命值
const MAX_ENERGY: int = 10            # 最大能量值
const ENERGY_PER_TURN: int = 1        # 每回合获得能量

# 特效和反馈参数
const DAMAGE_FEEDBACK_DURATION: float = 0.3  # 伤害反馈持续时间
const HEAL_FEEDBACK_DURATION: float = 0.4    # 治疗反馈持续时间
const CARD_HOVER_SCALE: float = 1.1          # 卡牌悬停缩放比例

# 拖拽和交互参数
const DRAG_THRESHOLD: float = 10.0    # 拖拽触发阈值（像素）
const SNAP_DISTANCE: float = 50.0     # 自动吸附距离（像素）
const DOUBLE_CLICK_TIME: float = 0.5  # 双击时间窗口（秒）

# AI 和难度参数
const AI_THINK_TIME: float = 1.0      # AI 思考时间（秒）
const EASY_AI_MISTAKE_RATE: float = 0.2    # 简单AI失误率
const NORMAL_AI_MISTAKE_RATE: float = 0.1  # 普通AI失误率
const HARD_AI_MISTAKE_RATE: float = 0.05   # 困难AI失误率

# 数据存储和缓存参数
const MAX_SAVE_SLOTS: int = 10        # 最大存档槽位数
const AUTO_SAVE_INTERVAL: float = 30.0  # 自动存档间隔（秒）
const CACHE_SIZE_LIMIT: int = 100     # 缓存大小限制

# 调试和开发参数
const DEBUG_MODE: bool = false        # 调试模式开关
const SHOW_DEBUG_INFO: bool = false   # 显示调试信息
const LOG_GAME_EVENTS: bool = false   # 记录游戏事件日志
