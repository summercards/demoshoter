extends CanvasLayer
## [PORT-STRIP 2026-10-21] 灰盒 HUD 外壳。
##
## 这一层**不发明任何鼠标逻辑**，完全对标老工程：
##   1. 老工程全程不抓鼠标（`src` 内 0 处 set_mouse_mode），鼠标常驻可见，
##      由 `Player3D._update_aim_from_mouse()` 把屏幕光标沿相机射线投到角色的水平面上，
##      再用 `AimCursor`（Ring + Dot）标出落点 —— 所以这里**不画**屏幕中心准星，
##      也不调用 set_mouse_mode，否则光标被锁在中心，瞄准直接失效。
##   2. 暂停键（`pause`，Esc）由 `Global._input` 统一接管：遍历 `pause_input_guard` 组，
##      再 `toggle_pause()`。老工程的 `PauseOverlay` 是 `Dungeon3D.tscn` 里挂在 HUD 下的
##      `ui_pause_overlay_screen.tscn` 实例。这里照抄同一结构：把它实例化挂到本层，
##      由 PauseMenu3D 自己响应 `Global.game_paused`，不由本脚本开关。
##
## 本脚本只做灰盒需要的最少信息显示：关卡名 / 坐标 / 安全区状态 / 操作提示。

const PLAYER_GROUP := "player_3d"
const PLAYER_GROUP_ALT := "player"
## 暂停层由 greybox_feature_hud.gd 挂载（与老工程同一个 ui_pause_overlay_screen.tscn），
## 这里不再重复挂第二份，避免出现两个 pause_input_guard。

var _title_label: Label
var _zone_label: Label
var _hint_label: Label
var _boundary_z := 0.0
var _level_title := "GREYBOX"


func configure(p_level_title: String, p_boundary_z: float) -> void:
	_level_title = p_level_title
	_boundary_z = p_boundary_z


func _ready() -> void:
	layer = 90
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_title_label = _make_label(root, 22, Color(1, 1, 1))
	_title_label.position = Vector2(24, 16)

	_zone_label = _make_label(root, 20, Color(0.45, 0.95, 0.55))
	_zone_label.position = Vector2(24, 46)

	_hint_label = _make_label(root, 16, Color(0.82, 0.86, 0.90))
	_hint_label.position = Vector2(24, 76)
	_hint_label.text = "WASD 移动 · 移动鼠标瞄准（光标即落点）· 左键射击 · R 换弹 · E 交互 · Esc 暂停"

	_refresh()


func _make_label(parent: Control, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _zone_label == null:
		return
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP)
	if player == null:
		player = get_tree().get_first_node_in_group(PLAYER_GROUP_ALT)
	if player is Node3D:
		var pos := (player as Node3D).global_position
		var in_safe := pos.z >= _boundary_z
		_zone_label.text = "安全区" if in_safe else "非安全区 · 有怪物"
		_zone_label.add_theme_color_override(
			"font_color",
			Color(0.45, 0.95, 0.55) if in_safe else Color(1.0, 0.42, 0.38)
		)
		_title_label.text = "%s · 坐标 X %.0f / Z %.0f" % [_level_title, pos.x, pos.z]
	else:
		_zone_label.text = "等待玩家"
		_title_label.text = _level_title
