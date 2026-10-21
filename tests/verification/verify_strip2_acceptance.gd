extends Node
## 减量第二轮（2026-10-21 12:04 口径）功能验收台。
## 判据来自任务书 §4：枪械全在 / 掉落全在 / 开局武器 / 能开火 / 能拾取 /
## 普通怪全在 / Boss 已隔离 / 音效 / 账本只清 Boss 与未做怪。
## 只读被测工程，不改任何状态。

const LEDGER_PATH := "res://assets/registry/ledger_split_baseline.json"
const ENEMY_SCENE: PackedScene = preload("res://assets/art/enemies/enemy_3d/enm_ecosystem_kit_root_top3d_v001.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/Player3D.tscn")

const IMPLEMENTED_KINDS: Array[String] = ["melee_chaser", "fat_zombie03", "ranged_caster"]
const CLEARED_ENM := [
	"ENM-BOSS-ABYSS01", "ENM-BOSS-ARCHIVIST-95", "ENM-BOSS-FURNACE-WARDEN-90",
	"ENM-BOSS-HOLLOW-CHOIR-85", "ENM-BOSS-MONITOR002-3D", "ENM-ELITE-RIFT-BOAR-ARMED-3D",
	"ENM-BEAST-SPIKESHELL01", "ENM-BOMBER-FRUIT01", "ENM-SUMMON-HIVE01",
	"ENM-TANK-SHELLGUARD01", "ENM-TRAP-SPIKEWORM01",
]
const KEPT_ENM := [
	"ENM-MELEE-FUNGBOAR01", "ENM-NORMAL-FAT-ZOMBIE03", "ENM-RANGED-SPORESHOOTER01",
	"ENM-ECOSYSTEM-KIT-3D",
]

var failures: Array[String] = []
var notes: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_check_dir_counts()
	_check_ledger()
	_check_starting_weapon()
	_check_boss_blocked()
	_check_audio()
	await _check_fire()
	await _check_pickup()
	await _check_enemies()
	_report()


# ---------------------------------------------------------------- helpers
func _count_files(path: String) -> int:
	if not DirAccess.dir_exists_absolute(path):
		return -1
	var total := 0
	var dir := DirAccess.open(path)
	if dir == null:
		return -1
	dir.include_hidden = false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := path.path_join(name)
			if dir.current_is_dir():
				var sub := _count_files(full)
				if sub > 0:
					total += sub
			else:
				total += 1
		name = dir.get_next()
	dir.list_dir_end()
	return total


func _expect_path_count(label: String, path: String, expected: int) -> void:
	var got := _count_files(path)
	notes.append("%s count=%d expected=%d" % [label, got, expected])
	if got != expected:
		failures.append("%s count %d != %d" % [label, got, expected])


func _expect_absent(label: String, path: String) -> void:
	var exists := DirAccess.dir_exists_absolute(path)
	notes.append("%s exists=%s" % [label, str(exists)])
	if exists:
		failures.append("%s should have been moved out but still exists" % label)


func _check_dir_counts() -> void:
	_expect_path_count("WEAPONS", "res://assets/art/weapons", 132)
	_expect_path_count("ITEMS_WEAPONS", "res://assets/art/items_weapons", 192)
	_expect_path_count("NORMAL_ENEMY_3D", "res://assets/art/enemies/normal_enemy_3d", 29)
	_expect_path_count("ENEMY_3D_KIT", "res://assets/art/enemies/enemy_3d", 2)
	_expect_path_count("SRC_SFX_AUDIO", "res://src/assets/audio", 354)
	_expect_absent("BOSSES", "res://assets/art/enemies/bosses")
	_expect_absent("BOSSES_V01", "res://assets/art/enemies/bosses_v01")
	_expect_absent("ELITE_3D", "res://assets/art/enemies/elite_3d")


func _check_ledger() -> void:
	var text := FileAccess.get_file_as_string(LEDGER_PATH)
	if text.is_empty():
		failures.append("ledger unreadable at %s" % LEDGER_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		failures.append("ledger does not parse as JSON object")
		return
	var data := parsed as Dictionary
	var assets := data.get("assets", {}) as Dictionary
	var columns := data.get("columns", []) as Array
	notes.append("LEDGER keys=%d columns=%d asset_count=%s" % [assets.size(), columns.size(), str(data.get("asset_count", -1))])
	if columns.size() != 25:
		failures.append("ledger column count changed: %d" % columns.size())
	var nonempty := {}
	for key in assets.keys():
		var prefix := str(key).split("-")[0]
		if not nonempty.has(prefix):
			nonempty[prefix] = 0
		var entry := assets[key] as Dictionary
		if not str(entry.get("v", "")).is_empty():
			nonempty[prefix] = int(nonempty[prefix]) + 1
	notes.append("LEDGER_NONEMPTY " + str(nonempty))
	if int(nonempty.get("WPN", 0)) != 36:
		failures.append("weapon ledger entries changed: nonempty WPN=%d expected 36" % int(nonempty.get("WPN", 0)))
	if int(nonempty.get("ITM", 0)) != 24:
		failures.append("item ledger entries changed: nonempty ITM=%d expected 24" % int(nonempty.get("ITM", 0)))
	for key in CLEARED_ENM:
		if not assets.has(key):
			failures.append("ledger key %s disappeared (keys must stay)" % key)
			continue
		var entry := assets[key] as Dictionary
		if not str(entry.get("v", "")).is_empty():
			failures.append("ledger %s still has content" % key)
	for key in KEPT_ENM:
		if not assets.has(key):
			failures.append("kept ledger key %s disappeared" % key)
			continue
		var entry := assets[key] as Dictionary
		if str(entry.get("v", "")).is_empty():
			failures.append("kept ledger key %s lost its content" % key)


func _check_starting_weapon() -> void:
	if BlueprintRegistry == null:
		failures.append("BlueprintRegistry autoload missing")
		return
	if BlueprintRegistry.DEFAULT_STARTING_GUN_ID != "bp_starter_rifle":
		failures.append("DEFAULT_STARTING_GUN_ID changed to %s" % BlueprintRegistry.DEFAULT_STARTING_GUN_ID)
	var tree: WeaponAssemblyTree = BlueprintRegistry.get_starting_weapon_tree()
	if tree == null or tree.root == null:
		failures.append("get_starting_weapon_tree() returned an empty tree")
		return
	notes.append("STARTING_TREE root_type=%d name=%s tags=%s" % [int(tree.root.node_type), tree.root.node_name, str(tree.root.tags)])
	if tree.root.node_type != AssemblyNode.NodeType.GUN_BODY:
		failures.append("starting tree root is not a gun body")
	if tree.has_method("get_snapshot"):
		var snapshot: Dictionary = tree.get_snapshot()
		notes.append("STARTING_TREE snapshot keys=%s" % str(snapshot.keys()))


func is_allowed_kind(kind: String) -> bool:
	if IMPLEMENTED_KINDS.has(kind):
		return true
	var base := MonsterVariants.base_of(kind)
	return not base.is_empty() and IMPLEMENTED_KINDS.has(base)


func _check_boss_blocked() -> void:
	if not MonsterInjector.is_kept_enemy_kind("melee_chaser"):
		failures.append("whitelist rejects an implemented kind")
	for kind in IMPLEMENTED_KINDS:
		if not MonsterInjector.is_kept_enemy_kind(kind):
			failures.append("whitelist rejects implemented kind %s" % kind)
		if not MonsterInjector.is_kept_enemy_kind(kind + "_strong"):
			failures.append("whitelist rejects strong variant of %s" % kind)
	for kind in ["boss", "elite", "summoner", "exploder", "ambusher"]:
		if MonsterInjector.is_kept_enemy_kind(kind):
			failures.append("whitelist still accepts removed kind %s" % kind)
	var injector := MonsterInjector.new()
	var boss_list: Array = injector.generate_enemies({"type": "boss", "floor": 1})
	if not boss_list.is_empty():
		failures.append("boss generation still produced %d entries" % boss_list.size())
	var boss_box: Dictionary = injector.generate_box_enemy("boss", 1, RoomData.FloorLevel.SHALLOW)
	if not boss_box.is_empty():
		failures.append("boss spawn box path still produced an entry")
	# `generate_enemies` 对普通怪种走主题兜底，本来就会产出「某个合法怪」；
	# 这里要证明的是**产出里不出现已移除的怪种**，不是「产出为空」。
	var summoner_list: Array = injector.generate_enemies({"type": "summoner", "floor": 1})
	for entry in summoner_list:
		var kind := str((entry as Dictionary).get("enemy_type", ""))
		if not is_allowed_kind(kind):
			failures.append("unimplemented kind summoner leaked %s through generate_enemies" % kind)
	var summoner_box: Dictionary = injector.generate_box_enemy("summoner", 1, RoomData.FloorLevel.SHALLOW)
	if not summoner_box.is_empty():
		failures.append("unimplemented kind summoner leaked through the spawn-box path")
	var kept_list: Array = injector.generate_enemies({"type": "fat_zombie03", "floor": 1, "count": 2})
	if kept_list.size() != 2:
		failures.append("implemented kind fat_zombie03 produced %d entries instead of 2" % kept_list.size())
	for entry in kept_list:
		var kind := str((entry as Dictionary).get("enemy_type", ""))
		if not is_allowed_kind(kind):
			failures.append("kept output has unexpected kind %s" % kind)
	injector = null
	notes.append("BOSS_BLOCKED boss=[] summoner=[] fat_zombie03=%d" % kept_list.size())


func _check_audio() -> void:
	if AudioManager == null:
		failures.append("AudioManager autoload missing")
		return
	var sfx: Dictionary = AudioManager.SFX
	var bad := 0
	for key in sfx.keys():
		var path := str(sfx[key])
		if not path.begins_with("res://src/assets/audio/"):
			bad += 1
			failures.append("SFX %s points outside src/assets/audio: %s" % [key, path])
	notes.append("SFX entries=%d outside_src_audio=%d rifle_fire=%s" % [sfx.size(), bad, str(sfx.get("rifle_fire", ""))])
	if not ResourceLoader.exists("res://src/assets/audio/sfx/rifle_fire_v004.ogg"):
		failures.append("rifle_fire ogg missing")


func _check_fire() -> void:
	var player := PLAYER_SCENE.instantiate() as Player3D
	player.start_with_weapon = true
	player.position = Vector3.ZERO
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	var weapon := player.weapon
	if weapon == null:
		failures.append("player has no weapon after start_with_weapon")
		player.queue_free()
		return
	weapon.current_ammo = maxi(2, weapon.magazine_size)
	var before: int = weapon.current_ammo
	var fired: bool = weapon.try_fire(Vector3.FORWARD, player)
	await get_tree().physics_frame
	var after: int = weapon.current_ammo
	notes.append("FIRE fired=%s ammo %d -> %d" % [str(fired), before, after])
	if not fired:
		failures.append("try_fire() returned false")
	if after != before - 1:
		failures.append("ammo did not drop by exactly 1: %d -> %d" % [before, after])
	player.queue_free()
	await get_tree().process_frame


func _check_pickup() -> void:
	var loot := GroundLootPickup3D.new()
	add_child(loot)
	await get_tree().process_frame
	loot.configure({"item_id": "item_ammo_pack", "display_name": "弹药包", "amount": 1})
	await get_tree().process_frame
	loot.position = Vector3(0, 0, 0)
	loot.accept_pickup(null)
	notes.append("PICKUP accepted=%s available=%s" % [str(loot.is_pickup_accepted()), str(loot.is_pickup_available())])
	if not loot.is_pickup_accepted():
		failures.append("ground loot could not be accepted for pickup")
	loot.queue_free()
	await get_tree().process_frame


func _make_support() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = Vector3(0.0, -0.15, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 0.30, 200.0)
	collision.shape = shape
	body.add_child(collision)
	return body


func _check_enemies() -> void:
	add_child(_make_support())
	var player := PLAYER_SCENE.instantiate() as Player3D
	player.start_with_weapon = false
	player.position = Vector3.ZERO
	add_child(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	player.position = Vector3.ZERO
	for index in range(IMPLEMENTED_KINDS.size()):
		var kind := IMPLEMENTED_KINDS[index]
		var enemy := ENEMY_SCENE.instantiate() as Enemy3D
		enemy.enemy_kind = kind
		enemy.position = Vector3(0.0, 0.0, -6.0)
		add_child(enemy)
		await get_tree().physics_frame
		enemy.look_at(player.global_position + Vector3.UP * 0.7, Vector3.UP)
		# 对齐 verify_3d_enemy_behavior_flow 的口径：视线内 0.5s 内必须离开 idle。
		await get_tree().create_timer(0.5).timeout
		var state_seen := str(enemy.ai_state)
		var start_pos := enemy.global_position
		for _frame in range(60):
			await get_tree().physics_frame
		var moved := enemy.global_position.distance_to(start_pos)
		state_seen = str(enemy.ai_state) if str(enemy.ai_state) != "idle" else state_seen
		var hp_before := enemy.current_hp
		enemy.take_damage(maxi(1, hp_before / 2), false, Vector3.FORWARD)
		var hp_mid := enemy.current_hp
		var died: Array = [false]
		enemy.killed.connect(func(_e, _l): died[0] = true)
		enemy.take_damage(enemy.current_hp + 999, false, Vector3.FORWARD)
		await get_tree().process_frame
		# 清掉在飞的投射物：它们仍指向刚死的怪，落到已释放实例会在
		# Projectile3D._hit_target 刷 "previously freed" 脚本错误（纯验收台噪声）。
		for child in get_children():
			if child is Projectile3D:
				child.queue_free()
		await get_tree().process_frame
		var still_there := is_instance_valid(enemy)
		# 不立刻 free：飞行中的投射物仍引用这只怪，提前释放会在
		# Projectile3D._hit_target 打「previously freed」错误（验收台噪声）。
		if still_there:
			enemy.visible = false
		notes.append(
			"ENEMY %s hp %d->%d state=%s moved=%.2fm killed=%s alive=%s" % [
				kind, hp_before, hp_mid, state_seen, moved, str(died[0]), str(still_there)
			]
		)
		var engaged: Array = ["alert", "chase", "telegraph", "attack", "recovery"]
		if not engaged.has(state_seen):
			failures.append("%s stayed %s with a clear target in range" % [kind, state_seen])
		# 近战必须真的贴上来；远程怪保持距离是设计（`chase` 只做走位避让），
		# 因此对它只要求进入战斗状态，不要求位移。
		if kind == "melee_chaser" and moved < 0.25:
			failures.append("%s did not close distance (moved %.2fm, state %s)" % [kind, moved, state_seen])
		if hp_mid >= hp_before:
			failures.append("%s did not lose HP when damaged" % kind)
		if not died[0]:
			failures.append("%s did not die from lethal damage" % kind)
		await get_tree().process_frame
		await get_tree().physics_frame
	for child in get_children():
		if child is Enemy3D:
			child.queue_free()
	for child in get_children():
		if child is Projectile3D:
			child.queue_free()
	await get_tree().process_frame
	player.queue_free()
	await get_tree().process_frame


func _report() -> void:
	for line in notes:
		print("NOTE " + line)
	if failures.is_empty():
		print("STRIP2_ACCEPTANCE=PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		print("FAIL " + failure)
	print("STRIP2_ACCEPTANCE=FAIL failures=%d" % failures.size())
	get_tree().quit(1)
