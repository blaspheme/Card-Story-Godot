extends Node
class_name UIManager

## UI 管理器：管理游戏中的所有 UI 组件引用
## 通过 Manager.UI 访问

#region UI 组件引用
## 卡牌信息面板
@onready var card_info: CardInfo = $"../../UI/CardInfo"
## 碎片信息面板
@onready var aspect_info: AspectInfo = $"../../UI/AspectInfo"
#endregion

#region 生命周期
func _ready() -> void:
	# 验证必需的 UI 组件
	assert(card_info != null, "UIManager: CardInfo 组件不能为 null")
	assert(aspect_info != null, "UIManager: AspectInfo 组件不能为 null")
	Manager.UI = self
#endregion
