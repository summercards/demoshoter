extends SceneTree
## [PORT-STRIP 2026-10-21] 灰盒关卡验收脚本。
## 判据：两个灰盒能被加载页实例化（根节点 + 脚本 + 五件套齐全）、
##       加载契约 meta 已上报、1/2 关卡 id 映射正确、01→02 链路不断。
## 跑法：Godot --headless --path <proj> --script res://tests/verification/verify_greybox_levels.gd
##
## 注意：_initialize 阶段 root 还没跑起来，add_child 不会触发 _ready；
## 所以统一延后到第一帧之后再装配场景、再做检查。

const L01 := "res://scenes/greybox/GreyboxLevel01.tscn"
const L02 := "res://scenes/greybox/GreyboxLevel02.tscn"

var _fail := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_check_config()
	await _check_scene("GreyboxLevel01", L01, "expedition_01", 3, 6)
	await _check_scene("GreyboxLevel02", L02, "expedition_02", 5, 8)
	await _check_chain()
	print("VERIFY_RESULT=%s FAILURES=%d" % ["PASS" if _fail == 0 else "FAIL", _fail])
	quit(0 if _fail == 0 else 1)


func _ok(label: String, condition: bool, detail := "") -> void:
	if condition:
		print("PASS  %s %s" % [label, detail])
	else:
		_fail += 1
		print("FAIL  %s %s" % [label, detail])


func _check_config() -> void:
	_ok("config 1 -> 灰盒01", GameDesignConfig.expedition_level_scene("1") == L01, GameDesignConfig.expedition_level_scene("1"))
	_ok("config 2 -> 灰盒02", GameDesignConfig.expedition_level_scene("2") == L02, GameDesignConfig.expedition_level_scene("2"))
	_ok("config expedition_01 -> 灰盒01", GameDesignConfig.expedition_level_scene("expedition_01") == L01)
	_ok("config expedition_02 -> 灰盒02", GameDesignConfig.expedition_level_scene("expedition_02") == L02)
	_ok("config 99 -> 兜底灰盒01", GameDesignConfig.expedition_level_scene("99") == L01, GameDesignConfig.expedition_level_scene("99"))
	_ok("config 未登记 id -> 兜底灰盒01", GameDesignConfig.expedition_level_scene("no_such_level") == L01)
	_ok("config 空 id -> 兜底灰盒01（绝不为空）", GameDesignConfig.expedition_level_scene("") != "")
	_ok("run_id 未登记 -> 兜底非空", GameDesignConfig.expedition_scene_for_run_id("no_such_run") != "")


func _check_scene(label: String, path: String, expect_level: String, enemies: int, covers: int) -> void:
	_ok("%s 资源存在" % label, ResourceLoader.exists(path))
	var packed := load(path) as PackedScene
	_ok("%s 可实例化" % label, packed != null)
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	_ok("%s 实例是 Node3D" % label, inst != null)
	if inst == null:
		return
	_ok("%s 根节点挂了脚本" % label, inst.get_script() != null)
	root.add_child(inst)
	await process_frame
	await process_frame

	_ok("%s level_id" % label, str(inst.get_meta("greybox_level_id", "")) == expect_level, str(inst.get_meta("greybox_level_id", "")))
	_ok("%s 地板" % label, inst.has_node("GreyboxFloor"))
	var walls := 0
	for wall_name in ["WallNorth", "WallSouth", "WallEast", "WallWest"]:
		if inst.has_node(wall_name):
			walls += 1
	_ok("%s 四面墙" % label, walls == 4, "%d/4" % walls)
	_ok("%s DirectionalLight3D" % label, inst.has_node("DirectionalLight3D"))
	var env_node := inst.get_node_or_null("GreyboxWorldEnvironment") as WorldEnvironment
	_ok("%s 环境光" % label, env_node != null and env_node.environment != null)
	_ok("%s 玩家出生点" % label, inst.has_node("PlayerSpawn"))
	var enemy_nodes := inst.find_children("GreyboxEnemy*", "CharacterBody3D", true, false)
	_ok("%s 敌人数量" % label, enemy_nodes.size() == enemies, "%d/%d" % [enemy_nodes.size(), enemies])
	var cover_nodes := inst.find_children("Cover*", "StaticBody3D", true, false)
	_ok("%s 掩体数量" % label, cover_nodes.size() == covers, "%d/%d" % [cover_nodes.size(), covers])
	_ok("%s 加载契约 meta" % label, bool(inst.get_meta("loading_scene_ready", false)))
	_ok("%s 场景路径可被加载页识别" % label, inst.scene_file_path == path, inst.scene_file_path)
	print("INFO  %s 构件数=%s 玩家已实例化=%s" % [label, str(inst.get_meta("greybox_part_count", -1)), str(inst.get_meta("greybox_player_spawned", false))])

	inst.free()


func _check_chain() -> void:
	var packed := load(L01) as PackedScene
	if packed == null:
		_ok("01→02 链路：01 可加载", false)
		return
	var inst := packed.instantiate() as Node3D
	root.add_child(inst)
	await process_frame
	await process_frame
	var portal := inst.get_node_or_null("ExitPortal")
	_ok("01 有出口传送门", portal != null)
	if portal != null:
		_ok("01 传送门指向 expedition_02", str(portal.get_meta("greybox_next_level", "")) == "expedition_02")
	inst.free()

	# 复刻传送门运行时动作：登记下一关 → 加载页消费 pending → 解析目标场景。
	_ok("登记 expedition_02", GameDesignConfig.select_expedition_level("expedition_02"))
	var pending := GameDesignConfig.consume_pending_expedition_level_id()
	_ok("pending 消费为 expedition_02", pending == "expedition_02", pending)
	var target := GameDesignConfig.expedition_level_scene(pending)
	_ok("01→02 解析到灰盒 02", target == L02, target)
	_ok("01→02 目标场景存在", ResourceLoader.exists(target))

	_ok("登记 expedition_01（回环）", GameDesignConfig.select_expedition_level("expedition_01"))
	var back := GameDesignConfig.consume_pending_expedition_level_id()
	_ok("02→01 解析到灰盒 01", GameDesignConfig.expedition_level_scene(back) == L01)
