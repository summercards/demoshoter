# 文档重置为空工程：归档原游戏设计，主设计文档改为空骨架

日期：2026-10-21
工程版本：`0.1.0`（`project.godot` 未改）
目标工程：`I:\_scaffold_test\v323run\ShellStorm2Port`
源工程：`I:\工作项目\shellstrom2\ShellStorm2`（只读，本轮未写入）

## 起因

用户提出：「这是个初始化的工程项目，文档需要跟项目匹配」，并明确「主设计文档应该是空的，本身没有核心玩法的目标设计，要写清楚这是一个空项目，可以让后续自由发挥，但是要严格遵守规范文档」。

先做的只读核查，结论是**文档与工程不匹配，且不匹配的方向会误导开发**：

| 文档声称 | 工程实际 |
|---|---|
| 正式主线是「远征情报室 → expedition_01 单层 7 房」 | `RogueMapSelectMenu.gd` 的 `LEVEL_IDS = ["99"]`，只有灰盒；`ExpeditionLevel01/02/99_3D.tscn` 在 `_removed_content/` |
| 37 项功能已登记、41 行功能表、258 处 `[已实装]` | 全部指向原工程；本工程一个功能都没登记 |
| 12 只唯一精英、78 张塔罗、七大核心系统 | 原工程时点的用户设计，与本工程无关 |

根因：`docs/` 是从原工程整体继承的，只有 3 篇 2026-10-21 的记录在描述这个骨架。

## 改动

### 1 归档原游戏文档（352 项）

整批移入 `docs/archive/inherited_shellstorm2_2026-10-21/`，保持内部相对结构：

| 子目录 | 内容 | 文件数 |
|---|---|---|
| `v0.1_topic/` | 01–18 主题施工、完整度清单、功能关系跟踪、`feature_registry.json`、原 CHANGELOG | 31 |
| `v0.1_design/` | 45 篇设计页与 `refs/` | 48 |
| `v0.1_audits/` | 13 篇审计 + `evidence/` | 50 |
| `v0.1_development/` | 2026-09-12 至 2026-10-20 交付记录 + `history/` | 267 |
| `docs_art/` | 原工程资产批次验收证据 | 78 |
| `v0.2/` | 原工程 0.2 变更登记册 | 2 |

配套：`.gdignore`（Godot 不导入、不入包）+ `README.md`（来源、时点、使用边界、可复用的踩坑清单）。

**不归档**：
- 规范类文档——讲「怎么做」，对本工程持续有效（清单见 `docs/README.md`）。
- 运行数据 `docs/v0.1/data/`——`data/level_plans/expedition_01/level_plan.json` 的 `source_csv` 仍指向它，移动会断溯源。

### 2 主设计文档改写为空骨架

`docs/v0.1/README.md` 从 420 行原游戏主设计，改写为「空设计骨架」：

- §0 开头明写：**这份文档现在的正确内容是「还没有内容」**；一旦开始描述具体玩法，说明有人把归档或代码现状当成了目标，必须退回。
- §1 给出「空项目」的三条可验证判据（无冻结设计 / 无登记功能 / 无验收基线）。
- §4 列 9 个**设计槽位**（D1 愿景 … D9 表现基线），全部标「未设计」，并注明槽位可增删改名。
- **明确不继承「七大核心系统」**：D4 要求系统数量与切分从 D1–D3 推出来。
- §3 给出优先级：用户当轮指令 > 已冻结设计 > 规范 > 归档（只能参考）。
- §7 列出不随玩法变化的工程约束（资产路径不带版本、关卡解耦、存档目录、Autoload 隔离等）。

### 3 入口与索引改成空工程版

| 文件 | 改动 |
|---|---|
| `docs/README.md` | 重写为「这是什么工程 → 阅读顺序 → 规范清单 → 目录地图 → 门禁说明」；规范清单单独成表，并注明文中数量/清单属原工程实例 |
| `docs/v0.1/MODULE_INDEX.md` | 重写为空功能表（0 行），带 `<!-- EMPTY-PROJECT-INDEX -->` 显式声明；补齐登记第一行所需的六列定义、状态词含义、同步注册表要求 |
| `docs/v0.1/feature_registry.json` | `features: []`，`empty_project: true` |
| `docs/v0.1/design/README.md` | 重写为空设计目录说明：命名规则、必填 11 字段、冻结流程、四条禁止（不许从归档直接复制当设计） |
| `docs/v0.1/development/README.md` | 重写为本工程开发记录说明；原 266 篇索引指向归档 |
| `docs/v0.1/development/CHANGELOG.md` | 重写为本工程变更日志；原版归档为 `CHANGELOG_inherited.md` |

### 4 新增骨架能力说明书

`docs/SKELETON_CAPABILITIES.md`（新文件）。它回答「手上到底有哪些积木」，因为主设计文档说「玩法未定」之后，下一个问题必然是「那现在有什么」。

关键设计是**证据强度三档**：`文件存在` / `接入正式链` / `已实测`。默认全是第一档，只有 2026-10-21 那份 22 条断言记录覆盖的项才标「已实测」。并明确写出：

> 不要把「`src/` 里有这个文件」当成「这个功能能用」。

同时列出已剥离内容（Boss 模型、房间组件源、BGM、远征关卡场景、基地设施美术）与 410 个验证脚本「不能直接当证据」的原因。

### 5 门禁支持显式空工程

`scripts/check_documentation_contracts.py`：

- 新增 `EMPTY_PROJECT_MARKER = "<!-- EMPTY-PROJECT-INDEX -->"`。
- 无功能行 **且** 有标记 → 合法，输出 `empty_project: true`。
- 无功能行 **且** 无标记 → 仍报 `No feature rows found`（漏写不能蒙混）。
- 有功能行 **且** 有标记 → 报错（标记是「我确认现在没有功能」的声明，不是省事的开关）。

没有放宽任何其他检查：六列格式、ID 唯一、设计与注册表一致、验收脚本存在且注册，全部保留。

### 6 归档后的链接重定向

归档造成 415 条断链，全部来自保留的规范文档指向已归档文件。写了重定向脚本，只改「目标不存在且归档中存在同结构副本」的链接：

- 自动改写 **399 条**，涉及 11 个文件。
- 剩余 14 条人工处理：2 张图片原工程就缺失（改为文字注明）、`CHANGELOG.md`（已归档重写）、`MODULE_INDEX` 的示例占位（改为非链接）。

## 验收

`python3 scripts/check_documentation_contracts.py`：

| 指标 | 重置前 | 重置后 |
|---|---:|---:|
| 扫描文档 | 377 | 25 |
| 本地链接 | 2030 | 119 |
| 功能行 | 41 | 0（`empty_project: true`） |
| 问题数 | 415（首次运行基线含大量存量断链） | **2** |

剩余 2 项均为**存量、非本轮引入**，未修改、未放宽：

1. `VERIFICATION_REGISTRY_FAILED`：4 个用例在 `tests/verification/` 存在但未在 `run_verification_suite.sh` 注册——`verify_base_lamp_dynamics`、`verify_base_lamp_visual`、`verify_stairwell_turn_rail`、`verify_strip2_acceptance`。已核对 `git ls-tree HEAD`，这 4 个文件在本轮之前就已存在且未注册。
2. `MEDIA_ASSET_DOMAINS_FAILED`：媒体账本域值口径不一致（`ui` 18 / `audio` 178 / `music` 9）。2026-10-21 上一轮记录已登记为移植存量。

**处理决定：不修。** 前者要注册就得先确认 4 条用例能跑通，否则是把红项换成假绿；后者属媒体账本域值口径，与文档重置无关。两者都记在这里，留给后续独立处理。

## 未做

- 未跑验证套件。本轮只动文档与一个门禁脚本，未改任何游戏代码。
- 未修上述 2 项存量门禁红项（原因见上）。
- 未给保留的 8 份规范文档逐篇加「适用性横幅」，只在 `docs/README.md` 与主设计文档集中说明。若后续有人单独打开 `14.8_音乐系统与配乐资产.md`，会看到原工程的曲目清单——这层风险已知，未消除。
- 未处理 `scenes/` 下 46 处指向 `_removed_content` 的 `ext_resource`（上一轮记录已列为未做）。
- 未恢复任何被剥离的美术或音频资产。

## 过程文件

- 归档清单（352 项，逐项 from/to）：`I:\_scaffold_test\v323run\ShellStorm2-work\sessions\2026-10-21_doc_reset\archive_manifest.json`
- 迁移脚本：同目录 `archive_docs.py`、`archive_docs_fix.py`
- 链接重定向脚本：同目录 `rewrite_links.py`
- 回滚方式：按 `archive_manifest.json` 逐项 `to → from` 反向移动；`git checkout -- docs/` 可还原被改写的文档正文。
