extends Node


func _ready() -> void:
	var expected_name := OS.get_environment("SHELLSTORM_VERIFICATION_USER_DIR_NAME")
	var cache_isolated := OS.get_environment("SHELLSTORM_VERIFICATION_CACHE_ISOLATED")
	var actual_dir := OS.get_user_data_dir()
	var failures: Array[String] = []
	if expected_name.is_empty():
		failures.append("统一验收runner没有声明隔离用户目录")
	elif not actual_dir.ends_with("/" + expected_name):
		failures.append("Autoload使用的user://不是runner隔离目录：%s" % actual_dir)
	# ⚠ 真实玩家数据目录**不能写死名字**：它由 project.godot 决定 ——
	# `use_custom_user_dir=true` 时取 `custom_user_dir_name`，否则取 `config/name`。
	# 旧版把「弹壳风暴2」写死在这里，而本项目一直有 custom_user_dir_name="ShellStorm2Port"，
	# 于是 user:// 永远不等于「弹壳风暴2」⇒ 这条断言从来没可能触发（假绿）。
	# 现在按引擎的真实规则推导，改名（config/name 已改「弹壳风暴-青春版」）也不再失准。
	var real_dir_name := _real_user_dir_name()
	if not real_dir_name.is_empty() and actual_dir.ends_with("/" + real_dir_name):
		failures.append("验收仍指向正式玩家数据目录：%s" % actual_dir)
	if cache_isolated != "1":
		failures.append("统一验收runner没有使用独立.godot导入缓存")
	if failures.is_empty():
		print("VERIFICATION_RUNNER_CONTRACT_OK: preflight, autoload user data and .godot import cache are isolated")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


## 按 Godot 的 user dir 规则推导真实目录名（不含父路径）。
func _real_user_dir_name() -> String:
	if bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)):
		return str(ProjectSettings.get_setting("application/config/custom_user_dir_name", ""))
	return str(ProjectSettings.get_setting("application/config/name", ""))
