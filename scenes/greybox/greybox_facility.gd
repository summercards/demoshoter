extends Area3D
## [PORT-STRIP 2026-10-21] 灰盒白盒设施：不依赖任何美术资产，但**可以真正使用**。
##
## 交互契约与 BaseFacility3D 对齐（PlayerInteractionController3D 只认这三样）：
##   1. 进组 "interaction_provider_3d"
##   2. get_interaction_candidate(player) -> Dictionary（available / interaction_id / position / priority / prompt）
##   3. set_interaction_focus(candidate, focused) / perform_interaction(player, candidate)
##
## perform_interaction 按 BaseFacilityCatalog 的 action_kind 分流：
##   ACTION_MENU  -> 把菜单场景实例化成 CanvasLayer 叠在当前场景上
##   ACTION_SCENE -> change_scene_to_file
##   ACTION_INFO  -> 只打日志
##
## 白盒尺寸按"和人差不多高"给（默认 1.8 m），footprint 1.4~2.0 m。

const PROVIDER_GROUP := "interaction_provider_3d"
const PLAYER_GROUP := "player_3d"
const PLAYER_GROUP_ALT := "player"
const FacilityCatalog = preload("res://src/base/BaseFacilityCatalog.gd")

@export var facility_id := ""
@export var box_size := Vector3(1.6, 1.8, 1.4)

var _definition: Dictionary = {}
var _player_in_range := false
var _prompt: Label3D
var _open_menu: Node = null


## 由 greybox_builder 调用：先设 id 与尺寸，再 add_child（那时才跑 _ready）。
func setup(p_facility_id: String, p_box_size: Vector3) -> void:
	facility_id = p_facility_id
	box_size = p_box_size


func _ready() -> void:
	add_to_group(PROVIDER_GROUP)
	add_to_group("greybox_facility")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	_definition = FacilityCatalog.get_definition(facility_id)
	_build_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func get_display_name() -> String:
	var label_text := str(_definition.get("display_name", ""))
	if label_text.is_empty():
		label_text = facility_id
	return label_text


# ---------------------------------------------------------------- 几何

func _build_visual() -> void:
	var half := box_size * 0.5

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WhiteBox"
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.94, 0.96)
	mat.roughness = 0.55
	mesh_instance.material_override = mat
	mesh_instance.position = Vector3(0, half.y, 0)
	add_child(mesh_instance)

	# Area3D 不挡人，单独挂 StaticBody3D 当实体，玩家能撞到、能绕背面。
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	var solid_shape := CollisionShape3D.new()
	var solid_box := BoxShape3D.new()
	solid_box.size = box_size
	solid_shape.shape = solid_box
	solid.add_child(solid_shape)
	solid.position = Vector3(0, half.y, 0)
	add_child(solid)

	# 交互感应体比实体略大，站到跟前就能进范围。
	var area_shape := CollisionShape3D.new()
	area_shape.name = "SenseShape"
	var area_box := BoxShape3D.new()
	area_box.size = box_size + Vector3(1.4, 0.8, 1.4)
	area_shape.shape = area_box
	area_shape.position = Vector3(0, half.y, 0)
	add_child(area_shape)

	var name_label := Label3D.new()
	name_label.name = "NameLabel"
	name_label.text = get_display_name()
	name_label.font_size = 42
	name_label.pixel_size = 0.006
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.outline_size = 10
	name_label.outline_modulate = Color(0.05, 0.06, 0.09)
	name_label.position = Vector3(0, box_size.y + 0.28, 0)
	add_child(name_label)

	_prompt = Label3D.new()
	_prompt.name = "PromptLabel"
	_prompt.text = "[E] 使用 %s" % get_display_name()
	_prompt.font_size = 32
	_prompt.pixel_size = 0.006
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.modulate = Color(1.0, 0.88, 0.45)
	_prompt.outline_size = 8
	_prompt.outline_modulate = Color(0.06, 0.05, 0.02)
	_prompt.position = Vector3(0, box_size.y - 0.18, 0)
	_prompt.visible = false
	add_child(_prompt)


# ---------------------------------------------------------------- 交互契约

func _is_player(body: Node3D) -> bool:
	return body.is_in_group(PLAYER_GROUP) or body.is_in_group(PLAYER_GROUP_ALT)


func _on_body_entered(body: Node3D) -> void:
	if body == null or not _is_player(body):
		return
	_player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body == null or not _is_player(body):
		return
	_player_in_range = false
	if _prompt != null:
		_prompt.visible = false


func get_interaction_candidate(_player: Player3D) -> Dictionary:
	if not _player_in_range:
		return {}
	return {
		"available": true,
		"interaction_id": "greybox_facility:%s" % facility_id,
		"position": global_position,
		"priority": 60,
		"prompt": "[E] 使用 %s" % get_display_name(),
	}


func set_interaction_focus(_candidate: Dictionary, focused: bool) -> void:
	if _prompt != null:
		_prompt.visible = focused and _player_in_range


func perform_interaction(_player: Player3D, _candidate: Dictionary) -> bool:
	if not _player_in_range:
		return false
	var action_kind := str(_definition.get("action_kind", FacilityCatalog.ACTION_INFO))
	var action_path := str(_definition.get("action_path", ""))
	match action_kind:
		FacilityCatalog.ACTION_MENU:
			return _delegate_open_menu(action_path, _player)
		FacilityCatalog.ACTION_SCENE:
			if action_path.is_empty() or not ResourceLoader.exists(action_path):
				push_warning("[GreyboxFacility] 场景不存在：%s" % action_path)
				return false
			return get_tree().change_scene_to_file(action_path) == OK
		_:
			print("[GREYBOX] %s 没有可用界面（action_kind=%s）" % [get_display_name(), action_kind])
			return true


# ---------------------------------------------------------------- 开界面

## 菜单不在设施里自建宿主：交给关卡根节点（与 BaseWorld3D._open_menu 同一套）。
func _delegate_open_menu(scene_path: String, player: Node) -> bool:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("[GreyboxFacility] 界面不存在：%s" % scene_path)
		return false
	var host: Node = null
	var node: Node = self
	while node != null:
		if node.has_method("_open_menu"):
			host = node
			break
		node = node.get_parent()
	if host == null:
		push_warning("[GreyboxFacility] 关卡根节点没有 _open_menu，无法打开界面：%s" % scene_path)
		return false
	return bool(host.call("_open_menu", scene_path, self))


func _on_menu_closed() -> void:
	_open_menu = null
