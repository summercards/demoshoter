# 设施菜单接口回接原工程：贩卖机背包与武器改造台

工程版本 0.1.0（`project.godot` 未改）。目标工程 `I:\_scaffold_test\v323run\ShellStorm2Port`；源工程 `I:\工作项目\shellstrom2\ShellStorm2` 全程只读（本轮未写入任何一个字节）。

## 现象与定位

用户报告两件事：I 键背包与自动贩卖机里的背包内容不一致；武器改造台 UI 不对且同样没有接口。

先做只读比对，结论是**实现层零差异、接线层断了一条**：

- `src/ui/BaseVendingMenu.gd`、`src/ui/WorkshopMenu.gd`、`src/ui/WorkbenchMenu.gd`、`src/ui/WorkbenchPanel.gd`、`src/ui/InventoryUI.gd`、`src/ui/GridInventoryBoard.gd`、`src/game/InventoryModule.gd`、`src/base/BaseManager.gd`、`src/base/ProfileSaveService.gd`、`src/core/GameTimeManager.gd` —— 与原工程**逐字节相同**（SHA-256 一致）。
- 断点在打开链路。原工程上 99F 基地走 `TowerDescent3D._open_facility_menu()`，它按注释契约依次注入 `set_inventory_module` / `set_player` / `set_facility` 后才 `add_child`。灰盒 `greybox_builder.gd` 自己写了一份 `_open_menu()`（抄的是 `BaseWorld3D._open_menu`），**只注入 player 和 facility，漏了 inventory_module**。

后果正是用户看到的两处：

1. `BaseVendingMenu._refresh()` 里有一句 `var owner := "loadout" if _sell_owner == "inventory" and _inventory_module == null else _sell_owner`。`_inventory_module` 为 null 时它静默降级到 `loadout`（下局带入）页 —— 于是贩卖机里看到的不是本次运行的背包。购买也走 `purchase_base_shop_item()`（进下局带入）而不是 `purchase_base_shop_item_to_inventory()`。
2. `WorkbenchMenu` 的三个 setter 存字段、`_ready()` 转发给 `WorkbenchPanel`；`WorkbenchPanel._resolve_inventory()` 通过 `get_inventory_module()` 反查。没注入就是 null，面板的 ALCHEMY GRID 右側背包区空白 —— 看起来"UI 坏了"，实际是依赖没接上。

## 改动

### 1. `_open_facility_menu` 下沉到 `Dungeon3D`

灰盒与 99F 基地同为 `Dungeon3D` 子类、都会开设施菜单，所以把原 `TowerDescent3D._open_facility_menu()` 与 `_on_active_facility_menu_closed()` 原样移到基类，`_active_facility_menu` 字段一并下沉。

**函数体与原工程逐字节相同**（SHA-256 `17f514f514f61b67`，双方各 21 行；`_on_active_facility_menu_closed` 同样一致）。不是重写，是搬家。

`TowerDescent3D` 侧删掉这三段（字段 + 两个函数），`_has_exclusive_modal()` 里设施菜单那一项也删掉 —— 基类已经判了，子类保留 `super()` 即可，不会漏也不会重。

### 2. 灰盒设施激活改走原版分工

`_on_greybox_facility_activated()` 按 `TowerDescent3D._on_facility_activated()` 重写：活跃菜单挡重复触发 → 状态栏写设施自述 → `OPEN_MENU` 调 `_open_facility_menu()` → `LOAD_SCENE` 切场景。

菜单路径取 `facility.menu_scene_path`，不再自行从快照里取 `action_path`。`BaseFacility3D._apply_catalog_definition()` 已在 `_ready` 按 `BaseFacilityCatalog` 补齐 `activation_type` 与 `menu_scene_path`，与原工程各设施 prefab 里写的值同源。

### 3. 删除灰盒自建的 `_open_menu` / `_active_menu` / `_refresh_greybox_facilities`

`_open_menu()` 是漏注入的源头，`_active_menu` 与它成对，一并删除；`_refresh_greybox_facilities()` 唯一调用点就在被删的关闭回调里，且 `BaseFacility3D` 自己在 `get_interaction_candidate()` 与 `perform_interaction()` 两处都会 `apply_snapshot()`，删掉不影响可用性刷新。

### 4. 验收脚本跟随实现

`repair_loop.gd` 第 80 行由 `_open_menu` 改为 `_open_facility_menu`（取 `menu_scene_path`），第 84 行由 `_active_menu` 改为 `_active_facility_menu`。这是测试适配，不是产品行为变更。

## 存档链路的核对结论

用户把现象描述为"存档接口好像没有对上"。逐项核对后确认**存档链路没有偏差**：

- `src/base/ProfileSaveService.gd`、`src/base/BaseManager.gd`、`src/base/BaseData.gd`、`src/base/BaseShopService.gd`、`src/base/BaseEnergyService.gd`、`src/base/BaseFacilityService.gd`、`src/core/GameTimeManager.gd` 全部与原工程 SHA 一致。
- `scenes/StartupLoadingScreen.gd` 只有一处差异：`TARGET_SCENE` 指向灰盒（移植既定决定），与存档无关。
- `project.godot` 只有一处差异：`config/use_custom_user_dir=true` + `config/custom_user_dir_name="ShellStorm2Port"`。这是刻意的存档隔离，避免移植工程覆盖原工程存档 —— **属于必要的偏差，且方向是保护原工程存档**。

两进程真实落盘往返实测（同一 user 目录、独立进程、真实 Forward+ 渲染器）：

| 断言 | 写入进程 | 重启后读取进程 |
| --- | --- | --- |
| 金币 | 4321 | 4321 ✓ |
| 保险柜 `item_ammo_pack` | 17 | 17 ✓ |
| 商店货架 | — | 7 项 ✓ |
| 时间域 `flush_to_profile` | true | 读回 7239.6 秒 |

时间读回 7239.6 而写入值 7200，是 `GameTimeManager` 在载入后照常走表（`86400/1200 = 72` 游戏秒每真实秒，间隔约 0.55 秒 → 39.6 秒），不是存档偏差。落盘文件 `user://base_save.json` 24,637 字节，含 `manifest_version` / `payload` / `payload_checksum` / `payload_checksum_algorithm` / `profile_schema` / `revision` 等字段，与 `ProfileSaveService` 的约定一致。

## 验收

真实 Forward+ 渲染器，`APPDATA/LOCALAPPDATA/USERPROFILE` 在 Autoload 前隔离到工程外，两套脚本均已删除（不留在工程里）。

**设施接口专项 `FACILITY_MENU_RESULT failures=0`，退出 0，`SCRIPT ERROR` 0：**

| 组 | 断言 |
| --- | --- |
| 背包同源 | `i_key_inventory_same_module`（`InventoryUI._inventory_module == get_inventory_module()`） |
| 贩卖机 | `vending_menu_path`、`vending_activation_open_menu`、`vending_inventory_injected`（同一 RefCounted 实例）、`vending_sell_owner_inventory`、`vending_sell_model_is_run_inventory`、`vending_capacity_matches`、`vending_input_locked`、`vending_closed_clears_ref`、`vending_closed_unlocks` |
| 改造台 | `forge_menu_path`、`forge_inventory_injected`、`forge_player_injected`、`forge_facility_injected`、`forge_panel_exists`、`forge_panel_inventory`、`forge_hides_hud`、`forge_closed_restores_hud`、`forge_closed_clears_ref` |
| 七个设施 | `mission_operations` / `weapon_workshop` / `vault` / `monster_archive` / `fate_collection` / `base_recovery` / `avatar_wardrobe` 逐个 open + close + 路径比对；凡声明 `set_inventory_module` 的（`VaultMenu`）均拿到同一份背包 |

**闭环回归 `REPAIR_RESULT failures=0`，22/22 通过，退出 0，`SCRIPT ERROR` 0：** `home_ready`、`original_world_owner`、`inventory_owner`、`inventory_tree`、`original_enemies`、`death_reward_owner`、`sun_noon_matches_original`、`time_hud`、`sun_night`、`twenty_minutes_one_day`、`pause_freezes_time`、`time_saved`、`world_drop`、`real_pickup`、`pickup_inventory`、`hologram_open`、`depart_round`、`carry_inventory`、`time_across_map`、`original_extraction`、`return_home`、`return_carry`。

真实渲染截图两张（1280×720，`ShellStorm2-work/sessions/2026-10-21_v323_runtime_repair/target_user/APPDATA/ShellStorm2Port/`）：

- `vending_inventory_tab.png`：贩卖机右侧"背包 1/40 格"，格内是本次运行的通用弹药 ×17；购买按钮按 `_inventory_module != null` 走背包分支。
- `forge_workbench.png`：改造台 ALCHEMY GRID 5×5，右側"背包（1/40 格）"同一份弹药，底部 PAYLOAD/MELT/RARITY/RECIPE/BLUEPRINT/GRADE ODDS/FEE 全部渲染，无空白依赖。

## 与原工程的行为一致性

- 菜单场景路径全部取 `BaseFacilityCatalog` → `BaseFacility3D._apply_catalog_definition()`，与 `zone_base.tscn` / `env_base99_remaining_facilities` 下各设施 prefab 里写的值一致。
- 打开顺序（set_* 在 `add_child` 之前）、`BaseMenu.overlay_mode`、`tree_exited` 关闭回调、`_sync_player_input_lock()` 全部沿用原实现。
- 贩卖机打开时基地 HUD 仍然透出：`BaseVendingMenu` 本来就没有 `_hide_gameplay_hud`（只有 `WorkbenchMenu` 与 `WardrobeMenu3D` 有），这是原工程行为，本轮**未擅自修改**。

## 未做

- 灰盒白盒设施的空间布局、外形、名牌尺寸未调整（不在本次接口范围）。
- `scenes/` 下仍有 46 处 `ext_resource` 指向 `_removed_content` 的非启动链场景，未改空态。
- 未跑全量验证套件。

## 过程文件

- 改前备份：`I:\工作项目\shellstrom2\ShellStorm2-backup\2026-10-21_v323_facility_menu_contract\before_edits\`（`Dungeon3D.gd`、`TowerDescent3D.gd`、`greybox_builder.gd`）。
- 日志：`I:\_scaffold_test\v323run\ShellStorm2-work\sessions\2026-10-21_v323_runtime_repair\`（`facility_all.log`、`regression3.log`、`save_write.log`、`save_read.log`）。
- 门禁：`check_level_decoupling.py` 退出 0（7 个通用机制容器，违规 0）；`check_asset_runtime_naming.py` 退出 0（带版本引用计数 tscn 93 → 92）。
