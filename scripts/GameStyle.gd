# 游戏调色盘和样式配置
# 统一管理所有颜色、字体、UI样式等视觉相关设置
extends Node

# 主色调配置
const PRIMARY_COLOR: Color = Color("#2C3E50")      # 主要颜色（深蓝灰）
const SECONDARY_COLOR: Color = Color("#3498DB")    # 次要颜色（蓝色）
const ACCENT_COLOR: Color = Color("#E74C3C")       # 强调颜色（红色）
const SUCCESS_COLOR: Color = Color("#27AE60")     # 成功颜色（绿色）
const WARNING_COLOR: Color = Color("#F39C12")     # 警告颜色（橙色）
const ERROR_COLOR: Color = Color("#E74C3C")       # 错误颜色（红色）

# 背景色配置
const BG_PRIMARY: Color = Color("#ECF0F1")         # 主背景色（浅灰）
const BG_SECONDARY: Color = Color("#BDC3C7")      # 次背景色（中灰）
const BG_DARK: Color = Color("#34495E")           # 深色背景
const BG_LIGHT: Color = Color("#FFFFFF")          # 浅色背景

# 文字颜色配置
const TEXT_PRIMARY: Color = Color("#2C3E50")       # 主要文字颜色
const TEXT_SECONDARY: Color = Color("#7F8C8D")    # 次要文字颜色
const TEXT_LIGHT: Color = Color("#FFFFFF")        # 浅色文字
const TEXT_DISABLED: Color = Color("#95A5A6")     # 禁用文字颜色

# 卡牌颜色配置
const CARD_BG_DEFAULT: Color = Color("#FFFFFF")    # 默认卡牌背景
const CARD_BG_RARE: Color = Color("#3498DB")      # 稀有卡牌背景
const CARD_BG_EPIC: Color = Color("#9B59B6")      # 史诗卡牌背景
const CARD_BG_LEGENDARY: Color = Color("#F39C12") # 传说卡牌背景
const CARD_BORDER_DEFAULT: Color = Color("#BDC3C7")   # 默认卡牌边框
const CARD_BORDER_SELECTED: Color = Color("#3498DB") # 选中卡牌边框
const CARD_BORDER_HOVER: Color = Color("#2ECC71")    # 悬停卡牌边框

# UI 元素颜色
const BUTTON_NORMAL: Color = Color("#3498DB")      # 普通按钮
const BUTTON_HOVER: Color = Color("#2980B9")      # 悬停按钮
const BUTTON_PRESSED: Color = Color("#21618C")    # 按下按钮
const BUTTON_DISABLED: Color = Color("#95A5A6")   # 禁用按钮

# 状态指示颜色
const HEALTH_FULL: Color = Color("#27AE60")       # 满血状态
const HEALTH_MEDIUM: Color = Color("#F39C12")     # 中血状态
const HEALTH_LOW: Color = Color("#E74C3C")        # 低血状态
const MANA_COLOR: Color = Color("#3498DB")        # 魔法值颜色
const ENERGY_COLOR: Color = Color("#F1C40F")      # 能量值颜色

# 特效颜色配置
const DAMAGE_EFFECT: Color = Color("#E74C3C")     # 伤害特效颜色
const HEAL_EFFECT: Color = Color("#27AE60")       # 治疗特效颜色
const BUFF_EFFECT: Color = Color("#3498DB")       # 增益特效颜色
const DEBUFF_EFFECT: Color = Color("#8E44AD")     # 减益特效颜色

# 透明度配置
const ALPHA_DISABLED: float = 0.5      # 禁用状态透明度
const ALPHA_HOVER: float = 0.8         # 悬停状态透明度
const ALPHA_SELECTED: float = 1.0      # 选中状态透明度
const ALPHA_OVERLAY: float = 0.7       # 覆盖层透明度

# 阴影和光效配置
const SHADOW_COLOR: Color = Color("#000000", 0.3)     # 阴影颜色
const GLOW_COLOR: Color = Color("#FFFFFF", 0.8)       # 发光颜色
const OUTLINE_COLOR: Color = Color("#2C3E50")         # 描边颜色

# 渐变配置
const GRADIENT_PRIMARY: Array[Color] = [Color("#3498DB"), Color("#2980B9")]    # 主渐变
const GRADIENT_SECONDARY: Array[Color] = [Color("#27AE60"), Color("#229954")] # 次渐变
const GRADIENT_WARNING: Array[Color] = [Color("#F39C12"), Color("#E67E22")]   # 警告渐变
const GRADIENT_ERROR: Array[Color] = [Color("#E74C3C"), Color("#C0392B")]     # 错误渐变

# 获取卡牌稀有度颜色
static func get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common", "普通":
			return CARD_BG_DEFAULT
		"rare", "稀有":
			return CARD_BG_RARE
		"epic", "史诗":
			return CARD_BG_EPIC
		"legendary", "传说":
			return CARD_BG_LEGENDARY
		_:
			return CARD_BG_DEFAULT

# 获取血量对应颜色
static func get_health_color(current_health: int, max_health: int) -> Color:
	var health_ratio: float = float(current_health) / float(max_health)
	if health_ratio > 0.6:
		return HEALTH_FULL
	elif health_ratio > 0.3:
		return HEALTH_MEDIUM
	else:
		return HEALTH_LOW

# 获取带透明度的颜色
static func get_color_with_alpha(color: Color, alpha: float) -> Color:
	var result = color
	result.a = alpha
	return result
