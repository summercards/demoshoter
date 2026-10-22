# 在线可玩版：Godot Web 导出 + 内网发布

工程版本 0.1.0。目标：产出一个能直接在浏览器里玩的链接。

**线上地址**：https://sofunny-resource-sharing.hnfunny.com/web-20261022-142522/
（Site ID `web-20261022-142522`，9 文件 / 189.3 MiB）

## 一、要补的三件事（本工程原本都不能 Web 导出）

| 缺什么 | 后果 | 怎么补 |
| --- | --- | --- |
| 没有 `Web` 导出预设 | 无产物 | `export_presets.cfg` 加 `[preset.3]`，`platform="Web"`，`variant/thread_support=false` |
| 渲染器是 Forward+ | Web 端需要 WebGPU，多数浏览器跑不起来 | `project.godot` 加 `renderer/rendering_method.web="gl_compatibility"` |
| 字体全是 `SystemFont` | **浏览器里中文全变方框**，菜单/HUD 全看不见，等于不能玩 | 内置 Noto Sans SC + `gui/theme/custom_font.web` |

第三条是最要命的：工程内所有字体走 `SystemFont`（`StartupLoadingScreen.gd:628`、
`DamageNumberStyle.gd:111`），靠"系统里第一个存在的族"取字。浏览器沙箱没有这个概念，
实测第一版 Web 截图里「开始游戏 / 设置」全是方框。

**字体只在 Web 生效**：用的是 ProjectSettings 的 feature tag 覆盖（键名后缀 `.web`），
桌面端与安卓端不引用这份字体，字形一字不变。字体为 Noto Sans SC，
SIL Open Font License 1.1（允许嵌入与分发），声明见 `assets/fonts/LICENSE_OFL.txt`。

## 二、发布时踩到的坑：`.pck` 被静默跳过

第一次发布（`web-20261022-142128`）返回「发布成功」，但输出里有一行

```
已跳过: index.pck
```

`.pck` 不在分享服务的静态后缀白名单里（`.bin` 在、`.pck` 不在）。
结果是**站点能打开、游戏起不来** —— 最坏的一种"看起来成功"。

处理：导出后把 `index.pck` 改名 `index.bin`，并同步改两处引用：
· `index.js` 里 `${exe}.pck` → `${exe}.bin`
· `index.html` 里 `GODOT_CONFIG.fileSizes` 的键 `"index.pck"` → `"index.bin"`

改名后**必须校验**（漏改一处就是白屏），所以落了 `scripts/build_web.py`：

```
python3 scripts/build_web.py            # 导出 + 改名 + 改引用 + 校验
python3 scripts/build_web.py --skip-export --publish   # 再发布
```

校验项：pck 头是 `GDPC`、`index.js` 里不再有 `${exe}.pck`、
`GODOT_CONFIG.fileSizes` 的键与**实际字节数一致**、产物里 `已跳过` 必须为空。

## 三、导出体积

初版 pck 160.6 MB，加了 `exclude_filter`（`tools/ tests/ docs/ scripts/ _removed_content/ _rollback_*`）
后 153.0 MB。**大头是 assets**（`assets/art` 157M 里 characters 48M / ui 30M / weapons 27M /
props 21M / vfx 14M / shared 14M），这些是开局与灰盒都真实用到的，本轮不动。

## 四、验收（真机 Chrome + SwiftShader 软件渲染）

**本地**：
- 引擎起来了：`Godot Engine v4.6.3.stable`、
  `OpenGL API OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) - Compatibility`
- 灰盒加载：`[GREYBOX] safe_line z=0.0 depth=1.2`
- 画面：开场近景兔子、舞台光柱、地面光斑、中文「弹壳风暴 青春版 / 开始游戏 / 设置」全部正常

**线上**（`web-20261022-142522`）：连续采样 123 秒，同一画面成立，中文正常，菜单可读。

已知非阻塞项：
- `Parameter "material" is null` 若干条 —— 与桌面端同一个既有基线（见
  `2026-10-21_v323_greybox_runtime_reconnect.md` 第 64 行），Web 端 gles3 路径同样会打，不影响渲染。
- `[AudioManager] 正式音效不可用：enemy_die（res://src/assets/audio/sfx/enemy_die_v003.ogg）`
  —— 该 ogg 在工程里本就不存在（`assets/audio` 仍在外置目录），桌面端同样报。
- 一条 `index.bin net::ERR_ABORTED`：浏览器取消的重复预取请求，pck 实际已加载成功
  （引擎启动 + 灰盒加载即证明）。
- **首次加载慢**（153 MB，内网约 1~2 分钟）。这是包体积决定的，不是 bug。

## 五、怎么重新发布

```bash
cd I:\_scaffold_test\v323run\ShellStorm2Port
python3 scripts/build_web.py --publish
```

改了内容要**保持链接不变**时用 `--update` 语义（发布脚本会按来源路径匹配旧站点，
Site ID 不变）：目前 `build_web.py` 走的是新增发布；要原地更新，可直接：

```bash
python3 ~/.workbuddy/skills/sofunny-resource-sharing/scripts/publish.py \
  server "I:\_scaffold_test\v323run\ShellStorm2Port\build\web" --update
```

## 六、遗留

- 旧的一次失败发布 `web-20261022-142128`（缺 pck，打不开）仍在服务器上。
  删除需主人确认 Site ID 后执行 `remove-server`，本轮未动。
- 包体积 189 MB，若要在弱网下可接受，需要裁剪 assets 或改用
  `variant/extensions_support` + 分章 pck，属独立优化项。
