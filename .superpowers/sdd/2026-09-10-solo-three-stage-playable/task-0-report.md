# Task 0 reviewer fix report

日期：2026-09-10

首轮审查发现并修复了四项实现缺口：

- 正式参考工坊默认关闭景深；景深作为对比开关时限制为弱景深，不遮挡门洞和接口。
- 工坊程序生成的盒体装饰统一加入 `workshop_decor`，并在回归中确认不进入 `room_prop`。
- 参考工坊测试面板增加“正式工坊预览”按钮，依次进入工坊、电视梦境和返回现实工坊。
- 样片退出时恢复工坊前的环境、主辅灯、相机、角色变换、景深和房间逻辑存档。

同时在正式 Profile 中记录中心底座与绿色切割垫尺寸，并保留 C 参考工坊测试入口。

验证命令（Godot 4.7.1 console）：

```powershell
& 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/toyhouse_tactile_lab_regression.gd
& 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/formal_cartoon_assembly_regression.gd
& 'D:\godot\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'G:\dream-channel\godot' --script res://tests/formal_workshop_regression.gd
```

结果：三项均 `PASS`。
