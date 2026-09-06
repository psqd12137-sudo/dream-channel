# 频道宿主完整可玩实施计划

> 已被用户纠正的战场范围取代：正式终局必须在本局大地图上。执行以 `2026-09-05-overworld-boss.md` 为准；这里只保留已复用的双轨、破韧和结果原因的设计历史，不代表房内版本已交付。

**Goal:** 将已批准的频道宿主细案接入正式祭坛和隔离试玩，验证双胜利、双失败及可读预告。
**Architecture:** 专属战斗规则置于 channel_host_fight.gd，经 CombatRules 的意图、敌方行动和破韧入口调用；场景继续管理锚、播出及结局。其他 Boss 保持原规则。
**Tech Stack:** Godot 4 / GDScript / SceneTree regression tests.
**Spec:** 本任务中用户批准的频道宿主十节设计；主策划 docs/design/织梦频道_channel_dream_策划案与招标书.md。

## Constraints

- 保留用户地编、资源导入、project.godot 修改；在 codex/channel-host-playable 分支原目录实施，方便直接反馈。
- 5格祭坛外形与副本战斗格分层；在最终可走区域初始化锚及预告。
- 16HP、6韧性、4锚×2操作×2AP、18播出；每轮2+取景1，拆锚减2，破韧每轮最多减1。
- 阶段 HP50%/25% 或锚2/3触发；已预告动作不因阶段切换重瞄。
- 试玩不得修改或清除正式存档。不自动推送。

## Tasks

- [ ] 编写并运行 host_boss_regression.gd，捕捉邻格交互、成本、阶段、播出和不同结局缺失。
- [ ] 新增 channel_host_fight.gd：固定预告追击/冲撞/扫场、取景、破韧、阶段。接入 combat_rules.gd，复用实际移动、陷阱、伤害及回合账本。
- [ ] 更新频道宿主配置及 controller：最终地形后初始化、锚减韧、播出计算、结果原因与回顾。
- [ ] 更新 HUD/renderer：入场规则、下次行动/播出数字、摄影机标记、相邻拆锚；添加不影响正式存档的标题后台试玩入口。
- [ ] 扩展真实回合测试：移动和基础牌通关，预告不漂移、扫场有安全区、破韧取消、两种失败、重复试玩隔离。
- [ ] 运行 Boss/完整流程/回合/测试隔离回归，渲染截图检查；记录玩法操作、验证范围和余项。

## Verification

在独立 APPDATA 目录运行 Godot --headless --path G:/dream-channel/godot --script res://tests/host_boss_regression.gd。首次须观察上述规则断言失败，然后实现再跑。完成时运行现有 boss_progression_regression、complete_run_flow_regression、turn_timing_regression、combat_test_isolation_regression；渲染试玩截图检查 HUD 与危险格。
