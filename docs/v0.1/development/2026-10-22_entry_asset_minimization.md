# 开场 UI 与镜头的资产依赖核算：把 environments 从 420M 收到 319M

工程版本 0.1.0。接续 `2026-10-21_entry_menu_camera_restore.md`。

## 主人的质疑

「我不要这些资产啊，我只要摄像机镜头和开场的 ui 怎么给我弄回来了？」

质疑成立的部分：我上一轮把 **420M / 4590 文件**整个 `environments` 移回，
但主人的目标只是「开始菜单 + 镜头」。我确实扩大了范围。

质疑不成立的部分：**开场 UI 不是一个独立界面，它没有自己的美术资产。**
`MainEntryScreen3D.gd` 扫描结果为 **零个 `res://assets/...` 引用** —— 它的做法是
「把真实游戏场景当背景，用 SpotLight3D + 光柱 + 地面光斑打灯，然后把玩家的相机
推到近景」。截图里那面 BASE CAMP 墙、MEDICAL / TOOLS 柜、地板，全是活的 99F 基地场景。
所以「只要 UI 不要资产」在技术上不成立：**背景本身就是资产**。

## 于是改为「按需最小化」，而不是全有或全无

`environments` 内各目录实测体积：

| 目录 | 体积 | 开场是否需要 |
| --- | --- | --- |
| `base_facility_3d` | 144M | **需要** —— 开场背景的主体（BASE CAMP 墙、柜、结构件） |
| `open_world/components` | 107M | **需要** —— 塔楼楼层本体（`tower_02/floor_*`），移掉不报错但塔是空壳 |
| `tower_descent_3d` | 43M | **需要** —— 塔楼墙 / 地砖 / 楼梯间 |
| `open_world/runtime` | 9.6M | **需要** —— `cross_tower_route`，`TowerDescent3D.tscn` 的 ext_resource |
| `master_office_3d` | 6.6M | **需要** —— 98F 主人办公室（新档开局落点） |
| `tower_zones/base` · `common` | ~250K | **需要** —— `zone_base.tscn`，基地布局源 |
| `dungeon_3d` | 21K | **需要** —— `env_iron_frontier_kit`，场景 ext_resource |
| `base_world_3d` | 241K | **需要** |
| `tower_zones/expedition` | 86M | 不需要（远征关卡） |
| `tower_zones/battle` | 4.3M | 不需要 |
| `rooftop_courtyard_3d` | 8.4M | 不需要 |
| `mobile_landmark_3d` | 1.6M | 不需要 |
| `boss_arenas_v01` | 956K | 不需要 |
| `training_range_3d` | 257K | 不需要 |
| `british_corner_bookshop_3d` | 13K | 不需要 |
| `soviet_snow_street_corner_3d` | 9K | 不需要 |

**判定方式不是猜目录名**，而是跑一次真机、统计 `Resource file not found` 落在哪个目录：

```
移出 9 个目录后 → "Resource file not found" 821 条，全部来自 open_world/components
（即：其余 8 个目录在这条链路上真的零引用）
```

于是把 `open_world/components` 放回，其余 8 个继续外置。

## 结果

| | 之前 | 现在 |
| --- | --- | --- |
| `assets/art/environments` 在工程内 | 420M | **319M** |
| 外置到工程外 | 0 | **102M**（`I:\_scaffold_test\v323run\_env_hold`） |
| 真机启动到主世界 | t=4.0 | **t=4.0** |
| `Resource file not found` | 0 | **0** |
| 开场菜单 / 镜头 | 正常 | **正常** |

像素级比对（419M 版 vs 319M 版的开场截图）：差异 1.48%，热图显示**差异全部落在
兔子剪影上**（两次截图时跑动动画相位不同），环境区域逐像素一致。
⇒ 砍掉的那 102M 对开场画面**零影响**。

⚠ 目录移动会让导入缓存失效（首次复测 t 从 4.0 涨到 14.9）。必须重跑
`--headless --import`，之后恢复 4.0。

## 外置目录清单（`I:\_scaffold_test\v323run\_env_hold`，102M）

```
tower_zones/expedition        86M    远征关卡
tower_zones/battle           4.3M
rooftop_courtyard_3d         8.4M
mobile_landmark_3d           1.6M
boss_arenas_v01              956K
training_range_3d            257K
british_corner_bookshop_3d    13K
soviet_snow_street_corner_3d   9K
```

**没有删。** 要走远征 / 屋顶 / 靶场时，把这几个目录移回
`assets/art/environments/` 原路径 + 重跑 `--import` 即可。

## 遗留

- 若主人要求「开场背景也不要真实场景」（即纯 UI + 空背景），那是**改产品定义**，
  与原版 `MainEntryScreen3D` 的设计相悖，需要单独确认后再动，不能顺手改。
- `_removed_content/` 里仍有 `assets/art/enemies`（60M）与三个
  `ExpeditionLevel0{1,2,99}_3D.tscn` 未处理，属远征链路，本轮未碰。
