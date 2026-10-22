extends Dungeon3D
## Minimal content assembly. The inherited Dungeon3D owns combat, inventory,
## rewards, equipment transactions and persistence. Geometry stays user-authored.
@export var level_id: String = "greybox_home"
## 给加载页 / 日志看的可读标题。
@export var level_title: String = "GREYBOX 01"
## 地板边长（整数米，正方形）。
@export var floor_size_m: int = 60
## 墙高（整数米）。
@export var wall_height_m: int = 6
## 墙厚（整数米）。
@export var wall_thickness_m: int = 1
## 掩体块数量（0 = 不放掩体）。
@export var cover_count: int = 6
## 敌人占位数量（程序化胶囊，不依赖任何角色资产）。
@export var enemy_count: int = 3
## 布局变体：0 = 对称掩体阵（关 01）；1 = 斜向双排（关 02）。
@export var layout_variant: int = 0
## 玩家出生点（整数米）。
@export var spawn_offset_m: Vector3 = Vector3(0, 1, 20)
## 下一关 id；空串表示本关是链路终点，不放传送门。
@export var next_level_id: String = "99"
## 是否尝试实例化正式玩家（scenes/Player3D.tscn）；失败只告警，退化成纯出生点标记。
@export var spawn_real_player: bool = true

## [PORT-STRIP 2026-10-21] 是否在灰盒里摆一组白盒设施占位（测试用）。
## 原设施美术在 assets/art/environments/base_facility_3d（267 文件 / 142.9 MB），
## 已随 environments 整体移入 _removed_content，因此这里用纯程序化白盒 + 名牌占位，
## 让"走到设施前面、看清它是什么、验证交互入口"这件事能测，不需要任何美术资产。
@export var facility_boxes: bool = true

## 安全区 / 非安全区的分界（世界 z）。z >= 该值为安全区，z < 该值为非安全区（怪物在这边）。
@export var safe_zone_boundary_z: float = 0.0

## 白盒设施表：id 与 BaseFacilityCatalog 一一对应。
## 高度统一 1.8 m（"和人差不多高"），footprint 1.4~2.0 m，两排摆在出生点前方。
const FACILITY_BOXES := [
	{"id": "mission_operations", "size": Vector3(2.0, 1.8, 1.8), "pos": Vector3(-8.0, 0.0, 12.0)},
	{"id": "training_range", "size": Vector3(2.2, 1.8, 2.0), "pos": Vector3(-4.0, 0.0, 12.0)},
	{"id": "weapon_workshop", "size": Vector3(2.0, 1.8, 1.8), "pos": Vector3(0.0, 0.0, 12.0)},
	{"id": "weapon_forge", "size": Vector3(1.6, 1.8, 1.6), "pos": Vector3(4.0, 0.0, 12.0)},
	{"id": "vault", "size": Vector3(1.6, 1.8, 1.6), "pos": Vector3(8.0, 0.0, 12.0)},
	{"id": "monster_archive", "size": Vector3(1.8, 1.8, 1.8), "pos": Vector3(-8.0, 0.0, 16.0)},
	{"id": "fate_collection", "size": Vector3(1.8, 1.8, 1.8), "pos": Vector3(-4.0, 0.0, 16.0)},
	{"id": "base_vending", "size": Vector3(1.4, 1.8, 1.2), "pos": Vector3(0.0, 0.0, 16.0)},
	{"id": "base_recovery", "size": Vector3(1.8, 1.8, 1.8), "pos": Vector3(4.0, 0.0, 16.0)},
	{"id": "avatar_wardrobe", "size": Vector3(1.6, 1.8, 1.6), "pos": Vector3(8.0, 0.0, 16.0)},
]


const FACILITY_SCENE := preload("res://assets/art/props/base_world_3d/prp_base_facility_root_top3d.tscn")
const GREYBOX_ROOM_SCRIPT := preload("res://scenes/greybox/greybox_room.gd")
const LOADING_SCREEN_SCENE := "res://scenes/ExpeditionLoadingScreen.tscn"

## ===== 刷怪开关（2026-10-22 主人要求）=====
##
## 只做「开关」这一件事，刷怪本身**一行都不重写**，全部走关卡里既有的那套
## **运行时遭遇事件**（正式名；口头叫「倒计时刷怪」）：
##
##   room.encounter（下面 `_greybox_encounter()` 的数据）
##     → Dungeon3D._build_room_encounter_config()   ← 现成构造器，固定
##         completion=timer / progress_mode=tick / hud_countdown=true
##     → Dungeon3D.start_encounter_event()          ← 唯一入口
##
## 之所以必须走构造器而不是自己拼 config：`progress_mode=tick` + `completion=timer`
## 这两条正是「自己走 1 分钟倒计时、时间到就不再出怪」的定义，写死在构造器里。
## 自己在灰盒里另拼一份就等于复制了一份平行实现，改一处漏一处。
const SPAWN_SWITCH_DURATION_SEC := 60.0
## 场景内可交互开关（带白圆点、走近按 E）。见 greybox_spawn_switch_3d.gd。
const SPAWN_SWITCH_SCRIPT := preload("res://scenes/greybox/greybox_spawn_switch_3d.gd")
var _spawn_switch: Area3D = null
var _part_names: Array[String] = []
var _atmosphere: TowerAtmosphere3D
var _portal_fired := false

func _ready() -> void:
	visual_theme = DungeonTheme3D.new()
	gameplay_theme = load("res://data/map_themes/iron_frontier.tres")
	return_scene_path = "res://scenes/greybox/GreyboxLevel01.tscn"
	set_meta("loading_scene_ready", false)
	await super._ready()
	player.global_position = spawn_offset_m
	_install_world_time_hud()
	_build_facilities()
	_build_exit_portal()
	_build_spawn_switch()
	set_meta("greybox_level_id", level_id)
	set_meta("greybox_generated", true)
	set_meta("loading_scene_ready", true)
	set_meta("loading_bootstrap_pending", false)
	if IrisTransition != null:
		IrisTransition.complete_loading(false)

func _configure_environment() -> void:
	super._configure_environment()
	if OS.get_environment("GB_NO_BASELINE") != "1":
		_apply_main_world_environment_baseline()
	_atmosphere = TowerAtmosphere3D.new()
	_atmosphere.name = "TowerAtmosphere3D"
	_atmosphere.background_music_enabled = false
	_atmosphere.configure(world_environment.environment, key_light)
	add_child(_atmosphere)


## 灰盒代表「主世界」，光影基线必须与 TowerDescent3D.tscn 的
## Environment_editor_runtime_match 逐项一致；Dungeon3D 自带的暗室基线
## （ambient 0.16~0.22 / fog 0.075）是给封闭房间用的，直接沿用它会让灰盒
## 昼夜都糊成一片灰。这里只改 Environment 基线，TowerAtmosphere3D 仍按
## GameTimeManager 的太阳快照继续接管 background / ambient / fog 的动态部分。
func _apply_main_world_environment_baseline() -> void:
	var environment := world_environment.environment
	if environment == null:
		return
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.62, 0.64, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = Color(0.45, 0.52, 0.60, 1.0)
	environment.ambient_light_energy = 0.01
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.18
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.40, 0.48, 0.55, 1.0)
	environment.fog_light_energy = 0.36
	environment.fog_density = 0.04
	environment.fog_height = 0.0
	environment.fog_height_density = 0.0

func _generate_layout_for_loading() -> void:
	_generate_layout()
	await get_tree().process_frame

func _generate_layout() -> void:
	_build_floor()
	_build_walls()
	_build_cover()
	_build_safe_zone()
	var room := GREYBOX_ROOM_SCRIPT.new() as DungeonRoom3D
	room.name = "GreyboxRoom"
	room.configure({"room_id":"start", "room_type":"START", "theme":visual_theme,
		"custom_dimensions":Vector2(floor_size_m, floor_size_m), "seed":run_seed,
		"search_facilities_enabled":false})
	$GeneratedRooms.add_child(room)
	_rooms.append(room)
	_room_by_id["start"] = room
	_records.append({"id":"start", "type":"START", "size":"large", "index":0,
		"main":true, "position":Vector3.ZERO, "doors":[], "door_targets":{},
		"custom_dimensions":Vector2(floor_size_m,floor_size_m), "parent":""})
	_build_topology()
	minimap.configure(_records, _open_edges)
	minimap.reveal_room("start")
	room.player_entered.connect(_on_room_entered)
	room.prop_searched.connect(_on_prop_searched)
	room.service_activated.connect(_on_service_activated)
	room.light_toggled.connect(_on_room_light_toggled)
	# 刷怪开关的数据源。键名全部是 Dungeon3D._build_room_encounter_config 已经在读的
	# 正式键（触发器刷怪设计 §3.3），不新增任何机制键：
	#   · duration_sec —— 这一轮刷怪持续多久（主人指定 1 分钟）
	#   · stages       —— 每一波的怪物编成；at_sec 由构造器自动给，这里不写
	#   · seal_room=false —— 主人要「只是刷怪」，不封门，其它什么都不变
	#   · hunt_player  —— 让怪主动来找玩家；否则野外潜行逻辑下会有怪站着不动，
	#                    点下去像「没刷出来」，那就不是刷怪开关了
	#   · hud_countdown —— 右上角那枚倒计时环，是这套机制自带的表现，不是新加 UI
	room.encounter = _greybox_encounter()
	room.ensure_shell_built()
	# No starter content collection: the inherited guaranteed pistol/ammo is retained.
	_spawned_rooms["start"] = true
	_spawn_greybox_enemies.call_deferred()

func _spawn_greybox_enemies() -> void:
	var room := _room_by_id.get("start") as DungeonRoom3D
	var configs: Array[Dictionary] = []
	var positions: Array = []
	for i in enemy_count:
		configs.append(_monster_injector.generate_box_enemy("melee_chaser", 1, 1))
		var pos := _enemy_position(i, enemy_count)
		positions.append(Vector3(pos.x, 0.1, pos.y))
	_spawn_enemy_batch(room, configs, false, false, positions)


## 开关点下去之后要刷的怪。只提供**编成**，不提供机制：
## `completion` / `progress_mode` / `stage_advance` 的缺省值由
## `Dungeon3D._build_room_encounter_config` 给出（timer / tick / clear），
## 这里再写一遍就是复制平行实现。
##
## 波数多于「60 秒内能打完」的量是刻意的：这开关要的是「一分钟持续刷怪」，
## 玩家杀得快就一直有下一波，杀得慢就到点收工（倒计时结束不再开工）。
func _greybox_encounter() -> Dictionary:
	return {
		"duration_sec": SPAWN_SWITCH_DURATION_SEC,
		"seal_room": false,
		"hunt_player": true,
		"hud_countdown": true,
		"start_delay_sec": 1.0,
		"stages": [
			{"monsters": [{"type": "melee_chaser", "count": 4}]},
			{"monsters": [{"type": "melee_chaser", "count": 5}]},
			{"monsters": [{"type": "melee_chaser", "count": 5}]},
			{"monsters": [{"type": "melee_chaser", "count": 6}]},
			{"monsters": [{"type": "melee_chaser", "count": 6}]},
			{"monsters": [{"type": "melee_chaser", "count": 7}]},
		],
	}


## 刷怪开关本体。**场景里的可交互物件**（走过去按 E），不是 HUD 按钮 ——
## 视觉与交互契约照抄 RoomLightSwitch3D，圆点由 PlayerInteractionController3D 统一画。
## 摆位：玩家出生点 (0,0,20) 前方 2 m 的空地上，z=18 一带没有设施白盒。
func _build_spawn_switch() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var room := _room_by_id.get("start") as DungeonRoom3D
	if room == null:
		return
	var switch := SPAWN_SWITCH_SCRIPT.new() as Area3D
	switch.name = "SpawnSwitch"
	switch.set("host", self)
	switch.set("room", room)
	switch.position = Vector3(0.0, 0.0, 18.0)
	add_child(switch)
	_spawn_switch = switch

func _build_facilities() -> void:
	if not facility_boxes:
		return
	for entry in FACILITY_BOXES:
		var facility := FACILITY_SCENE.instantiate() as BaseFacility3D
		facility.name = "Facility_%s" % entry.id
		facility.facility_id = entry.id
		facility.position = entry.pos
		facility.base_size_multiplier = 1.0
		facility.beacon_light_enabled = false
		facility.activated.connect(_on_greybox_facility_activated, CONNECT_DEFERRED)
		add_child(facility)
		_apply_greybox_facility_visual(facility, entry.size)

## 与 TowerDescent3D._on_facility_activated 同构：活跃菜单挡重复触发，
## 状态栏写设施自述，OPEN_MENU 走继承来的 _open_facility_menu（注入背包/玩家/设施）。
## 菜单路径取 facility.menu_scene_path —— BaseFacility3D._apply_catalog_definition()
## 已在 _ready 从 BaseFacilityCatalog 补齐，和原工程各设施 prefab 里的值同源。
func _on_greybox_facility_activated(facility: BaseFacility3D) -> void:
	if _active_facility_menu != null and is_instance_valid(_active_facility_menu):
		return
	status_label.text = "%s：%s" % [facility.display_name, facility.description]
	if facility.activation_type == BaseFacility3D.ActivationType.OPEN_MENU:
		_open_facility_menu(facility.menu_scene_path, facility)
		return
	if facility.activation_type == BaseFacility3D.ActivationType.LOAD_SCENE:
		if ResourceLoader.exists(facility.target_scene_path):
			get_tree().change_scene_to_file(facility.target_scene_path)

func get_runtime_map_id() -> String:
	return level_id

func _runtime_scope_for_save(_floor_index: int, _room_id: String) -> String:
	return "base" if facility_boxes else "combat"

func _base_runtime_restore_position(_room: DungeonRoom3D) -> Vector3:
	return spawn_offset_m

func _finish_run(success: bool) -> void:
	if success:
		await _finish_expedition_successful_extraction()
	else:
		super._finish_run(false)

func _return_to_scene_after_settlement(entry_request_id: int) -> void:
	IrisTransition.loading_destination_scene = return_scene_path
	IrisTransition.loading_destination_name = "初始灰盒"
	var result := get_tree().change_scene_to_file(LOADING_SCREEN_SCENE)
	if result != OK:
		GameEntryFlow.cancel_request(entry_request_id)
		push_error("灰盒返航加载失败")

func _build_exit_portal() -> void:
	# Home departs through the original intelligence-room transaction.
	# The round returns via the original extraction / settlement interaction.
	if facility_boxes:
		return
	_standard_extraction = _create_extraction_beacon(_room_by_id["start"], "STANDARD", 4.0, false, Vector3(0,0,-float(floor_size_m)*0.5+6))
	_conditional_extractions["STANDARD"] = _standard_extraction

# ---------------------------------------------------------------- 构建：四面墙

func _build_walls() -> void:
	var span := float(floor_size_m)
	var height := float(wall_height_m)
	var thick := float(wall_thickness_m)
	var y := height * 0.5
	var mat := _mat(Color(0.34, 0.36, 0.40))
	_add_box(self, "WallNorth", Vector3(span, height, thick), Vector3(0, y, -span * 0.5), mat)
	_add_box(self, "WallSouth", Vector3(span, height, thick), Vector3(0, y, span * 0.5), mat)
	_add_box(self, "WallWest", Vector3(thick, height, span), Vector3(-span * 0.5, y, 0), mat)
	_add_box(self, "WallEast", Vector3(thick, height, span), Vector3(span * 0.5, y, 0), mat)


# ---------------------------------------------------------------- 构建：灯光

func _build_cover() -> void:
	if cover_count <= 0:
		return
	var mat := _mat(Color(0.46, 0.42, 0.34))
	var count := cover_count
	for i in count:
		var pos := _cover_position(i, count)
		var height := 2.0 if i % 2 == 0 else 3.0
		var size := Vector3(4.0, height, 4.0) if i % 3 == 0 else Vector3(5.0, height, 2.0)
		_add_box(self, "Cover%02d" % i, size, Vector3(pos.x, height * 0.5, pos.y), mat)


## 整数米落点：变体 0 打对称双列，变体 1 走斜向双排。

func _cover_position(index: int, count: int) -> Vector2:
	var half := floor_size_m * 0.5
	if layout_variant == 0:
		var rows := int(ceil(float(count) / 2.0))
		var col := index % 2
		var row := index / 2
		var x := -10.0 if col == 0 else 10.0
		var z_step := (half - 8.0) / float(maxi(rows, 1))
		var z := -half + 8.0 + z_step * float(row)
		return Vector2(x, z)
	var diag_x := -half + 10.0 + 7.0 * float(index)
	var diag_z := -half + 10.0 + 5.0 * float(index)
	return Vector2(diag_x, diag_z)


# ---------------------------------------------------------------- 构建：白盒设施

## 摆一组白盒设施：高度 1.8 m，能撞、能绕、走近按 E 能真的打开对应界面。

func _build_safe_zone() -> void:
	var span := float(floor_size_m)
	var line_height := 0.08
	var line_depth := 1.2
	var mat := _mat(Color(0.95, 0.80, 0.20), 0.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.80, 0.20)
	mat.emission_energy_multiplier = 1.6
	var line := _add_box(
		self,
		"SafeZoneLine",
		Vector3(span, line_height, line_depth),
		Vector3(0.0, line_height * 0.5, safe_zone_boundary_z),
		mat
	)
	line.collision_layer = 0
	line.collision_mask = 0
	line.add_to_group("greybox_safe_line")
	line.set_meta("safe_zone_boundary_z", safe_zone_boundary_z)
	# Main-world daylight and sky bounce are owned by TowerAtmosphere3D.
	print("[GREYBOX] safe_line z=%.1f depth=%.1f" % [safe_zone_boundary_z, line_depth])


# ---------------------------------------------------------------- 构建：HUD

func _build_facility_light() -> void:
	var light := OmniLight3D.new()
	light.name = "FacilityLight"
	light.position = Vector3(0.0, 6.5, 14.0)
	light.light_energy = 2.4
	light.omni_range = 26.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = true
	add_child(light)
	_part_names.append("FacilityLight")


# ---------------------------------------------------------------- 构建：安全区标线

## 地板中线画一条亮黄实线：出生侧（z >= safe_zone_boundary_z）是安全区，另一侧是非安全区。
## 标线不参与碰撞（collision_layer/mask 清零），避免玩家被 8 cm 高的坎绊住。

func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position: Vector3,
	material: StandardMaterial3D
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	parent.add_child(body)
	_part_names.append(node_name)
	return body

func _mat(color: Color, metallic := 0.0, roughness := 0.9) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func _enemy_position(index: int, count: int) -> Vector2:
	var spread := 6.0
	var x := -spread * float(count - 1) * 0.5 + spread * float(index)
	# 全部落在非安全区（z < safe_zone_boundary_z），并避开 z=-24 的出口传送门。
	var z := safe_zone_boundary_z - 8.0 - 3.0 * float(index % 3)
	return Vector2(x, z)


# ---------------------------------------------------------------- 构建：出生点

func _resolve_player() -> Node:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group("player_3d")
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	return player

# ---------------------------------------------------------------- 构建：敌人


func _build_floor() -> void:
	var size := Vector3(float(floor_size_m), 1.0, float(floor_size_m))
	# 地板顶面压在 y=0，墙和掩体都从 0 往上长，方便整数米对齐。
	_add_box(self, "GreyboxFloor", size, Vector3(0, -0.5, 0), _mat(Color(0.22, 0.24, 0.26)))


# ---------------------------------------------------------------- 构建：四面墙


func _activate_runtime_persistence() -> void:
	super._activate_runtime_persistence()
	_sync_inventory_weapon_tree({})
	if not player.weapon_instance_changed.is_connected(_sync_inventory_weapon_tree):
		player.weapon_instance_changed.connect(_sync_inventory_weapon_tree)

func _sync_inventory_weapon_tree(_snapshot: Dictionary) -> void:
	if _inventory_ui != null and is_instance_valid(player):
		_inventory_ui.set_weapon_tree(player.get_weapon_tree())

func _apply_greybox_facility_visual(facility: BaseFacility3D, size: Vector3) -> void:
	# Presentation only: keep original provider, labels, availability and signals.
	var mesh := BoxMesh.new()
	mesh.size = size
	facility.base_mesh.mesh = mesh
	facility.base_mesh.position = Vector3(0,size.y*0.5,0)
	facility.base_mesh.material_override = _mat(Color(0.93,0.94,0.96))
	for child_name in ["Roof", "Door", "Beacon"]:
		facility.get_node(child_name).hide()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := facility.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
	collision.shape = shape
	collision.position = Vector3(0,size.y*0.5,0)
	facility.name_label.position = Vector3(0,size.y+0.28,0)
	facility.prompt_label.position = Vector3(0,size.y+0.6,0)

func _setup_run_modules() -> void:
	print("TRACE modules begin")
	super._setup_run_modules()
	print("TRACE modules end")

func _install_holographic_hud_style() -> void:
	print("TRACE hud begin")
	super._install_holographic_hud_style()
	print("TRACE hud end")
