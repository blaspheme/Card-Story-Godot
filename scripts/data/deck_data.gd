class_name DeckData
extends Resource

@export var label: String
@export_multiline var text: String

@export_category("Fragments")
## 牌堆的内容片段（Fragment 资源列表）
@export var fragments: Array[FragmentData]
## 当牌堆为空时抽到的默认片段
@export var default_fragment: FragmentData

@export_category("抽取后附加")
## 从此牌堆抽到某个片段后，应额外添加到该片段上的片段列表
@export var tag_on: Array[FragmentData]
## 抽牌时使用的 memory fragment（可为空）
@export var memory_fragment: FragmentData

@export_category("Options")
## 是否在初始化/补充时随机洗牌
@export var shuffle: bool = false
## 用尽后是否从已丢弃/备份处补充
@export var replenish: bool = false
## 抽牌不从牌堆内移除（无限抽取）
@export var infinite: bool = false
## 每次抽牌是否随机选择（与 shuffle/replenish 结合使用）
@export var random: bool = false
