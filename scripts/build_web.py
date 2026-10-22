#!/usr/bin/env python3
"""构建可在线玩的 Godot Web 版本，并把产物整理成发布服务接受的形态。

为什么要这个脚本，而不是直接跑 godot --export-release：

1. **`.pck` 不在发布服务的静态后缀白名单里**（白名单在
   sofunny-resource-sharing 的 publish.py：`.bin` 在、`.pck` 不在）。
   直接发布会静默 `已跳过: index.pck`，站点上传成功但游戏起不来 —— 这是最坏的一种
   "看起来成功"。所以导出后把 pck 改名 `.bin`，并同步改两处引用：
     · index.js  里 `${exe}.pck` → `${exe}.bin`
     · index.html 里 GODOT_CONFIG.fileSizes 的键 "index.pck" → "index.bin"
   改完必须校验（见 verify_pack），否则改名漏改一处就是白屏。

2. **Web 需要内置中文字体**。全工程字体走 SystemFont，浏览器沙箱没有系统字体，
   不内置就是满屏方框。字体在 project.godot 里用 feature tag 覆盖
   （`gui/theme/custom_font.web`），只在 Web 生效，桌面端不受影响。

用法：
    python3 scripts/build_web.py            # 导出 + 整理 + 校验
    python3 scripts/build_web.py --publish  # 再发布到内网分享服务
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "build" / "web"
GODOT = Path("I:/Godot_v4.6.3-stable_win64.exe/Godot_v4.6.3-stable_win64_console.exe")
PRESET = "Web"
# 发布白名单里的后缀；.bin 是 Godot 旧版 packing 的常规叫法，服务端也认。
PACK_SUFFIX = ".bin"


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    print("+", " ".join(str(c) for c in cmd))
    return subprocess.run(cmd, **kw)


def export() -> None:
    if not GODOT.exists():
        sys.exit(f"找不到 Godot 可执行文件：{GODOT}")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # 不要先删目录：删除会被安全策略拦掉（这是好事，说明它没在乱删）。
    # 覆盖导出即可，旧产物会被同名覆盖。
    result = run([
        str(GODOT), "--headless", "--path", str(ROOT),
        "--export-release", PRESET, str(OUT_DIR / "index.html"),
    ])
    if result.returncode != 0:
        sys.exit(f"导出失败，退出码 {result.returncode}")
    if not (OUT_DIR / "index.html").exists():
        sys.exit("导出完成但没见到 index.html")


def rename_pack() -> None:
    pck = OUT_DIR / "index.pck"
    if not pck.exists():
        print("· 已是 .bin 形态，跳过改名")
        return
    pck.rename(OUT_DIR / f"index{PACK_SUFFIX}")
    print(f"· index.pck → index{PACK_SUFFIX}")


def patch_references() -> None:
    """把两处 .pck 引用改成 .bin。改不改得动都要能看出来。"""
    js = OUT_DIR / "index.js"
    text = js.read_text(encoding="utf-8")
    before = text.count(".pck")
    text = text.replace("${exe}.pck", "${exe}" + PACK_SUFFIX)
    js.write_text(text, encoding="utf-8")
    print(f"· index.js: 替换 .pck 引用 {before} → {text.count('.pck')}")

    html = OUT_DIR / "index.html"
    text = html.read_text(encoding="utf-8")
    text = text.replace('"index.pck"', f'"index{PACK_SUFFIX}"')
    html.write_text(text, encoding="utf-8")
    print(f"· index.html: fileSizes 键已改为 index{PACK_SUFFIX}")


def verify_pack() -> None:
    """改名后必须校验：pck 头 + 两处引用 + 文件确实存在。

    改名漏改一处 = 白屏，而发布流程不会报错。所以这里宁可失败。
    """
    pack = OUT_DIR / f"index{PACK_SUFFIX}"
    if not pack.exists():
        sys.exit(f"[FAIL] 缺少 {pack.name}")
    with pack.open("rb") as handle:
        magic = handle.read(4)
    if magic != b"GDPC":
        sys.exit(f"[FAIL] {pack.name} 头不是 GDPC，得到 {magic!r}，不是有效 pck")

    js = (OUT_DIR / "index.js").read_text(encoding="utf-8")
    if "${exe}.pck" in js:
        sys.exit("[FAIL] index.js 仍在找 ${exe}.pck")
    html = (OUT_DIR / "index.html").read_text(encoding="utf-8")
    match = re.search(r"GODOT_CONFIG = (\{.*?\});", html)
    if not match:
        sys.exit("[FAIL] index.html 里找不到 GODOT_CONFIG")
    config = json.loads(match.group(1))
    sizes = config.get("fileSizes", {})
    if f"index{PACK_SUFFIX}" not in sizes:
        sys.exit(f"[FAIL] GODOT_CONFIG.fileSizes 里没有 index{PACK_SUFFIX}")
    real = pack.stat().st_size
    if sizes[f"index{PACK_SUFFIX}"] != real:
        sys.exit(f"[FAIL] fileSizes 声明 {sizes[f'index{PACK_SUFFIX}']} 与实际 {real} 不符")
    wasm = OUT_DIR / "index.wasm"
    if "index.wasm" in sizes and sizes["index.wasm"] != wasm.stat().st_size:
        sys.exit("[FAIL] index.wasm 大小与声明不符")
    total = sum(f.stat().st_size for f in OUT_DIR.iterdir() if f.is_file())
    print(f"[OK] {pack.name} {real / 1048576:.1f} MiB（头 GDPC），引用一致，产物共 {total / 1048576:.1f} MiB")


def publish() -> None:
    script = Path.home() / ".workbuddy/skills/sofunny-resource-sharing/scripts/publish.py"
    if not script.exists():
        sys.exit(f"找不到发布脚本：{script}")
    result = run([sys.executable, str(script), "server", str(OUT_DIR)], text=True,
                 capture_output=True)
    print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        sys.exit(f"发布失败，退出码 {result.returncode}")
    if "已跳过" in result.stdout:
        # 静默跳过是最坏的失败：站点能打开但游戏起不来。
        sys.exit("[FAIL] 发布时有文件被跳过，检查后缀白名单")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--publish", action="store_true", help="构建后发布到内网分享服务")
    parser.add_argument("--skip-export", action="store_true", help="只做整理与校验")
    args = parser.parse_args()

    if not args.skip_export:
        export()
    rename_pack()
    patch_references()
    verify_pack()
    if args.publish:
        publish()


if __name__ == "__main__":
    main()
