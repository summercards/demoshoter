# v323run 灰盒工程：启动链回接原版 + 主世界光影基线

> ⚠️ **本轮记录中的「启动链」结论已于同日晚被撤销**
> （见 `2026-10-21_entry_menu_camera_restore.md`）。
> 该轮把启动链改走 greybox，是为绕开被移出的 `assets/art/environments/`；
> 环境资产移回后启动链已恢复为 `StartupLoadingScreen → TowerDescent3D`，
> 因为**开始菜单 `MainEntryScreen3D` 只由 `TowerDescent3D` 安装**，走 greybox 会整个丢掉它。
> 下文灰盒场景本身的改动仍然有效，只是它不再位于启动路径上。

工程版本 0.1.0（`project.godot` 未改）。目标工程 `I:\_scaffold_test\v323run\ShellStorm2Port`；源工程 `I:\工作项目\shellstrom2\ShellStorm2` 全程只读。本轮接续 2026-10-21 上一轮被 usage 上限打断的修复，把隔离副本的改动收尾、验收并回写。

## 问题与改动

### 1. 启动链换成原版 `Dungeon3D` 基座 〔已撤销，见顶部说明〕

`GreyboxLevel01.tscn` / `GreyboxLevel02.tscn` 由 `type="Node3D"` 改为 `instance=ExtResource("2_base")`（`res://scenes/Dungeon3D.tscn`），灰盒脚本只负责空间与表现，战斗、背包、奖励、结算、存档全部回到 `Dungeon3D` 原实现。关卡身份按「初始灰盒 → 回合 99」重定：`greybox_home` / `99`，`next_level_id` 互指，`EXPEDITION_LEVELS` 只留 99，`RogueMapSelectMenu` 的 `LEVEL_IDS` 同口径。

新增 `scenes/greybox/greybox_room.gd`：房间壳体继续由 `greybox_builder` 拥有，`DungeonRoom3D` 的触发器、流送、出生点校验与运行态全部沿用。

`Dungeon3D` 侧只做一处迁移：把 `TowerDescent3D` 的世界时间 HUD 三个函数（`_install_world_time_hud` / `_on_world_time_minute_changed` / `_refresh_world_time_hud`）与 `_world_time_label` 字段下沉到 `Dungeon3D`，灰盒与塔楼共用同一份实现，不再各写一条。

### 2. 主世界光影基线对齐 `TowerDescent3D.tscn`

灰盒代表「主世界」，但 `Dungeon3D._configure_environment()` 给的是封闭战斗房基线（`fog_density` 走 `DungeonTheme3D` 默认 0.075、ambient 压到 0.16~0.22）。新增 `_apply_main_world_environment_baseline()`，逐项对齐原场景 `Environment_editor_runtime_match`：

| 参数 | 值 |
| --- | --- |
| `background_mode` / `background_color` | BG_COLOR / (0.58, 0.62, 0.64) |
| `ambient_light_source` | SKY（原场景 sub_resource 为 3） |
| `ambient_light_color` / `energy` | (0.45, 0.52, 0.60) / 0.01 |
| `tonemap_mode` / `exposure` | FILMIC / 1.18 |
| `fog_light_color` / `energy` / `density` | (0.40, 0.48, 0.55) / 0.36 / 0.04 |
| `fog_height` / `fog_height_density` | 0 / 0（纯距离雾） |

太阳、背景色、环境抬光、屋顶无影补光仍由 `TowerAtmosphere3D` 按 `GameTimeManager` 的太阳快照驱动，基线只改初值，不接管动态部分。

## 渲染器错配（上一轮的假线索）

`project.godot` 是 `config/features=PackedStringArray("4.6", "Forward Plus")`，`renderer/rendering_method.mobile="gl_compatibility"` 只是移动端回落。上一轮的验收脚本写死 `--rendering-method gl_compatibility`，于是出现 TAA / SSDFGI / SSR / SSIL / 体积雾「仅 Forward+ 可用」一整片 WARNING，并把 `material_storage.cpp` 的行号指向 gles3 —— 那一轮据此判断「工程跑在 Compatibility」是错的，工程本身没问题，是验收入口选错了后端。本轮验收统一 `--rendering-method forward_plus`，警告归零（仅保留退出期 ObjectDB 泄漏 WARNING）。

## `Parameter "material" is null` 的定性

在真实 Forward+ 下仍会打印，量随场景切换次数走：单场景 8 条（4 种检查 × 2 个材质），一次完整闭环（基地 → 回合 → 回基地）24 条。已做的隔离实验：

- 裸 `Dungeon3D.tscn` + 主题（不加载灰盒几何、不装 `TowerAtmosphere3D`）：仍 8 条 ⇒ 与灰盒几何、设施、大气模块均无关。
- 完整灰盒分别跳过 floor / walls / cover / safe / enemies / facilities / portal / atmo：8 条恒定，不随任何一段消失。
- 逐实例扫 `GeometryInstance3D`（232 个）：`material_override` 全部有效，`MultiMesh` 的 `surface 0` 材质全部非空，只有 `ImmediateMesh` 的 `VisionProximitySurface` / `FlashlightOverlaySurface` 是 0 表面（`clear_surfaces()` 后引擎仍持有旧 surface RID）。

结论：这是引擎层 `material_storage` 对已释放 surface 引用发的噪声，非本轮改动引入；原工程 `docs/v0.1/development/2026-10-18_synthesis_pity_settlement.md` 已把同一行登记为 `expected_errors` 白名单。**本轮不把它当绿灯，也不写任何白名单掩盖**：真实渲染截图中玩家、敌人、灰盒几何均有正确材质，没有出现实际缺材质的面。

## 验收

隔离副本 `ShellStorm2-work/audits/2026-10-21_v323run_review/runtime_snapshot` 与回写后的目标工程各跑一次同一闭环脚本（22 条断言，真实 Forward+ 渲染器，`APPDATA/LOCALAPPDATA/USERPROFILE` 在 Autoload 前隔离到工程外）：

| 项 | 隔离副本 | 目标工程（回写后） |
| --- | --- | --- |
| 退出码 | 0 | 0 |
| `CHECK` 通过 | 22 / 22 | 22 / 22 |
| `SCRIPT ERROR` | 0 | 0 |
| `material is null` | 24（见上节定性） | 24 |

断言覆盖：`home_ready`、`original_world_owner`（`home is Dungeon3D`）、`inventory_owner`、`inventory_tree`、`original_enemies`（`ActiveEnemies` 子节点是 `Enemy3D`）、`death_reward_owner`、`sun_noon_matches_original`、`time_hud`、`sun_night`、`twenty_minutes_one_day`、`pause_freezes_time`、`time_saved`、`world_drop`、`real_pickup`、`pickup_inventory`（314→321）、`hologram_open`、`depart_round`、`carry_inventory`、`time_across_map`、`original_extraction`（`ExtractionBeacon3D`）、`return_home`、`return_carry`。

主场景单独跑 700 帧：退出码 0、`SCRIPT ERROR` 0、`material is null` 8。

## 门禁

- `scripts/check_level_decoupling.py` 退出 0（7 个通用机制容器，违规 0）。
- `scripts/check_asset_runtime_naming.py` 退出 0（带版本引用计数 tscn 93 → 92，欠账 15 项已消失）。
- `scripts/check_documentation_contracts.py` 退出 1，为**移植存量问题**、非本轮引入：断链集中在 `art_source/` 与 `ShellStorm2-backup/` 下已迁出工程的路径；`VERIFICATION_REGISTRY_FAILED` 为 4 个未登记用例；`MEDIA_ASSET_DOMAINS_FAILED` 187 项为媒体账本域值口径不一致；`FEATURE_TRACEABILITY_FAILED` 1 项为 `ASSET-ROOFTOP` 的验证命令指向 `art_source` 已不在本工程。本轮未改动 `docs/` 下任何既有文件，也未为全绿删设计或放宽阈值。

## 未做

- 雾色不随时间变化（`TowerAtmosphere3D` 的 `FOG_LIGHT_COLOR` 是常量，原工程同源代码亦然）。夜间远处因此偏灰。这是共享模块的既有行为，改动会影响原工程，需用户确认后再动。
- `scenes/` 下仍有 46 处 `ext_resource` 指向已移入 `_removed_content` 的资源（`BaseWorld3D`、`TowerDescent3D`、`open_world_layout_edit` 等非本期启动链场景）。这些场景本轮未加载，故未逐一改空态。
- 未跑全量验证套件，未做手感/逐页输入复核。

## 过程文件

- 改前备份：`I:\工作项目\shellstrom2\ShellStorm2-backup\2026-10-21_v323_runtime_repair\before_writeback\`（9 个文件，含 `manifest.json` 的改前/改后哈希）。
- 日志与脚本：`I:\_scaffold_test\v323run\ShellStorm2-work\sessions\2026-10-21_v323_runtime_repair\`。
- 真实渲染截图：同目录 `user\APPDATA\ShellStorm2Port\greybox_noon.png` / `greybox_night.png`（1280×720）。
