# 弹壳风暴2

Godot 4.6 顶视角 3D 项目骨架。当前工程版本 `0.1.0`。

**这是初始化骨架工程：有能跑的 3D 底座、完整的工程规范、一批可复用的运行时模块；没有已确定的玩法。**

主设计文档现在是空白骨架，不回答「这个游戏是什么」：

- 主设计：[docs/v0.1/README.md](docs/v0.1/README.md)
- 手上有什么积木：[docs/SKELETON_CAPABILITIES.md](docs/SKELETON_CAPABILITIES.md)
- 当前功能登记：零个（[MODULE_INDEX.md](docs/v0.1/MODULE_INDEX.md) 的空白表就是答案）

原《弹壳风暴2》的全部玩法设计与施工记录已归档在 `docs/archive/inherited_shellstorm2_2026-10-21/`，**只能参考，不能当本工程的设计依据**。

## 现在能跑什么

启动 → 加载页（标题「弹壳风暴-青春版」）→ 灰盒战斗场景 `scenes/greybox/GreyboxLevel01.tscn`。

灰盒 `instance` 自 `scenes/Dungeon3D.tscn`，继承战斗、背包、奖励、装备事务与存档；几何是程序化白盒（60×60 m、5 个胶囊敌人、白盒设施占位）。这条链路 2026-10-21 有 22 条断言的实测记录。

注意：基座自带「清房间 / 开箱 / 撤离」不等于这些是本工程的目标玩法。留不留、改不改，都还是设计决定。

## 开始开发

1. 用 Godot 4.6.x 打开仓库根目录。
2. 先读 [工程文档入口](docs/README.md)，再读 [文档驱动开发规范](docs/DOCUMENTATION_STANDARD.md)。
3. 要动玩法：先按主设计文档 §5 走「提案 → 冻结 → 登记 → 契约 → 施工」，**不能先写代码再倒推设计**。
4. 要加关卡：读 [关卡接入规范](docs/v0.1/关卡接入规范.md)。
5. 交付前跑 `python3 scripts/check_documentation_contracts.py` 与相关验证；涉及关卡、角色、战斗或资产时跑对应专项。

## 目录

| 路径 | 职责 |
|---|---|
| `scenes/` | 可运行场景、UI 页面、场景装配入口 |
| `src/framework/` | 跨系统稳定契约 |
| `src/core/` | 全局基础设施、状态机、存储、音频、时间 |
| `src/world3d/` | 3D 关卡、房间、门、撤离 |
| `src/player3d/` / `src/enemy3d/` | 3D 角色与怪物运行时 |
| `src/game/` | 维度无关的玩法模块（背包、掉落、结算、保险） |
| `src/base/` | 基地长期数据、设施、商店、蓝图 |
| `assets/art/` | 运行美术资产；制作源在 `art_source/` |
| `assets/registry/` | 美术资产唯一登记源 |
| `_removed_content/` | 从原工程剥离、当前不用的内容（`.gdignore`，不入包） |
| `tests/verification/` | 自动回归场景（多为原工程遗留，未逐条适配） |
| `docs/` | 规范、空主设计、开发记录；`docs/archive/` 为历史 |

`outputs/`、`.dev-cycle/`、`.codex-tmp/` 是可丢弃工作产物，不进入版本控制。开发临时产物放上层 `ShellStorm2-work/`。

运行贴图遵循[尺寸与共享规则](docs/v0.1/10_资产与内容规范.md)，导出或重导入模型后运行 `python scripts/check_runtime_texture_policy.py`。
