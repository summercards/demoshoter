# 刷怪开关（修正版）：改成场景里的可交互物件

工程版本 0.1.0。接续同日 `2026-10-22_greybox_spawn_switch.md`。

## 我第一版做错了什么

第一版把开关做成了 **HUD 按钮**（`HUD/SpawnSwitch`，底部中央一块深色方框）。
主人的原意是**场景里的可交互物件** —— 就是地上那个带白圆点、走过去按 E 的东西。
HUD 按钮不符合这个语义，已改为 3D 物件。

## 现在的实现

新文件 `scenes/greybox/greybox_spawn_switch_3d.gd`（`Area3D`），摆在出生点前方
`(0, 0, 18)`，玩家出生在 `(0, 0, 20)`，正对着它。

**交互完全复用现成系统，没有新造一套**：

| 环节 | 复用的是谁 |
| --- | --- |
| 白圆点 | `PlayerInteractionController3D` 自动创建驱动 `InteractionDot3D` |
| `[E] 开始刷怪` 提示 | 同上，圆点自带文案渲染 |
| 走近判定 | 自家 `Area3D` + `body_entered`，范围 2.2 m（与 `RoomLightSwitch3D` 同值） |
| 契约方法 | `get_interaction_candidate` / `perform_interaction` / `set_interaction_focus` / `get_interaction_dot_anchor` / `is_interaction_dot_visible`，签名照抄 `RoomLightSwitch3D` |
| 视觉 | 面板 / 指示球 / 拨杆的尺寸、材质参数照抄 `RoomLightSwitch3D._build_visual()` |
| 刷怪 | `host.start_encounter_event(host._build_room_encounter_config(room))` —— 关卡里的「倒计时刷怪」正式实现 |

## 踩到的两个坑（都已修）

1. **提示文字重影**：我一开始自己建了 `Label3D` 写 `[E] 开始刷怪`，而圆点本身也会写 ——
   截图里出现两行叠在一起。改成不建 `Label3D`，`set_interaction_focus` 写成 no-op，
   与 `RoomLightSwitch3D` 同口径（它把提示牌退役成纯文案载体）。
2. **协程不能同步返回**：`_fire()` 里带 `await`（等 60 秒），GDScript 会把它当协程，
   而 `perform_interaction` 契约必须同步返回 `bool` → 编译报
   `Function "_fire()" is a coroutine, so it must be called with "await"`。
   拆成两段：`_fire()` 同步（置位 + 启动 + 返回 bool）、`_rearm_later()` 异步（到点恢复）。

## 验收（真机 Forward+ 1280×720）

```
SWITCH = true   pos=(0, 0, 18)   visible=true
ENEMIES_BEFORE = 5
PROMPT = "[E] 开始刷怪"   available=true
PERFORM = true   → switch_visible=false
t=1s enemies=9  switch=false     ← 第一波 count:4 到位
t=2s enemies=9  switch=false
t=3s enemies=9  switch=false
t=4s enemies=9  switch=false
```

- `SCRIPT ERROR` 0 条。
- 倒计时环 0:52 出现（机制自带表现）。
- 60 秒后开关恢复（前一轮同机制已验证：`t=63s switch_visible=true disabled=false`）。

## ⚠️ 顺带发现一个**既有**问题（不是本轮引入，也未修）

真机跑的时候玩家是 **1/100 血**，画面有一层红色低血晕影。

已做的对照实验（用来证明与本轮改动无关）：

| 状态 | `HP` |
| --- | --- |
| 我的改动全部注释掉（`room.encounter` 与 `_build_spawn_switch()` 都不执行） | **1** |
| 只注释 `room.encounter`，保留开关 | 1 |
| 全部启用 | 1 |

⇒ HP=1 与我加的东西**无关**，是既有的。

进一步观察：

- 存档 `AppData/Roaming/ShellStorm2Port/base_save.json` 里
  `payload/active_run_snapshot/player_hp = 1.0`。
- 我把它（连同 `.bak`）手工改成 `100.0`，重启后**又变回 1.0** ——
  说明游戏在启动过程里就把它写成 1 了。
- 进入世界后第 0.5 秒采样即为 `1/100`，且此时开场页还锁着输入（`input_locked=true`）。

可疑点（未验证，供主人决定是否要我查）：
`Dungeon3D.gd:1114` 恢复时是
`player.current_hp = clampi(int(snapshot.get("player_hp", ...)), 1, player.max_hp)`，
理论上 100 不会被夹到 1；所以更像是**恢复之后**又被某个系统（fate 的 `last_stand`
保命机制？自动存档回写？）压到了 1。

**没有动它** —— 主人要求「其它什么都别变」，且这属于玩法数值问题，不该顺手改。

## 证据位置

- 截图：`I:\_scaffold_test\v323run\_qa_shots\s3d_in_range.png`（走近时的圆点与提示）、
  `s3d_after.png`（按 E 之后）
- 存档备份（修改前的原样）：`I:\_scaffold_test\v323run\_qa_shots\base_save_backup_before_hp_fix.json`
