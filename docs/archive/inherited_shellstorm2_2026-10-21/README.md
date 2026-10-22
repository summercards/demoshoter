# 继承文档归档 · ShellStorm2 原工程

归档日期：2026-10-21
来源工程：`I:\工作项目\shellstrom2\ShellStorm2`（只读，未回写）
归档原因：本工程是**初始化骨架工程**，不继承原工程已冻结的玩法目标设计。

## 这批文档是什么

原《弹壳风暴2》的玩法设计、技术施工、审计、开发记录与功能账，整批搬到这里。

| 子目录 | 原位置 | 内容 |
|---|---|---|
| `v0.1_topic/` | `docs/v0.1/01…18、CHANGELOG、FEATURE_RELATIONSHIP_*、MODULE_PIPELINE_INDEX、feature_registry.json` | 七大系统技术施工、完整度清单、功能关系跟踪 |
| `v0.1_design/` | `docs/v0.1/design/` | 45 篇功能目标设计、关卡设计、剧情剧本、UI 清单 |
| `v0.1_audits/` | `docs/v0.1/audits/` | 13 篇审计与逐字段证据 |
| `v0.1_development/` | `docs/v0.1/development/` | 2026-09-12 至 2026-10-20 共 266 篇交付记录（含 `history/`） |
| `docs_art/` | `docs/art/` | 原工程资产批次验收证据 |
| `v0.2/` | `docs/v0.2/PLAN.md` | 原工程的 0.2 变更登记册 |

完整逐项迁移清单：`I:\_scaffold_test\v323run\ShellStorm2-work\sessions\2026-10-21_doc_reset\archive_manifest.json`（352 项）。

## 使用边界（重要）

- **只能当参考，不能当依据。** 这里的「已实装」「已验收」「用户设计」全部指向原工程的那个时点，对本工程不成立。
- **不能据此判断本工程有什么。** 本工程当前真实能力只看 [骨架能力说明书](../../SKELETON_CAPABILITIES.md)。
- **不能把这里的设计当默认目标。** 要复刻某条设计，必须在 `docs/v0.1/design/` 重新写一份设计页、重新冻结，并在页首注明「来源：归档 XXX」。直接引用归档路径等于把别人的结论当自己的决定。
- **归档内容不参与门禁扫描。** 本目录有 `.gdignore`，Godot 不导入；文档门禁的链接检查也只扫 `docs/*.md`、`docs/v0.1/**`、`docs/v0.2/**`。

## 里面真正值得复用的部分

不是玩法，是**踩过的坑**。以下主题在归档里记录得比较完整，后续遇到同类问题时可以直接查：

| 主题 | 去哪查 |
|---|---|
| 存档 schema 与原子写入（`BaseData 2.0`、checksum、迁移） | `v0.1_topic/09_技术施工_存档结算与复活.md` |
| 武器实例、装配树、命运槽的所有权链 | `v0.1_topic/04_技术施工_战斗与局内成长.md` |
| 房间/门/走廊的坐标一致性与流送 | `v0.1_topic/05_技术施工_关卡生成与爬楼.md` |
| Blender → Godot 资产导入与去版本化 | `v0.1_development/2026-09-17_godot_asset_deversioning_plan.md`、`2026-10-11_art_source_split.md` |
| 贴图预算与包体 | `v0.1_development/2026-10-11_runtime_texture_optimization.md` |
| 启动卡顿与性能定位 | `v0.1_development/2026-10-11_startup_room_stutter_diagnosis.md`、`2026-10-04_stutter_deep_diagnosis.md` |

## 不在这里的东西

- **规范类文档没归档。** 它们讲「怎么做」，对本工程仍然有效，留在 `docs/` 与 `docs/v0.1/` 原位。
- **运行数据没归档。** `docs/v0.1/data/`（内容表、掉落 CSV）与 `data/level_plans/` 仍被运行时和溯源字段引用，原地不动。
