# 恢复开始菜单与镜头逻辑：撤销启动链改道

工程版本 0.1.0（`project.godot` 未改）。目标工程 `I:\_scaffold_test\v323run\ShellStorm2Port`。

## 现象与结论

主人反馈「进游戏后没有开始菜单，镜头逻辑也没移植过来」。

**代码是移植过的，一行都没缺** —— 实测 `src/ui/main_entry/` 四个脚本与源工程
`I:\工作项目\shellstrom2\ShellStorm2\src\ui\main_entry\` **逐字节相同**：

| 文件 | 对比结果 |
| --- | --- |
| `MainEntryScreen3D.gd` | identical |
| `EntryMenuLayout.gd` | identical |
| `EntryNeonButton.gd` | identical |
| `OpeningMovieScreen3D.gd` | identical |
| `scenes/ui/MainEntryScreen3D.tscn` | 仅差 `text = "弹壳风暴 2"` 一行（本日改名） |

问题不在代码，在**启动链被改道了**：

```
StartupLoadingScreen.gd: const TARGET_SCENE = "res://scenes/greybox/GreyboxLevel01.tscn"
```

而开始菜单唯一安装点是 `TowerDescent3D._install_main_entry_screen()`（该文件 659 行调用）。
启动走 greybox ⇒ `TowerDescent3D` 根本没被加载 ⇒ 开始菜单不会出现，近景镜头
（`CLOSEUP_FOV 52` / 距离 3.05m / `roll -7°`）自然也不生效。

改道的直接原因是 `assets/art/environments/`（420M / 4590 文件）被移入
`_removed_content/`（该目录带 `.gdignore`），`TowerDescent3D.tscn` 有 3 个
`ext_resource` 指向它，加载即 Parse Error：

```
res://assets/art/environments/dungeon_3d/env_iron_frontier_kit_top3d_v001.tres
res://assets/art/environments/open_world/runtime/cross_tower_route/env_cross_tower_route_root_top3d.tscn
res://assets/art/environments/tower_zones/base/runtime/zone_base.tscn
```

## 处理（恢复原状，未新写任何游戏代码）

1. `mv _removed_content/assets/art/environments assets/art/environments` —— 4590 文件、
   420M，与源工程文件数逐一相等。这是**移回**，不是重新制作。
2. `StartupLoadingScreen.gd` 的 `TARGET_SCENE` 改回 `res://scenes/TowerDescent3D.tscn`
   （原 PORT-STRIP 注释里自己写的恢复路径）。
3. `--headless --import` 重建导入缓存（必需：420M 资产的 `.import` 产物此前没跟着回来）。

改完 `TowerDescent3D.tscn` 加载**零 Parse Error**。

## 验收（真机 Forward+，1280×720）

真机跑完整启动链，探针挂 `root` 下跨 `change_scene` 存活：

| 检查项 | 实测 |
| --- | --- |
| 启动壳 → 主世界 | `STAGE startup t=0.1` → `STAGE world t=4.0/4.2`，场景 `TowerDescent3D` |
| 开始菜单是否安装 | `MAIN_ENTRY_INSTALLED = true`，脚本 `res://src/ui/main_entry/MainEntryScreen3D.gd` |
| 菜单可见 | `SCREEN_VISIBLE = true`；`Screen/Brand`、`Screen/MenuPanel` 均 present |
| 镜头接管 | `CAMERA_OVERRIDE = true`，`fov=52.00`（= `CLOSEUP_FOV`），`rot=(11.49, 0, 7.0)`（= `CLOSEUP_CAMERA_ROLL_DEG -7°`） |

截图 `entry_menu_live.png`：近景兔子、舞台光柱、地面暖色光斑、99F 基地背景、
「开始游戏 / 设置」按钮、品牌字标全部到位。

**点击「开始游戏」后的镜头插值**（`emit_signal("pressed")` 等价点击）：

| 时刻 | fov | pos | rot |
| --- | --- | --- | --- |
| 点击前 | 52.00 | (0.0, -11.67, 8.05) | (11.49, 0, 7.0) |
| +0.25s | 59.07 | (0.0, -6.25, 9.06) | (-27.38, -1.26, 3.75) |
| +0.50s | 62.95 | (0.0, -3.28, 9.62) | (-48.73, -0.90, 1.69) |
| +0.75s | 64.62 | (0.0, -2.00, 9.86) | (-57.91, -0.24, 0.38) |
| +1.00s | 64.99 | (0.0, -1.71, 9.91) | (-59.97, -0.00, 0.01) |
| +1.25s | 65.00 | (0.0, -1.71, 9.91) | (-60.00, 0, 0) |

⇒ fov 52→65、pitch 11.49°→−60°、roll 7°→0，**1.25s 收敛**（原设计
`TRANSITION_DURATION_S = 1.15`，采样点落在其后首帧），`OVERRIDE_AFTER = false`、
`SCREEN_VISIBLE_AFTER = false` —— 镜头交回、菜单让位，与源工程行为一致。

截图 `after_start_click.png`：正常玩法俯视角 + 完整 HUD，左上角已是「弹壳风暴-青春版」。

## 与既有记录的关系

`2026-10-21_v323_greybox_runtime_reconnect.md` 第 7 行写的「启动链换成原版 Dungeon3D 基座」
**现已不成立** —— 那一轮是为了绕开被移出的 environments，属临时改道。本轮恢复后：
启动链 = `StartupLoadingScreen → TowerDescent3D`，greybox 场景仍在仓库里，
但不再位于启动路径上（`GameDesignConfig.GREYBOX_LEVEL_01_SCENE` 等引用保留，未删）。

该记录第 68 行提到「`scenes/` 下 46 处 `ext_resource` 指向已移入 `_removed_content` 的资源」——
移回 environments 后复扫为 **5 处**，且都不在启动链上：

```
scenes/BaseFacility.tscn      → src/base/BaseFacility.gd, BaseFacilityRenderer.gd
scenes/Container.tscn         → src/game/ContainerInteraction.gd
scenes/DemoRoomChain.tscn     → src/game/DemoRoomGameMode.gd, scenes/GameUIManager.tscn
scenes/RoomBoss.tscn          → src/game/BossRoomLogic.gd, BossRoomPhaseDirector.gd, RoomWaveSpawner.gd
scenes/ThemedNPC.tscn         → src/game/ThemedNPC.gd
```

这些是远古 2D 遗留场景，指向的 `.gd` 本就不存在，与本轮无关，未处理。

## 遗留（明确没做）

- `_removed_content/` 仍剩 60M：`assets/art/enemies/` 与三个
  `scenes/ExpeditionLevel0{1,2,99}_3D.tscn`。**远征关卡是否可进取决于它们**，
  本轮只恢复主人点名的「开始菜单 + 镜头」，未扩大范围。若要一并恢复，说一声即可。
- `assets/audio`（41M）同样在 `_removed_content/assets/` 下未移回 —— 音效/BGM 若缺失同源。
- 未跑 `check_documentation_contracts.py` 之外的全套验证；本轮改动只涉及一个路径常量
  与目录搬迁，未改任何玩法/数值/存档逻辑。
