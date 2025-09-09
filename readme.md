# 实现说明

将 C:\workspace\game\test3\Assets\Cultistlike 这个unity插件使用godot实现，需要增加一个可调试的可视化工具，按照 `AGENTS.md` 的规则去实现。

对于这个可视化工具，我希望实现：

- Godot中的Scriptable脚本，我希望通过Resource文件实现
- 可以查看例如Token、Act、Rule、Slot、Card的流转关系，可以直接运行，DEBUG，增加、删除各种定义的Resource文件

将这个插件和可视化工具做成一个godot插件