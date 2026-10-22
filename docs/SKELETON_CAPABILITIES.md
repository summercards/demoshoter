# 骨架能力说明书

状态：**2026-10-21 静态盘点。未运行验证套件 —— 因此本文件的「存在」一律不等于「可用」。**
适用工程版本：`0.1.0`

---

## 0 这份文档回答什么

主设计文档说「玩法未定」，但地基不是空的。这份文档回答唯一一个问题：

> **现在手上到底有哪些积木，哪些是真的，哪些只是文件还在？**

它不写玩法设计，也不写「我们打算做什么」。设计去 `docs/v0.1/design/`，计划去开发记录。

**读法：** 每行都有「证据强度」列。`文件存在` = 只确认了文件在；`接入正式链` = 能从启动链走到；`已实测` = 有本工程的运行记录。

---

## 1 结论先行

| 判断 | 说明 |
|---|---|
| 能跑 | 启动 → 加载页 → 灰盒战斗场景，含真实玩家、胶囊敌人、背包、掉落、撤离读条、存档 |
| 能用但未接 | `src/` 下大量模块完整在位（武器装配树、命运卡、基地设施、存档服务、UI 体系），但**是否接在当前灰盒上，逐个未验** |
| 已剥离 | Boss 模型、房间组件美术源、BGM、远征关卡场景、基地设施美术 |
| 不可信 | 410 个验证脚本大量依赖已剥离资产，**直接跑会红**；`scenes/` 下有 46 处外部引用指向已剥离资源 |

**最重要的一句：** 不要把「`src/` 里有这个文件」当成「这个功能能用」。判定门槛见 §6。

---

## 2 启动链与主入口

| 环节 | 实体 | 证据强度 |
|---|---|---|
| 主场景 | `res://scenes/StartupLoadingScreen.tscn`（`project.godot` `run/main_scene`） | 文件存在 |
| 启动标题 | 「弹壳风暴-青春版」，162 px，-13° 倾斜（`StartupLoadingScreen.gd` 常量） | 文件存在 |
| 目标场景 | `res://scenes/greybox/GreyboxLevel01.tscn`（`TARGET_SCENE` 常量） | 文件存在 |
| 灰盒关卡 | `GreyboxLevel01` / `GreyboxLevel02`，`instance` 自 `scenes/Dungeon3D.tscn` | 已实测（2026-10-21 闭环记录，22/22 断言、退出 0） |

灰盒参数（`greybox_builder.gd` 导出项）：地板 60×60 m、墙高 6 m、墙厚 1 m、6 个掩体、5 个胶囊敌人、出生点 `(0, 1, 20)`、下一关 `99`、白盒设施占位开启。

---

## 3 运行时模块盘点

`src/` 共 24 个模块目录、约 300 个脚本。下表的「证据强度」默认是 `文件存在`，除非另有标注。

| 模块 | 主要构成 | 证据强度 | 备注 |
|---|---|---|---|
| `core/` | `StateMachine`、`AtomicJsonStore`、`GameTimeManager`、`WorldTimeDomain`、`GameManager`、输入与画质管理 | 文件存在；`GameTimeManager` 已实测（时间 HUD、跨图保持、暂停冻结） | 存储层是 `BaseData 2.0` 原子写入 + SHA-256 校验 |
| `base/` | `BaseData`、`ProfileSaveService`、`BaseManager`、`BaseFacilityCatalog`/`Service`、`BaseShopService`、`ItemRegistry`、`BlueprintRegistry` | 已实测（2026-10-21 两进程落盘往返：金币、保险柜、商店、时间） | 设施目录 9 项，99F 实体 8 项 |
| `world3d/` | `Dungeon3D`（关卡基座）、`DungeonRoom3D`、`RoomDoor3D`、`FloorPlanGenerator`（在 `src/map`? 见下）、`ExtractionBeacon3D`、`TowerDescent3D`、`EncounterEvent*`、`SecretBranch3D` | `Dungeon3D` 已实测；其余文件存在 | 灰盒就继承 `Dungeon3D` |
| `player3d/` | `Player3D`、`PlayerAvatar3D`、`PlayerInteractionController3D`、`AimAssist3D`、`PlayerFlashlight3D`、`PlayerVision3D` | 已实测（灰盒内实例化正式玩家） | 顶层状态 8 个 + 覆盖层 |
| `enemy3d/` | `Enemy3D`、`EnemyAvatar3D`、`MonsterAIManager`、`EliteRosterService`、`BossContentCatalog`、`MonitorBoss*` | 灰盒内只有程序化胶囊，**真实敌人模型未接** | Boss 相关的美术资产已剥离 |
| `weapons/` | `WeaponInstance`、`WeaponAssemblyTree`、`FateCardEngine`、`TarotFateCatalog`、`SynthesisCatalog`、`WeaponForge` | 文件存在 | 武器内容注册依赖 `data/` 与 `assets/` |
| `game/` | `InventoryModule`、`LootModule`、`EquipmentTransactionService`、`DeathSettlementModule`、`InsuranceModule`、`FateEconomyService` | 已实测（背包、拾取、结算、下局带入） | 维度无关的玩法模块 |
| `ui/` | 41 个脚本：HUD、背包、各设施菜单、暂停、性能监视、对话 UI、全层地图 | 已实测（贩卖机/改造台菜单注入、背包同源） | 菜单依赖 `set_*` 注入，注入漏了会静默降级 |
| `vfx/` | 45 个脚本 + `VfxPool3D` 自动加载 | 文件存在 | 池化特效 |
| `audio/` | `MusicManager`、`SynthSfx`；`AudioManager` 在 `core/` | 文件存在；BGM 资产已剥离 | 36 项音效的 OGG 是否还在需单独核 |
| `narrative/` | `NarrativeDirector3D` | 文件存在 | 剧本 JSON 在 `data/narrative/` |
| `map/` | `FloorPlanGenerator` 等 9 个 | 文件存在 | 远征关卡的生成逻辑 |
| `rewards/` | `RewardSpec`、`RewardService`、`RuntimeRewardCoordinator` | 文件存在 | 引用关卡掉落表 |
| `training3d/` | 9 个 | 文件存在 | 独立训练场 |
| `open_world/`、`postfx/`、`presentation/`、`framework/`、`i18n/`、`testing/`、`fx/`、`assets/` | 少量脚本 | 文件存在 | — |

---

## 4 灰盒当前能跑通的闭环

依据 `docs/v0.1/development/2026-10-21_v323_greybox_runtime_reconnect.md`（22 条断言、退出码 0、真实 Forward+ 渲染器）：

| 能力 | 断言 |
|---|---|
| 主世界由 `Dungeon3D` 拥有 | `original_world_owner`、`home is Dungeon3D` |
| 背包同源 | `inventory_owner`、`inventory_tree` |
| 真实敌人由原实现产生 | `original_enemies`（`ActiveEnemies` 子节点是 `Enemy3D`） |
| 死亡结算归原实现 | `death_reward_owner` |
| 世界时间与太阳 | `sun_noon_matches_original`、`sun_night`、`twenty_minutes_one_day`、`pause_freezes_time`、`time_saved`、`time_across_map` |
| 掉落与拾取 | `world_drop`、`real_pickup`、`pickup_inventory`（314→321） |
| 撤离 | `original_extraction`（`ExtractionBeacon3D`）、`depart_round`、`return_home`、`return_carry` |
| 设施菜单 | 七个设施逐个 open/close；贩卖机与改造台拿到同一份背包 |

**注意：** 这 22 条断言证明的是「继承的基座还能用」，**不是**「这个玩法是设计目标」。清房间、开箱、撤离这些行为目前是基座自带，留不留、改不改，都还是设计决定。

---

## 5 已剥离内容

`_removed_content/` 共 4670 个文件（有 `.gdignore`，不入包）：

| 类别 | 例子 | 影响 |
|---|---|---|
| Boss 美术 | `enm_boss_monitor002`、`enm_boss_archivist_95`、`enm_boss_furnace_warden_90`、`enm_boss_hollow_choir_85` | `src/enemy3d/MonitorBoss*` 缺模型 |
| 环境组件源 | `tower_zones/expedition` 各房型组件、`base_facility_3d` | 关卡与基地美术不可用；灰盒改用程序化白盒 |
| 基地设施美术 | 自动贩卖机、保险柜、档案室等 | 灰盒用白盒盒体 + 名牌占位 |
| BGM | `rooftop_relax`、`base_passion`、`boss_intense`、`descent_suspense` | 音乐系统缺资产 |
| 关卡场景 | `ExpeditionLevel01/02/99_3D.tscn` | 远征关卡不存在，`LEVEL_IDS` 只剩 `"99"` |
| 音乐源 | 各曲目 `.mp3` 源 | 仅母版保留 |

**需要时怎么恢复：** 见源工程 `I:\工作项目\shellstrom2\ShellStorm2`（只读）。恢复不是简单拷回，要先确认台账版本与运行路径（路径不带版本号）。

---

## 6 什么情况下可以说「这个功能可用」

三道门，缺一不可（`docs/DOCUMENTATION_STANDARD.md` §4 的口径）：

1. **接入正式链** —— 从启动链能走到它，不是只有类、字段或测试桩。
2. **有运行证据** —— 本工程的实测记录，退出码、断言数、渲染器都写明。
3. **文档与代码一致** —— 主设计或能力说明里写的形状，和当前代码对得上。

只满足「文件存在」的，写法是：`存在未验`。

现有的 410 个验证脚本**不能直接当证据**：它们是为原工程写的，大量依赖已剥离资产与远征关卡，直接跑会红。要用某个脚本，先确认它的依赖还在。

---

## 7 想加新玩法时从哪下手

| 你想做的事 | 起点 | 注意 |
|---|---|---|
| 换掉灰盒形状，做自己的关卡 | `scenes/greybox/greybox_builder.gd`（继承 `Dungeon3D`） | 先读 `docs/v0.1/关卡接入规范.md` |
| 不要基座自带的搜打撤 | 替换 `Dungeon3D` 子类或另行继承 | 存档、结算、背包都挂在基座上，拆之前先看 `src/game/` 与 `src/base/` |
| 用现成的背包/武器/存档 | `src/game/` + `src/base/` | 先跑通最小闭环再谈玩法设计 |
| 加新关卡 | `data/level_plans/` + `FloorPlanGenerator` | 通用机制按能力分支、专属按 ID 分支，跑 `check_level_decoupling.py` |
| 接美术 | `assets/art/` 现有 199 glb / 228 tscn | 路径不带版本号，跑 `check_asset_runtime_naming.py` |

---

## 8 本文件怎么维护

- 只在**盘点事实变化**时改：新增模块、剥离内容、实测通过。不写计划。
- 「证据强度」升级必须附来源：开发记录文件名或验证脚本名 + 运行条件。
- 不确定的一律写 `存在未验`。宁可低估，不可高估 —— 高估的代价是有人拿它当基础去设计玩法。
