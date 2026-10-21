extends CanvasLayer
## [PORT-STRIP 2026-10-21] 灰盒关卡的功能层 HUD 挂载器。
##
## 这里**不实现任何功能**，只把老工程（Dungeon3D）里已有的功能层组件原样挂上来：
##   血条      —— ProgressBar 延迟白段 + HPBar + 居中读数（口径同 Dungeon3D._on_player_hp_changed）
##   弹药      —— HUDPresenter3D 产出的 ammo_text 投影（`N · M备弹`）
##   武器图标  —— ItemModelIcon3D（正式 3D 图标控件，res://assets/art/ui/inventory_3d/ui_item_model_icon_root.tscn）
##   换弹环    —— HudReloadRing（正式脚本，跟随角色投影）
##   战术背包  —— InventoryUI（正式背包面板，Tab / I 开关）
##   暂停层    —— ui_pause_overlay_screen.tscn（由 Global 的 pause 动作驱动）
##
## 鼠标：老工程全程 MOUSE_MODE_VISIBLE，瞄准由 Player3D 把光标投影到世界平面，
## 本脚本不调用 set_mouse_mode、不画屏幕中心准星。

const HUD_UI_SCALE := 0.80
const HUD_PRESENTER_SCRIPT := preload("res://src/ui/HUDPresenter3D.gd")
const HUD_RELOAD_RING_SCRIPT := preload("res://src/ui/HudReloadRing.gd")
const CODE_HUD_GLYPH_SCRIPT := preload("res://src/ui/CodeHUDGlyph.gd")
const ITEM_MODEL_ICON_SCENE: PackedScene = preload("res://assets/art/ui/inventory_3d/ui_item_model_icon_root.tscn")
const PAUSE_OVERLAY_SCENE := "res://assets/art/ui/pause_3d/ui_pause_overlay_screen.tscn"

## 与 Dungeon3D 同一口径：换弹环外径 31.25 设计 px、角色偏移 (42.5, 12.5) 设计 px。
const HUD_RELOAD_RING_OUTER_DIAMETER_DESIGN := 31.25
const HUD_RELOAD_RING_CHARACTER_OFFSET_DESIGN := Vector2(42.5, 12.5)
## 与 Dungeon3D 同一口径：背包 40 格、快捷物品 2 格。
const BASE_INVENTORY_CAPACITY := 40
const QUICK_INVENTORY_CAPACITY := 2

var _root: Control
var _player: Node3D = null
var _hud_presenter: HUDPresenter3D = null
var _inventory: InventoryModule
var _quick_inventory: InventoryModule
var _insurance: InsuranceModule
var _inventory_ui: InventoryUI = null

var _hp_bar: ProgressBar
var _hp_delayed: ProgressBar
var _hp_label: Label
var _ammo_label: Label
var _fate_label: Label
var _weapon_icon: ItemModelIcon3D = null
var _reload_ring: Control = null
var _reload_active := false
var _delayed_ratio := 1.0
var _last_hp := -1


func _ready() -> void:
	layer = 91
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_vitals()
	_build_weapon_panel()
	_build_reload_ring()
	_build_inventory()
	_mount_pause_overlay()
	_bind_player()


# ---------------------------------------------------------------- 血条
func _build_vitals() -> void:
	var panel := PanelContainer.new()
	panel.name = "PlayerStatusPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "点击打开/关闭背包 [键 I / Tab]"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(18, 104)
	panel.custom_minimum_size = _hud_size(Vector2(248, 54))
	panel.add_theme_stylebox_override("panel", _bar_style(Color(0.02, 0.06, 0.10, 0.55), 6))
	_root.add_child(panel)
	panel.gui_input.connect(_on_status_panel_input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _hud_int(10))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var portrait := CODE_HUD_GLYPH_SCRIPT.new() as CodeHUDGlyph
	portrait.custom_minimum_size = _hud_size(Vector2(42, 42))
	portrait.configure("robot", Color(1.0, 0.25, 0.84))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)

	var stack := Control.new()
	stack.name = "PlayerHealthBarStack"
	stack.custom_minimum_size = _hud_size(Vector2(220, 26))
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stack)

	_hp_delayed = ProgressBar.new()
	_hp_delayed.name = "PlayerHealthBarDelayed"
	_hp_delayed.show_percentage = false
	_hp_delayed.custom_minimum_size = _hud_size(Vector2(220, 26))
	_hp_delayed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_delayed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_delayed.add_theme_stylebox_override("background", _bar_style(UIPalette.PRISM_HP_BG, 3))
	_hp_delayed.add_theme_stylebox_override("fill", _bar_style(Color(1.0, 0.96, 0.92, 0.85), 3))
	stack.add_child(_hp_delayed)

	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = _hud_size(Vector2(220, 26))
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.add_theme_stylebox_override("background", _bar_style(Color(0.12, 0.02, 0.04, 0.0), 3))
	_hp_bar.add_theme_stylebox_override("fill", _bar_style(UIPalette.PRISM_HP_RED, 3))
	stack.add_child(_hp_bar)

	_hp_label = _make_label("230 / 230", 14, Color.WHITE, stack)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# ---------------------------------------------------------------- 武器栏（图标 + 弹药）
func _build_weapon_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "CurrentWeaponPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -_hud_size(Vector2(300, 0)).x
	panel.offset_top = -_hud_size(Vector2(0, 76)).y
	panel.offset_right = -18
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _bar_style(Color(0.02, 0.06, 0.10, 0.0), 4))
	_root.add_child(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", _hud_int(8))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var keycap := Label.new()
	keycap.name = "WeaponSlotKeycap"
	keycap.text = "1"
	keycap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keycap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keycap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keycap.custom_minimum_size = _hud_size(Vector2(22, 20))
	keycap.add_theme_font_size_override("font_size", 12)
	keycap.add_theme_color_override("font_color", Color(0.05, 0.07, 0.09))
	keycap.add_theme_stylebox_override("normal", _bar_style(Color(0.94, 0.96, 0.98), 5))
	row.add_child(keycap)

	_weapon_icon = ITEM_MODEL_ICON_SCENE.instantiate() as ItemModelIcon3D
	_weapon_icon.name = "CurrentWeaponModelIcon3D"
	_weapon_icon.custom_minimum_size = _hud_size(Vector2(60, 44))
	_weapon_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_weapon_icon)

	_ammo_label = _make_label("0 · 0备弹", 21, Color.WHITE, row)
	_ammo_label.custom_minimum_size = _hud_size(Vector2(92, 42))
	_ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_fate_label = _make_label("0/0", 12, UIPalette.PRISM_ACCENT, row)
	_fate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


# ---------------------------------------------------------------- 换弹环
func _build_reload_ring() -> void:
	_reload_ring = HUD_RELOAD_RING_SCRIPT.new() as Control
	_reload_ring.name = "HudReloadRing"
	_reload_ring.z_index = 1
	_reload_ring.visible = false
	_reload_ring.size = _hud_size(
		Vector2(HUD_RELOAD_RING_OUTER_DIAMETER_DESIGN, HUD_RELOAD_RING_OUTER_DIAMETER_DESIGN)
	)
	_reload_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_reload_ring)


# ---------------------------------------------------------------- 战术背包
func _build_inventory() -> void:
	_inventory = InventoryModule.new(BASE_INVENTORY_CAPACITY)
	_quick_inventory = InventoryModule.new(QUICK_INVENTORY_CAPACITY)
	_insurance = InsuranceModule.new()
	_inventory_ui = InventoryUI.new()
	_inventory_ui.name = "InventoryUI3D"
	_inventory_ui.accept_tab_shortcut = true
	_root.add_child(_inventory_ui)
	_inventory_ui.set_inventory_module(_inventory)
	_inventory_ui.set_insurance_module(_insurance)
	_inventory_ui.set_quick_item_module(_quick_inventory)
	if _player != null and _player.has_method("get_weapon_tree"):
		_inventory_ui.set_weapon_tree(_player.call("get_weapon_tree"))
	if _player != null:
		_inventory_ui.set_weapon_owner(_player)
	_inventory_ui.set_backpack_owner(self)
	_inventory_ui.set_world_drop_handler(_on_world_drop_requested)


func _on_world_drop_requested(item: Dictionary, count: int) -> void:
	print("[GreyboxHUD] 丢弃请求：%s ×%d（灰盒无落地拾取实体）" % [
		str(item.get("name", item.get("id", ""))), count
	])


# ---------------------------------------------------------------- 暂停层（与老工程同场景）
func _mount_pause_overlay() -> void:
	if not ResourceLoader.exists(PAUSE_OVERLAY_SCENE):
		push_warning("[GreyboxHUD] 暂停层缺失：%s" % PAUSE_OVERLAY_SCENE)
		return
	var packed := load(PAUSE_OVERLAY_SCENE) as PackedScene
	if packed == null:
		return
	var overlay := packed.instantiate()
	if overlay == null:
		return
	overlay.name = "PauseOverlay"
	add_child(overlay)


# ---------------------------------------------------------------- 玩家接线
func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player_3d")
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("[GreyboxHUD] 未找到玩家，功能层 HUD 等待下一帧重试")
		call_deferred("_bind_player")
		return
	_hud_presenter = HUD_PRESENTER_SCRIPT.new()
	_hud_presenter.weapon_hud_command_ready.connect(_apply_weapon_hud_command)
	if _player.has_signal("hp_changed"):
		_player.connect("hp_changed", _on_player_hp_changed)
	if _player.has_signal("ammo_changed"):
		_player.connect("ammo_changed", _on_ammo_changed)
	if _player.has_signal("reload_progress_changed"):
		_player.connect("reload_progress_changed", _on_reload_progress_changed)
	if _player.has_signal("reload_started"):
		_player.connect("reload_started", _on_reload_started)
	if _player.has_signal("reload_ended"):
		_player.connect("reload_ended", _on_reload_ended)
	if _player.has_signal("weapon_instance_changed"):
		_player.connect("weapon_instance_changed", _on_weapon_instance_changed)
	_refresh_vitals()
	_refresh_weapon(true)


func _refresh_vitals() -> void:
	if _player == null:
		return
	if _player.has_method("get_max_health") and _player.has_method("get_health"):
		_on_player_hp_changed(int(_player.call("get_health")), int(_player.call("get_max_health")))
	elif _player.get("current_hp") != null:
		_on_player_hp_changed(int(_player.get("current_hp")), int(_player.get("max_hp")))


func _on_player_hp_changed(current: int, maximum: int) -> void:
	if _hp_label == null:
		return
	_hp_label.text = "%d / %d" % [current, maximum]
	_hp_bar.max_value = maxi(1, maximum)
	_hp_bar.value = clampi(current, 0, maximum)
	var ratio := float(current) / float(maxi(1, maximum))
	_hp_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.28, 0.22) if ratio <= 0.30 else Color(0.92, 0.95, 1.0)
	)
	var took_damage := _last_hp >= 0 and current < _last_hp
	_last_hp = current
	_hp_delayed.max_value = _hp_bar.max_value
	if took_damage and ratio < _delayed_ratio:
		pass
	else:
		_delayed_ratio = ratio
	_hp_delayed.value = _delayed_ratio * _hp_delayed.max_value


func _on_ammo_changed(current: int, maximum: int) -> void:
	if _player == null or _hud_presenter == null:
		return
	_hud_presenter.present_weapon(
		_player.call("get_weapon_presentation_snapshot") if _player.has_method("get_weapon_presentation_snapshot") else {},
		_player.call("get_weapon_snapshot") if _player.has_method("get_weapon_snapshot") else {},
		int(_player.call("get_active_weapon_slot")) if _player.has_method("get_active_weapon_slot") else 0,
		current,
		maximum,
		_player.call("get_equipped_weapon_item") if _player.has_method("get_equipped_weapon_item") else {}
	)


func _refresh_weapon(force := false) -> void:
	if _player == null or _hud_presenter == null:
		return
	var weapon_snapshot: Dictionary = _player.call("get_weapon_snapshot") if _player.has_method("get_weapon_snapshot") else {}
	_hud_presenter.present_weapon(
		_player.call("get_weapon_presentation_snapshot") if _player.has_method("get_weapon_presentation_snapshot") else {},
		weapon_snapshot,
		int(_player.call("get_active_weapon_slot")) if _player.has_method("get_active_weapon_slot") else 0,
		int(weapon_snapshot.get("current_ammo", 0)),
		int(weapon_snapshot.get("magazine_size", 0)),
		_player.call("get_equipped_weapon_item") if _player.has_method("get_equipped_weapon_item") else {},
		force
	)


## 与 Dungeon3D._apply_weapon_hud_command 同口径：只做投影，不解析弹药上限。
func _apply_weapon_hud_command(command: Dictionary) -> void:
	if _ammo_label != null:
		var ammo_text := str(command.get("ammo_text", "0 / 0"))
		if ammo_text.begins_with("近战"):
			_ammo_label.text = ammo_text
		else:
			var display := "%d" % int(command.get("ammo_current", 0))
			display += " · %d备弹" % _reserve_ammo_count()
			_ammo_label.text = display
	if _fate_label != null:
		_fate_label.text = "%d/%d" % [
			int(command.get("fate_slot_used", 0)),
			int(command.get("fate_slot_capacity", 0)),
		]
	if _weapon_icon == null:
		return
	var action := str(command.get("model_action", "keep"))
	var item: Dictionary = command.get("weapon_item", {}) as Dictionary
	if action == "clear":
		_weapon_icon.clear_model()
	elif action == "replace" and not item.is_empty():
		_weapon_icon.configure(item)


func _reserve_ammo_count() -> int:
	var total := 0
	if _inventory != null:
		total += _inventory.get_item_count("item_ammo_pack")
	if _quick_inventory != null:
		total += _quick_inventory.get_item_count("item_ammo_pack")
	return total


# ---------------------------------------------------------------- 换弹环
func _on_reload_started(_duration: float) -> void:
	_reload_active = true


func _on_reload_progress_changed(progress: float, _remaining: float) -> void:
	if _reload_ring == null:
		return
	_reload_active = true
	_reload_ring.set("progress", progress)
	_place_reload_ring()


func _on_reload_ended(_completed: bool) -> void:
	_reload_active = false
	if _reload_ring != null:
		_reload_ring.set("progress", 0.0)
		_reload_ring.visible = false


func _on_weapon_instance_changed(_snapshot: Dictionary) -> void:
	_refresh_weapon(true)


func _process(delta: float) -> void:
	_tick_delayed_bar(delta)
	if _reload_active:
		_place_reload_ring()


func _tick_delayed_bar(delta: float) -> void:
	if _hp_delayed == null or _hp_bar == null:
		return
	var actual := _hp_bar.value / maxf(1.0, _hp_bar.max_value)
	if _delayed_ratio <= actual:
		return
	# 白段以 0.55/s 速度朝真实血量收，永不越过红条。
	_delayed_ratio = move_toward(_delayed_ratio, actual, delta * 0.55)
	_hp_delayed.value = _delayed_ratio * _hp_delayed.max_value


## 与 Dungeon3D._place_hud_reload_ring 同算法：角色世界坐标 → 视口坐标 → 控件局部坐标。
func _place_reload_ring() -> void:
	if _reload_ring == null or _player == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(_player.global_position):
		_reload_ring.visible = false
		return
	var target := camera.unproject_position(_player.global_position)
	var parent := _reload_ring.get_parent() as Control
	if parent != null:
		target = parent.get_global_transform_with_canvas().affine_inverse() * target
	target += _hud_size(HUD_RELOAD_RING_CHARACTER_OFFSET_DESIGN)
	_reload_ring.position = target - _reload_ring.size * 0.5
	_reload_ring.visible = _reload_active


# ---------------------------------------------------------------- 工具
func _on_status_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _inventory_ui != null:
			_inventory_ui.toggle_inventory_panel()
			get_viewport().set_input_as_handled()


func _hud_size(design: Vector2) -> Vector2:
	return design * HUD_UI_SCALE


func _hud_int(design: int) -> int:
	return int(round(design * HUD_UI_SCALE))


func _make_label(text: String, font_size: int, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", maxi(8, int(round(font_size * HUD_UI_SCALE))))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label


func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
