# 环境资产全移出 + 开场 UI/镜头挂进原灰盒场景

工程版本 0.1.0。接续 `2026-10-22_entry_asset_minimization.md`。

## 主人的决定

「先全部去掉，只把镜头动画和逻辑，还有 ui 挪回来」→ 随后又指定「用原来的灰盒场景」。

前一轮我按「最小化」把 environments 收到 319M；本轮改为**整目录移出**，
并把原版开场 UI 挂到**原灰盒主场景**上，不再自建舞台。

## 做了什么

| 项 | 结果 |
| --- | --- |
| `assets/art/environments` | **整目录移出**到 `I:\_scaffold_test\v323run\_env_hold\environments`（420M / 4590 文件，**未删**） |
| 启动链 | `StartupLoadingScreen` → `res://scenes/greybox/GreyboxLevel01.tscn` |
| 开场 UI | `MainEntryScreen3D.tscn` 作为**原场景实例**挂在 `GreyboxLevel01.tscn` 根下 |
| `MainEntryScreen3D.gd` | **零改动**（逐字节与源工程一致） |
| `EntryMenuLayout / EntryNeonButton / OpeningMovieScreen3D` | 零改动 |
| `Player3D` | 零改动，沿用 `Dungeon3D.tscn` 里的静态子节点 |

中途试过自建 `scenes/EntryStage3D.tscn`（只实例化 Player3D + MainEntryScreen3D），
按主人「不要自己写代码」的要求**已删除**，改挂原灰盒场景。

## 为什么不需要写代码驱动镜头

三条都是原资产自带的行为，不是新写的：

1. `MainEntryScreen3D` 的 `@export auto_present_when_player_found` 默认 `true`，
   `_ready` 里 `call_deferred("_auto_present")`。
2. `_auto_present()` 用 `get_tree().get_first_node_in_group("player_3d")` 找玩家；
   `Dungeon3D.tscn` 的 `Player3D` 是静态子节点，`_ready` 时已在组内，时序天然成立。
3. `present()` 不传 `gameplay_transform` 时，把**当前相机姿态**记为玩法姿态
   （`MainEntryScreen3D.gd:305-306`），所以镜头插值的终点就是 Player3D 自带的
   `Camera3D`（fov 43 / pitch −52°）。无需外部赋值。

## 验收（真机 Forward+ 1280×720）

**开场接管（连测 8 秒不漂）**：

```
t=0.4  presenting=true  narr_hold=false  fov=52.0  pos=(0.0, 0.300364, 23.05)
...
t=8.0  presenting=true  narr_hold=false  fov=52.0  pos=(0.0, 0.300364, 23.05)
```

`fov 52.00` = `CLOSEUP_FOV`；`rot z = 7.0°` = `CLOSEUP_CAMERA_ROLL_DEG`。

**点击「开始游戏」后的插值**：

| 时刻 | fov | pos | rot |
| --- | --- | --- | --- |
| 点击前 | 52.00 | (0.0, 1.06, 23.05) | (11.49, 0, 7.0) |
| +0.25s | 47.08 | (0.0, 9.80, 28.49) | (−23.22, −1.07, 3.58) |
| +0.50s | 44.44 | (0.0, 14.74, 31.41) | (−41.83, −0.71, 1.53) |
| +0.75s | 43.28 | (0.0, 16.96, 32.69) | (−50.01, −0.18, 0.34) |
| +1.00s | 43.00 | (0.0, 17.50, 33.00) | (−52.00, 0, 0) |

⇒ `OVERRIDE_AFTER = false`、`SCREEN_VISIBLE_AFTER = false`，镜头交回、菜单让位，
HUD 正常显示（左上角「弹壳风暴-青春版 | 向下，寻找世界的答案」）。

**资源缺失**：`Resource file not found` **0 条**。
**既有基线**：`Parameter "material" is null` **8 条** —— 与 10-21 记录第 64 行
「主场景单独跑 700 帧…`material is null` 8」完全一致，非本轮引入。

## 副作用与代价（必须知道）

1. **开场背景变成灰盒白模**。原版是 99F 基地实景（BASE CAMP 墙、柜子），
   现在只有程序化白盒方块 + 舞台光柱 + 地面光斑。这是「去掉资产」的直接结果，
   不是 bug。要恢复到实景开场，把 `_env_hold/environments` 移回并重跑 `--import` 即可。
2. **硬 preload 残留 1 处**：`src/world3d/BossRoom02ArenaGate3D.gd` 仍 `preload`
   远征目录下的护栏 prefab。该脚本有 `class_name`，但**不在灰盒启动链上**，
   实测启动零报错，故本轮不动（改它属于远征逻辑，超出范围）。
3. `TowerDescent3D.tscn` 仍有 3 个 `ext_resource` 指向 environments。
   它不在启动路径上，不被加载；要进塔楼必须先移回环境资产。

## 回滚路径

```
把 I:\_scaffold_test\v323run\_env_hold\environments 移回
I:\_scaffold_test\v323run\ShellStorm2Port\assets\art\environments
然后 --headless --import
再把 StartupLoadingScreen.gd 的 TARGET_SCENE 改回 res://scenes/TowerDescent3D.tscn
```
