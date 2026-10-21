class_name PortStripEnvAssets
extends RefCounted
## [PORT-STRIP 2026-10-21] environments 目录已整目录移出到 _removed_content。
## 原 preload() 改为可选加载：资源不存在时返回 null，由调用方跳过，
## 保证工程仍可导入 / 启动；把 environments 搬回来后自动恢复原行为。

static func asset(path: String):
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)

static func scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as PackedScene

static func resource(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)
