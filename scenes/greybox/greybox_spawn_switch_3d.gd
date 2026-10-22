extends Area3D
## 灰盒里的「刷怪开关」——**场景里的可交互物件**，不是 HUD 按钮。
##
## 交互完全走现成系统，不新增一套：
##   · 加入 `interaction_provider_3d` 组，实现 `get_interaction_candidate` /
##     `perform_interaction`，`PlayerInteractionController3D` 就会自动创建并驱动
##     那枚**白圆点**（InteractionDot3D），玩家走进范围时提示 `[E] 开始刷怪`。
##   · 视觉参数照抄 `RoomLightSwitch3D._build_visual()`：同一块面板、同一颗指示球、
##     同一个 Label3D 提示口径。所以它看起来就是场景里本来就有的一类开关。
##
## 刷怪本身**一行不动**：点下去只调宿主的现成入口
##   host.start_encounter_event(host._build_room_encounter_config(room))
## 那对函数就是关卡里「倒计时刷怪」的正式实现（timer + tick）。

signal activated()

## 与 RoomLightSwitch3D 同值：走进去 2.2 m 内才算够得着。
const INTERACTION_RANGE := 2.2
## 用掉之后多久重新出现。主人指定 1 分钟。
const RESPAWN_SECONDS := 60.0

var host: Dungeon3D = null
var room: DungeonRoom3D = null
var _player_in_range := false
## 是否可用。「使用后消失」= visible=false 且不再给交互候选。
var _armed := true
var _indicator_material: StandardMaterial3D
var _body: Node3D


func _ready() -> void:
	add_to_group("greybox_spawn_switch_3d")
	add_to_group(PlayerInteractionController3D.PROVIDER_GROUP)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	_build_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visual()


# ===== 交互契约（与 RoomLightSwitch3D 同形）=====

func get_interaction_candidate(_player: Player3D) -> Dictionary:
	if not _armed or not _player_in_range:
		return {}
	return {
		"available": true,
		"interaction_id": "greybox_spawn_switch:%d" % get_instance_id(),
		"position": global_position,
		"priority": 50,
		"prompt": "[E] 开始刷怪",
	}


## ⚠ 提示文字**不由 Label3D 显示**：常驻圆点（InteractionDot3D）已经会画
## `[E] 开始刷怪`，两处都显示就会叠成重影（实测截图里正是两条叠在一起）。
## 与 RoomLightSwitch3D 同口径 —— 它把 `set_prompt_visible` 写成 no-op，
## 文字提示牌只当文案载体。这里直接不建 Label3D，省一个节点。
func set_interaction_focus(_candidate: Dictionary, _focused: bool) -> void:
	pass


func perform_interaction(_player: Player3D, _candidate: Dictionary) -> bool:
	if not _armed or host == null or room == null:
		return false
	var ok := _fire()
	if ok:
		# ⚠ 恢复要等 60 秒，不能写在 _fire() 里 —— 带 await 的函数是协程，
		# 而交互契约 perform_interaction 必须同步返回 bool。拆成两段。
		_rearm_later()
	return ok


## 圆点锚点：指示球所在高度（与灯开关同口径）。
func get_interaction_dot_anchor() -> Vector3:
	return global_position + Vector3.UP * 1.75


func is_interaction_dot_visible() -> bool:
	return _armed


# ===== 刷怪（只调现成入口）=====

## 同步部分：置为已使用 + 启动遭遇。失败立刻恢复可用。
func _fire() -> bool:
	_armed = false
	_update_visual()
	var started: Dictionary = host.call(
		"start_encounter_event", host.call("_build_room_encounter_config", room)
	)
	if not bool(started.get("ok", false)):
		# 启动失败就立刻恢复，不静默吞掉。
		push_warning("[greybox] 刷怪开关启动失败：%s" % str(started))
		_armed = true
		_update_visual()
		return false
	activated.emit()
	return true


## 延迟部分：到点重新出现。
func _rearm_later() -> void:
	await get_tree().create_timer(RESPAWN_SECONDS).timeout
	if not is_instance_valid(self):
		return
	_armed = true
	_update_visual()


func _update_visual() -> void:
	visible = _armed
	monitoring = _armed
	if _indicator_material != null:
		var color := Color(0.26, 0.92, 0.50) if _armed else Color(0.32, 0.34, 0.36)
		_indicator_material.albedo_color = color
		_indicator_material.emission = color


# ===== 视觉（参数照抄 RoomLightSwitch3D._build_visual）=====

func _build_visual() -> void:
	if get_node_or_null("SwitchPlate") != null:
		return
	_body = Node3D.new()
	_body.name = "SwitchBody"
	add_child(_body)

	var metal := _material(Color(0.10, 0.12, 0.13), 0.72, 0.34)
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.54, 0.72, 0.14)
	plate_mesh.material = metal
	var plate := MeshInstance3D.new()
	plate.name = "SwitchPlate"
	plate.position.y = 1.0
	plate.mesh = plate_mesh
	_body.add_child(plate)

	_indicator_material = _material(Color(0.26, 0.92, 0.50), 0.12, 0.30, true)
	var indicator_mesh := SphereMesh.new()
	indicator_mesh.radius = 0.075
	indicator_mesh.height = 0.15
	indicator_mesh.radial_segments = 10
	indicator_mesh.rings = 5
	indicator_mesh.material = _indicator_material
	var indicator := MeshInstance3D.new()
	indicator.name = "Indicator"
	indicator.position = Vector3(0, 1.17, -0.11)
	indicator.mesh = indicator_mesh
	_body.add_child(indicator)

	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.10, 0.28, 0.10)
	lever_mesh.material = _material(Color(0.66, 0.68, 0.65), 0.84, 0.24)
	var lever := MeshInstance3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, 0.91, -0.12)
	lever.mesh = lever_mesh
	_body.add_child(lever)

	# 底座：开关立在灰盒地面上。灰盒是**近垂直俯视**，竖直面板在屏幕上只剩一条边 ——
	# 所以必须靠这块水平圆盘把「这里有个装置」读出来。
	# 半径 0.62 / 亮灰，是为了在这个视角下仍有明显的圆形轮廓，不是装饰。
	var pad := _material(Color(0.82, 0.86, 0.88), 0.30, 0.42)
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.62
	base_mesh.bottom_radius = 0.66
	base_mesh.height = 0.08
	base_mesh.material = pad
	var stand := MeshInstance3D.new()
	stand.name = "Stand"
	stand.position.y = 0.04
	stand.mesh = base_mesh
	_body.add_child(stand)

	var shape := SphereShape3D.new()
	shape.radius = INTERACTION_RANGE
	var collision := CollisionShape3D.new()
	collision.name = "InteractionRange"
	collision.position.y = 0.9
	collision.shape = shape
	add_child(collision)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player_3d"):
		_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player_3d"):
		_player_in_range = false


func _material(color: Color, metallic: float, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material
