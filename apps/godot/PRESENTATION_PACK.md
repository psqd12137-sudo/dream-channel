# 表现资产包导入

状态：Godot 技术接口。

当前战斗角色不再绑定某一张贴图。`data/presentation_manifest.json` 是唯一的表现资产入口，战斗规则脚本只发出 `idle / move / ready / attack / hurt` 状态。

## 一键导入

把资产包文件夹拖到 `tools/import_presentation_pack.cmd` 上。脚本会复制素材、校验角色待机帧、更新 manifest，并把旧 manifest 保存为 `.bak`。回到 Godot 后等待自动导入即可，不需要修改战斗代码。

资产包结构：

```text
my_pack/
  pack.json                         # 可选；至少可写 { "id": "my_pack" }
  actors/
    player/
      actor.json                    # 可选：pixel_size、visual_y、各动画 fps/loop
      idle/001.png ...
      move/001.png ...              # 可选
      ready/001.png ...             # 可选
      attack/001.png ...            # 可选
      hurt/001.png ...              # 可选
    enemy/
      idle/001.png ...
      attack/001.png ...
      hurt/001.png ...
  items/
    jab.png                         # 文件名必须等于卡牌/物品 id
  decor/
    door.png                        # 文件名必须等于装饰 id
```

`actor.json` 示例：

```json
{
  "pixel_size": 0.0018,
  "visual_y": 0.9,
  "animations": {
    "idle": { "fps": 8, "loop": true },
    "attack": { "fps": 12, "loop": false },
    "hurt": { "fps": 10, "loop": false }
  }
}
```

若 `move / ready / attack / hurt` 没有正式逐帧，框架会继续使用已有待机帧，并叠加跳跃、蓄力、冲刺、闪红等程序动画。以后补入同名文件夹后会自动优先播放正式逐帧，程序动画仍作为动作力度反馈保留。

## 运行时映射

- 移动成功：玩家 `move`。
- 选中需要落点的道具：玩家 `ready`。
- 道具/攻击成功：发起方 `attack`。
- 生命值实际下降：承受方 `hurt`。
- 敌人巡视即使不在玩家视野内也会更新其状态；未被揭示时保持暗影显示，不泄露精确信息。

装饰和道具也通过同一个 manifest 查找，后续可以在不改规则层的情况下替换为正式角色、场景微缩模型、特效和 UI 插图。

## 3D 房间布景

房间中的 3D 家具不走 2D 角色表现包，而由 `scripts/room_art_registry.gd` 单独配置。首轮资产位于 `assets/quaternius/ultimate_house_interior/`，来源和 CC0 许可见该目录的 `SOURCE.md` 与 `LICENSE.txt`。

布景注册表只接受房间 ID、模型路径、局部位置、Y 轴旋转与统一缩放。它不会修改房间门向、格子坐标或战斗规则；未知房和缺少配置的房间继续显示原有纸盒白盒。
