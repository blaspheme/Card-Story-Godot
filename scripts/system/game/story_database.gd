class_name StoryDatabase

# ===============================
# 游戏运行时依赖的数据数据库
# ===============================
static var cards: Array[CardData]

## 扫描指定路径，加载全部数据
static func from_scan():
	pass

## 赋值构建
static func from_value():
	pass

## 通过编辑器指定构建
static func from_editor():
	pass
