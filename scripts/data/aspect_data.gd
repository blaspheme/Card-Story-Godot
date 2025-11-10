class_name AspectData
extends FragmentData

#region 公开方法
## 将自己加入 FragTree
func add_to_tree(fg: FragTree) -> void: fg.add_aspect(self)

## 在 FragTree 中按数量调整
func adjust_in_tree(fg: FragTree, level: int) -> int: return fg.adjust_aspect(self, level)

## 从 FragTree 中移除
func remove_from_tree(fg: FragTree) -> void: fg.remove_aspect(self)

## 在 FragTree 中计数
func count_in_tree(fg: FragTree, only_free: bool=false) -> int: return fg.count_aspect(self, only_free)

## 在 HeldFragment 列表中调整
func adjust_in_list(list: Array[HeldFragmentData], level: int) -> int:
	return HeldFragmentData.adjust_in_list(list, self, level)

func add_to_list(list: Array[HeldFragmentData]) -> int:
	return adjust_in_list(list, 1)

func remove_from_list(list: Array[HeldFragmentData]) -> int:
	return adjust_in_list(list, -1)

## 返回自身作为 Fragment
func to_fragment():
	return self

## 单位计数
func count() -> int:
	return 1
#endregion
