# 启动壳标题改名：弹壳风暴2 → 弹壳风暴-青春版

工程版本 0.1.0（`project.godot` 未改）。只改文案与随之联动的版式参数，不涉及存档、资源、包体。

## 起因

主人要求把启动壳（首个画面）的名字改成「弹壳风暴-青春版」。原文「弹壳风暴2」是 5 字符，新串是 7 汉字 + 1 连字符，**字数变了，字号必须重算** —— 直接换字会横向到 1900 px 宽，切掉近 1/3 屏。

## 字号反算（不靠估）

用真实字体（`Microsoft YaHei UI`，weight 800、字距 8）在 Godot headless 里量 `get_string_size` + `ascent/descent`，再按 -13° 旋转求字形包围盒：

| 文本 | 字号 | 字宽 | 字块高 | 旋转后字形框 | 横向溢出 |
| --- | --- | --- | --- | --- | --- |
| 弹壳风暴2（旧） | 260 | 1232 | 332 | 1275×601 | −4.9（不含特效） |
| 弹壳风暴-青春版（新） | 148 | 1157 | 189 | 1170×444 | −110 |
| 弹壳风暴-青春版（新） | 160 | 1246 | 205 | 1260×479 | −20 |
| **弹壳风暴-青春版（新）** | **162** | **1261** | **207** | **1275×485** | **−4.6** |
| 弹壳风暴-青春版（新） | 176 | 1365 | 225 | 1380×525 | +100（切字） |

结论：**162 px** 落在与旧版相同的横向预算线上（1261 vs 1232，差 2.4%）。旧注释里的「视觉包围盒 1302×608」是字形框 1275×601 再叠描边/色散/强拍抖动后的值，两者同一档。

后续改字的换算公式（写进设计文档，避免再试错）：`S ≈ 1300 / (字宽比×n)`，中文字宽比 ≈1.0、连字符/数字 ≈0.29。

## 联动改动（四处，缺一都会露馅）

| 常量 | 旧 | 新 | 依据 |
| --- | --- | --- | --- |
| `TITLE_TEXT` | `弹壳风暴2` | `弹壳风暴-青春版` | 主人指定 |
| `TITLE_FONT_SIZE` | 260 | 162 | 横向预算反算，见上表 |
| `TITLE_CENTER_RATIO` | 0.42 | 0.50 | 字块高 601→485，沿用 0.42 会重心塌到上半屏 |
| `OUTLINE_PX` | 5.0 | 3.2 | 按字高比 1.5% 反算（旧 5/332=1.5%，新 3.2/207=1.55%） |

`BAR_WIDTH_OF_TEXT`（0.34）、`BAR_HEIGHT`（8）、`BAR_GAP`（36）**不动**：前者吃字宽比例会自适应，后两者是绝对像素，在变矮的字块下仍成立。

## 验收

真机窗口渲染两帧（间隔 0.13 s，跨不同闪切帧），像素级量白字包围盒：

```
size 1280 720   white_px 96173
bbox 14 151 1263 577   →  1249 x 426
left 14  right 16  top 151  bottom 142   center_ratio_y 0.5056
```

- 横向左右各 14 / 16 px ⇒ **压满画幅且不出画、不切字**（旧版是刻意切 11 px，新版不需要）。
- 纵向上下各 151 / 142 px，重心 0.5056 ⇒ 居中成立，不是靠目测。
- 进度条仍在同一 -13° 坐标系、字块下中，屏底留白约 80 px。
- 色散、朋克律动、闪切背景不受影响（都按 `font_size` 与 `pose` 计算，无硬编码像素）。

## 门禁与遗留

- `python3 scripts/check_documentation_contracts.py` 退出码 **1**，68 项问题 —— 逐条核对**不含**本次改动的两个文件（`scenes/StartupLoadingScreen.gd`、`docs/v0.1/design/UI与UX全局设计及全界面清单.md`），均为既有基线（broken links、audio/music 域登记、verification registry 未登记项）。
- 启动壳无专属验收脚本；`probe_opening_movie_e2e.gd` 只加载场景不断言标题文本，改名不影响。
- `boot_splash`（引擎级前置画面）无标题文字，无需同步。

---

# 第二轮：把改名推到全局（同日晚）

主人要求「改一下」，即上一轮遗留的 `config/name`。

## 先纠正上一轮的一个错误判断

上一轮我写「改 `config/name` 会让存档路径漂移」，**这是错的**。本项目
`project.godot` 同时有：

```
config/use_custom_user_dir=true
config/custom_user_dir_name="ShellStorm2Port"
```

按引擎规则，`user://` 取 `custom_user_dir_name`，**与 `config/name` 无关**。实测：

| 时刻 | `config/name` | `OS.get_user_data_dir()` |
| --- | --- | --- |
| 改前 | 弹壳风暴2 | `C:/Users/<user>/AppData/Roaming/ShellStorm2Port` |
| 改后 | 弹壳风暴-青春版 | `C:/Users/<user>/AppData/Roaming/ShellStorm2Port`（**未变**） |

改完后回查存档目录，`base_save.json` 与 `.bak` 仍在原处、时间戳未动。
⇒ 显示名与数据目录是**两条互不影响的路径**，可以放心分开改。

## 改动清单

| 文件 | 改动 |
| --- | --- |
| `project.godot` | `config/name` → `弹壳风暴-青春版`；并在设置旁写清「目录由下面两行决定，与 name 无关」 |
| `scenes/BaseWorld3D.tscn` | `TitleLabel` → `弹壳风暴-青春版 · 3D 基地与荒野` |
| `scenes/ui/MainEntryScreen3D.tscn` | `Title` → `弹壳风暴-青春版`（该节点 `visible=false`，仅同步文本） |
| `src/world3d/TowerDescent3D.gd` | 三处 HUD 标题（远征 / 向下爬楼 / 启动失败） |
| `src/world3d/Dungeon3D.gd` | 参考 HUD 身份行 |
| `src/ui/main_entry/EntryBrand.gd` | 品牌字标改「弹壳风暴」+ 强调「青春版」，并改为**自适应缩放**（见下） |
| `scripts/daily_release.py`、`scripts/collect_daily_changes.py` | 发布页标题 |
| `tests/verification/verify_verification_runner_contract.gd` | 修掉一条**假绿断言**（见下） |

## EntryBrand：字标必须自适应，不能写死字号

原版是「弹壳风暴」4 字 + 强调「2」1 字，`base = h×0.44 = 78.32` 时总宽 371，容器可用宽 390 —— 刚好塞下。
新串强调段变成 3 字，同 base 下 need **580.10**，溢出 190.10。

改成「量宽 → 超了就回缩 → **迭代到收敛**」：

```
need = w(正文) + base×gap + w(强调)
need > avail  ⇒  base ← base × (avail/need) × 0.995
```

⚠ **为什么必须迭代**：只缩一次不收敛。实测 base 78.32 → 一缩到 52.65 后**仍溢出 3.48px**，
因为 `int(base)` 取整 + 字体 hinting 让字宽不随字号严格线性。
迭代版第 2 轮收敛：base 51.67、total 386.30 / avail 390、右端 398.30 / 上限 402。

真机截图（复刻 tscn 几何 42,112→450,290，并在容器右边界画 1px 参考线）确认字标与细线均未越界。

## 顺手修掉一条从来没可能触发的断言

`verify_verification_runner_contract.gd` 原有一行：

```gdscript
if actual_dir.ends_with("/弹壳风暴2"):
    failures.append("验收仍指向正式玩家数据目录")
```

它想拦的是「验收跑到真实玩家目录」。但本项目 `user://` 一直是 `ShellStorm2Port`，
**永远不等于「弹壳风暴2」** ⇒ 这条断言从写下的那天起就不可能触发，是假绿。
现改为按引擎真实规则推导（`use_custom_user_dir` ? `custom_user_dir_name` : `config/name`），
不再硬编码名字，改名也不会失准。

## 第二轮验收

- `check_documentation_contracts.py` 退出码 1（既有基线 68 项 → 72 项，新增 4 项均为
  `docs/v0.1/development/` 下历史记录里的旧链接，**不含**本轮改动文件；新记录自身零断链）。
- `check_asset_runtime_naming.py` 退出码 **2** = 欠账快照陈旧（`tscn 93 → 92` 已还但未缩表），
  属既有状态；本轮改的两个 `.tscn` 只动文本，未涉及任何带版本引用。
- `Dungeon3D` 顶栏实测：7 个子控件右端最大 596，容器宽 1084，**余量 488px** —— 名字变长不挤爆。
- `EntryBrand.gd` 编译通过；`MainEntryScreen3D.tscn` 加载通过。

## 遗留（明确没做）

- `boot_splash/image = scenes/StartupLoadingSplash.png` 是引擎级前置画面，图上无标题文字，无需同步。
- Android 的 `package/name="ShellStorm2"`（`project.godot` 与 `export_presets.cfg` 各一处）**未改** ——
  那是包标识相关的显示名，改它涉及渠道/安装包一致性，不属于「显示名」范畴，需要时单独确认。
- `custom_user_dir_name="ShellStorm2Port"` **刻意不动**：它是存档目录名，改它才是真正搬存档。
