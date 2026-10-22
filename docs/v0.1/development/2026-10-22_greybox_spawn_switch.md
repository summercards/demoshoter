# 刷怪开关：把「开始刷怪」接到既有运行时遭遇事件上

工程版本 0.1.0。灰盒关卡（`GreyboxLevel01`）新增一个一次性开关。

## 需求原话

「加一个开关，就是刷怪的开关，打开后就会开始进行刷怪。刷怪的功能**直接使用关卡里倒计时刷怪的那个**。
**不要做任何改动**。打开就是 1 分钟倒计时刷怪。其它什么都别变。只是把这个功能做成这个开关。
然后这个开关使用后消失。一分钟后会又出现。」

## 先定性：所谓「倒计时刷怪」是哪一套

翻 `CHANGELOG_inherited.md:716` 的既有结论：它的正式名是**运行时遭遇事件**
（`EncounterEventDirector3D` + `EncounterEventHost3D`），「撤离防守」只是它的第一个使用方。
它的两条轴是 `completion`（timer / clear / timer_and_clear）与 `progress_mode`（tick / external）。

**关键发现：这两条轴在 `Dungeon3D._build_room_encounter_config()` 里是写死的缺省值**：

```
"completion": "timer",
"progress_mode": "tick",       ← 自己走倒计时，不靠外部喂进度
"stage_advance": clear/time,   ← 从数据读
"hud_countdown": true          ← 右上角倒计时环
```

`timer + tick` 正是「自己倒计时一分钟、时间到就不再开工」。所以开关**必须**走这个构造器 ——
自己拼 config 就是复制一份平行实现，改一处漏一处。

## 改动（两个文件，全是接线，零机制代码）

### `scenes/greybox/greybox_builder.gd`

1. `room.encounter = _greybox_encounter()` —— 只提供**数据**，键名全部是构造器已在读的正式键：
   `duration_sec` / `seal_room` / `hunt_player` / `hud_countdown` / `start_delay_sec` / `stages`。
2. `_build_spawn_switch()` —— 一枚按钮，挂在 `$HUD` 下（`HUD/SpawnSwitch`），
   底部中央 `(-110..110, -108..-52)`，棱镜口径（深墨底 + 白 1px 边 + 方角），不新建面板、
   不动任何既有 HUD 的锚点或尺寸。
3. `_on_spawn_switch_pressed()` —— 点下去：
   ```
   开关隐藏 + disable
   → start_encounter_event(_build_room_encounter_config(room))   ← 现成入口
   → 失败：把开关放回去并 push_warning
   → 成功：await 60 秒 → 开关恢复
   ```

### `scenes/greybox/GreyboxLevel01.tscn`

无改动（开关挂在脚本里，不占场景节点）。

## 刻意选择的三处，理由

| 选择 | 理由 |
| --- | --- |
| `seal_room: false` | 主人要「只是刷怪」。封门是遭遇事件的可选项，这里不启用，其它玩法一字不变 |
| `hunt_player: true` | 不启用时怪会按野外潜行逻辑站在原地等玩家撞上来，点下去看着像「没刷出来」，那就不是刷怪开关 |
| 刷怪波数 > 60 秒能打完的量 | 主人要的是「一分钟持续刷怪」：杀得快就一直有下一波，杀得慢就到点收工（`_drop_unstarted_stages` 生效） |

## 验收（真机 Forward+ 1280×720）

| 时刻 | 敌人总数 | 开关 |
| --- | --- | --- |
| 点前 | 5 | 可见 / 可点（rect `(530,612) 220×56`） |
| 点后 0.4s | — | **消失 + disabled** |
| +1s | **9**（+4 = 第一波 `count:4`） | 不可见 |
| +2s … +8s | 9 | 不可见 |
| +63s | 7 | **重新可见、可点** |

- `start_encounter_event` 返回 `ok:true`，`instance_id = room_encounter:start#2`，
  `requested: 33`、`completion: timer`、`progress_mode: tick`、`hud_countdown: true`。
- 截图 `switch_after.png`：右上角出现 **0:52** 倒计时环（这套机制自带的表现，不是新加 UI），
  开关那一栏回到两个快捷物品槽，右侧可见刷出来的怪。
- `SCRIPT ERROR` 0 条。

## 未改动的部分（对照主人的「其它什么都别变」）

- 灰盒启动时原有的 5 只 `melee_chaser` 不动。
- 既有 HUD 任何锚点 / 尺寸 / 文案未改。
- `Dungeon3D`、`DungeonRoom3D`、`EncounterEventDirector3D`、`EncounterEventHost3D` **零改动**。
- 开场页（`MainEntryScreen3D`）零改动；开关跟着 HUD 一起在开场时被隐藏、
  点「开始游戏」后一起回来 —— 不额外做可见性处理，才叫「其它什么都不变」。
