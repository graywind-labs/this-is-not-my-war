extends Node3D


const LAB_CONFIG_PATH := "res://data/presentation/npc_dev_lab.json"
const APPEARANCE_CONFIG_PATH := "res://data/presentation/character_appearances.json"
const NPC_PROFILES_PATH := "res://data/npc_profiles.json"
const ENEMY_WAVES_PATH := "res://data/enemy_waves.json"
const WEAPON_DEFS_PATH := "res://data/weapon_defs.json"
const ARMOR_DEFS_PATH := "res://data/armor_defs.json"
const HORSE_DEFS_PATH := "res://data/horse_defs.json"
const HORSE_SCENE_PATH := "res://assets/3d/quaternius/animals/merchant_horse.glb"
const ENEMY_MOUNTED_ART_SCRIPT := preload("res://scripts/presentation/characters/EnemyMountedArtView.gd")
const MOUNTED_PRESENTATION_REFERENCE := preload("res://scripts/presentation/characters/MountedPresentationReference.gd")
const HORSE_VISIBLE_FORWARD_LOCAL := MOUNTED_PRESENTATION_REFERENCE.VISIBLE_FORWARD_LOCAL
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const ENEMY_MOUNTED_UNIT_TYPES := ["cavalry", "mounted_ranged"]
const FRIENDLY_MOUNTED_UNCONSCIOUS_ACTION_ID := "friendly_mounted_unconscious"
const ENEMY_MOUNTED_DEFEAT_ACTION_ID := "mounted_defeat_escape"
const ENEMY_MOUNTED_ESCAPE_DISTANCE := 24.0

const SLOT_ORDER := ["main_weapon", "helmet", "chest", "bracers", "greaves", "mount"]
const SLOT_LABELS := {
	"main_weapon": "主武器",
	"helmet": "头盔",
	"chest": "胸甲",
	"bracers": "护臂",
	"greaves": "护腿",
	"mount": "坐骑",
}
const SLOT_POSITIONS := {
	"helmet": Vector2(115.0, 0.0),
	"chest": Vector2(115.0, 82.0),
	"bracers": Vector2(12.0, 108.0),
	"main_weapon": Vector2(218.0, 126.0),
	"greaves": Vector2(115.0, 169.0),
	"mount": Vector2(115.0, 238.0),
}
const FORMAL_WEAPON_MODEL_IDS := ["sword_shield", "polearm", "bow", "crossbow"]
const ROTATION_DRAG_SENSITIVITY_DEGREES := 0.38
const NON_MOUNTED_SEATED_ACTION_IDS := ["work_clinic_doctor", "seated_prayer", "seated_study", "seated_eating"]
const MOUNTED_ACTION_STATES := {
	"idle": "vehicle_seated",
	"walk": "mounted_walk",
	"run": "mounted_walk",
	"hit_react": "mounted_hit_react",
	"attack": "mounted_attack",
	"training_practice": "mounted_training",
	"mounted_pose": "vehicle_seated",
}
const MOUNTED_HORSE_ACTION_CLIPS := {
	"walk": "Walk",
	"run": "Gallop",
	"hit_react": "Idle_HitReact1",
	"friendly_mounted_unconscious": "Gallop",
}
const CHARACTER_MOUNT_BASE_Y := 0.12
const SEAT_PREVIEW_BACKWARD_OFFSET := 0.40
const SEATED_EATING_FORWARD_OFFSET := 0.12

@onready var _character_mount: Node3D = $Stage/CharacterMount
@onready var _horse_mount: Node3D = $Stage/HorseMount
@onready var _seat_preview: Node3D = $Stage/SeatPreview
@onready var _camera: Camera3D = $Camera3D
@onready var _rotation_drag_area: Area3D = $Stage/RotationDragArea

var _lab_config: Dictionary = {}
var _units: Array = []
var _units_by_id: Dictionary = {}
var _actions_by_id: Dictionary = {}
var _action_order: Array = []
var _equipment_options: Dictionary = {}
var _shared_loadout: Dictionary = {}

var _selected_unit_id := ""
var _mode := "work"
var _selected_action_id := "idle"
var _character: Node3D
var _horse_model: Node3D
var _last_enemy_mounted_escape_snapshot: Dictionary = {}
var _rotation_drag_active := false
var _preview_yaw_degrees := 0.0

var _unit_select: OptionButton
var _unit_name_label: Label
var _unit_detail_label: Label
var _work_mode_button: Button
var _combat_mode_button: Button
var _mode_note_label: Label
var _action_grid: GridContainer
var _action_buttons: Dictionary = {}
var _equipment_buttons: Dictionary = {}
var _status_label: Label
var _picker_panel: PanelContainer
var _picker_title: Label
var _picker_items: VBoxContainer


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 1.02, 0.0), Vector3.UP)
	_rotation_drag_area.input_event.connect(_on_rotation_drag_area_input_event)
	_lab_config = _read_json_dictionary(LAB_CONFIG_PATH)
	if _lab_config.is_empty():
		push_error("NPCDevLab config failed to load: %s" % LAB_CONFIG_PATH)
		return
	_build_catalogs()
	_shared_loadout = _empty_loadout()
	_build_ui()
	if not _units.is_empty():
		_select_unit(str((_units[0] as Dictionary).get("id", "")))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8:
		_return_to_main()


func _input(event: InputEvent) -> void:
	if not _rotation_drag_active:
		return
	if event is InputEventMouseMotion:
		_rotate_preview_by_pixels((event as InputEventMouseMotion).relative.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			_end_rotation_drag()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_rotation_drag()


func _on_rotation_drag_area_input_event(
	_viewport_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_event_normal: Vector3,
	_shape_index: int
) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	_rotation_drag_active = true
	get_viewport().set_input_as_handled()


func _rotate_preview_by_pixels(horizontal_pixels: float) -> void:
	if is_zero_approx(horizontal_pixels):
		return
	_preview_yaw_degrees = wrapf(
		_preview_yaw_degrees + horizontal_pixels * ROTATION_DRAG_SENSITIVITY_DEGREES,
		-180.0,
		180.0
	)
	_apply_preview_yaw()


func _apply_preview_yaw() -> void:
	_character_mount.rotation_degrees.y = _preview_yaw_degrees
	_horse_mount.rotation_degrees.y = _preview_yaw_degrees
	_seat_preview.rotation_degrees.y = _preview_yaw_degrees
	_position_character_mount(is_instance_valid(_horse_model) and _horse_model.visible, _seat_preview.visible)


func _end_rotation_drag() -> void:
	_rotation_drag_active = false


func _build_catalogs() -> void:
	for raw_action in _lab_config.get("actions", []):
		if not raw_action is Dictionary:
			continue
		var action := (raw_action as Dictionary).duplicate(true)
		var action_id := str(action.get("id", ""))
		if action_id.is_empty():
			continue
		_actions_by_id[action_id] = action
		_action_order.append(action_id)
	_build_friendly_units()
	_build_enemy_units()
	_build_equipment_options()


func _build_friendly_units() -> void:
	var appearance_config := _read_json_dictionary(APPEARANCE_CONFIG_PATH)
	var appearances: Dictionary = appearance_config.get("characters", {})
	var profiles := _read_json_array(NPC_PROFILES_PATH)
	var common_actions: Array = _lab_config.get("common_friendly_actions", [])
	var role_actions: Dictionary = _lab_config.get("role_actions", {})
	var role_labels: Dictionary = _lab_config.get("role_labels", {})
	for raw_profile in profiles:
		if not raw_profile is Dictionary:
			continue
		var profile := raw_profile as Dictionary
		var npc_id := str(profile.get("id", ""))
		var appearance: Dictionary = appearances.get(npc_id, {})
		if appearance.is_empty():
			continue
		var role := str(appearance.get("role", ""))
		var action_ids := _merge_unique(common_actions, role_actions.get(role, []))
		var unit := {
			"id": npc_id,
			"display_name": str(profile.get("name", appearance.get("display_name", npc_id))),
			"side": "friendly",
			"side_label": "我方 NPC",
			"role": role,
			"role_label": str(role_labels.get(role, profile.get("background_job", role))),
			"scene": str(appearance.get("scene", "")),
			"action_ids": action_ids,
			"default_mode": "work",
			"default_loadout": _normalize_loadout(profile.get("equipment", {})),
			"model_status": "正式两头身生产外观",
		}
		_register_unit(unit)


func _build_enemy_units() -> void:
	var preview: Dictionary = _lab_config.get("enemy_preview", {})
	var preview_scene := str(preview.get("default_scene", ""))
	var waves := _read_json_array(ENEMY_WAVES_PATH)
	var seen: Dictionary = {}
	for raw_wave in waves:
		if not raw_wave is Dictionary:
			continue
		for raw_enemy in (raw_wave as Dictionary).get("enemies", []):
			if not raw_enemy is Dictionary:
				continue
			var enemy := raw_enemy as Dictionary
			var enemy_type_id := str(enemy.get("enemy_type_id", ""))
			if enemy_type_id.is_empty() or seen.has(enemy_type_id):
				continue
			seen[enemy_type_id] = true
			var weapon_id := str(enemy.get("weapon_type", ""))
			# Weapon and mount are first-class enemy wave fields today. Keep the
			# optional equipment dictionary so future per-type armor becomes fixed
			# automatically instead of reopening the developer picker for enemies.
			var loadout := _normalize_loadout(enemy.get("equipment", {}))
			if not weapon_id.is_empty():
				loadout["main_weapon"] = _find_equipment_item(WEAPON_DEFS_PATH, weapon_id)
			if not str(enemy.get("mount_type", "")).is_empty():
				loadout["mount"] = {
					"id": "riding_horse",
					"horse_id": "enemy_preview_horse",
					"name": "敌军坐骑",
					"slot": "mount",
				}
			var unit_type := str(enemy.get("unit_type", ""))
			var mounted_enemy := unit_type in ENEMY_MOUNTED_UNIT_TYPES
			var action_ids: Array = (_lab_config.get("enemy_actions", []) as Array).duplicate()
			if mounted_enemy:
				action_ids = _merge_unique(action_ids, _lab_config.get("mounted_enemy_actions", []))
				action_ids.erase("unconscious")
				action_ids.erase("get_up")
			var model_ready := mounted_enemy or (FORMAL_WEAPON_MODEL_IDS.has(weapon_id) and str(enemy.get("mount_type", "")).is_empty())
			var unit := {
				"id": "enemy:%s" % enemy_type_id,
				"enemy_type_id": enemy_type_id,
				"display_name": str(enemy.get("name", enemy_type_id)),
				"side": "enemy",
				"side_label": "敌方单位",
				"role": unit_type,
				"role_label": _unit_type_label(unit_type),
				"scene": preview_scene,
				"action_ids": action_ids,
				"default_mode": "combat",
				"default_loadout": loadout,
				"model_status": ("正式骑兵包装（与 Main 共用）" if mounted_enemy else "正式两头身敌军包装（与 Main 共用）") if model_ready else "通用敌军临时外观（专属模型待制作）",
				"uses_formal_enemy_mount": mounted_enemy,
			}
			_register_unit(unit)


func _register_unit(unit: Dictionary) -> void:
	var unit_id := str(unit.get("id", ""))
	if unit_id.is_empty() or _units_by_id.has(unit_id):
		return
	_units.append(unit)
	_units_by_id[unit_id] = unit


func _build_equipment_options() -> void:
	for slot in SLOT_ORDER:
		_equipment_options[slot] = []
	for raw_weapon in _read_json_array(WEAPON_DEFS_PATH):
		if raw_weapon is Dictionary:
			(_equipment_options["main_weapon"] as Array).append((raw_weapon as Dictionary).duplicate(true))
	for raw_armor in _read_json_array(ARMOR_DEFS_PATH):
		if not raw_armor is Dictionary:
			continue
		var armor := (raw_armor as Dictionary).duplicate(true)
		var slot := str(armor.get("slot", ""))
		if _equipment_options.has(slot):
			(_equipment_options[slot] as Array).append(armor)
	var horse_defs := _read_json_dictionary(HORSE_DEFS_PATH)
	var templates_by_id := {}
	for raw_template in horse_defs.get("horse_templates", []):
		if raw_template is Dictionary:
			templates_by_id[str((raw_template as Dictionary).get("template_id", ""))] = (raw_template as Dictionary).duplicate(true)
	for raw_horse in horse_defs.get("initial_horses", []):
		if not raw_horse is Dictionary:
			continue
		var horse := (raw_horse as Dictionary).duplicate(true)
		var template: Dictionary = templates_by_id.get(str(horse.get("template_id", "")), {})
		for key in template:
			horse[key] = template[key]
		horse["id"] = "riding_horse"
		horse["slot"] = "mount"
		(_equipment_options["mount"] as Array).append(horse)


func _build_ui() -> void:
	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(overlay)

	_build_unit_panel(overlay)
	_build_mode_panel(overlay)
	_build_rotation_hint(overlay)
	_build_action_panel(overlay)
	_build_equipment_panel(overlay)
	_build_status_panel(overlay)
	_build_picker_panel(overlay)


func _build_rotation_hint(overlay: Control) -> void:
	var hint := _new_label("按住角色左右拖动：旋转检视", 13, Color("#d8c69d"))
	hint.name = "RotationDragHint"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-130.0, 108.0)
	hint.size = Vector2(260.0, 24.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(hint)


func _build_unit_panel(overlay: Control) -> void:
	var panel := _new_panel("UnitPanel")
	panel.position = Vector2(16.0, 16.0)
	panel.size = Vector2(350.0, 150.0)
	overlay.add_child(panel)
	var content := _panel_content(panel, 12)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := _new_label("NPC / 敌军检视", 21, Color("#f0cb7a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var back := Button.new()
	back.text = "返回 Main（F8）"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_return_to_main)
	title_row.add_child(back)
	_unit_select = OptionButton.new()
	_unit_select.name = "UnitSelect"
	_unit_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for unit in _units:
		var unit_dict := unit as Dictionary
		_unit_select.add_item("%s｜%s" % [str(unit_dict.get("side_label", "")), str(unit_dict.get("display_name", ""))])
		_unit_select.set_item_metadata(_unit_select.item_count - 1, str(unit_dict.get("id", "")))
	_unit_select.item_selected.connect(_on_unit_selected)
	content.add_child(_unit_select)
	_unit_name_label = _new_label("未选择", 18, Color.WHITE)
	content.add_child(_unit_name_label)
	_unit_detail_label = _new_label("", 13, Color("#b9c2bd"))
	_unit_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_unit_detail_label)


func _build_mode_panel(overlay: Control) -> void:
	var panel := _new_panel("ModePanel")
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-215.0, 16.0)
	panel.size = Vector2(430.0, 84.0)
	overlay.add_child(panel)
	var content := _panel_content(panel, 8)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	var group := ButtonGroup.new()
	_work_mode_button = Button.new()
	_work_mode_button.name = "WorkModeButton"
	_work_mode_button.text = "工作模式"
	_work_mode_button.toggle_mode = true
	_work_mode_button.button_group = group
	_work_mode_button.custom_minimum_size = Vector2(155.0, 34.0)
	_work_mode_button.pressed.connect(_set_mode.bind("work"))
	row.add_child(_work_mode_button)
	_combat_mode_button = Button.new()
	_combat_mode_button.name = "CombatModeButton"
	_combat_mode_button.text = "战斗模式"
	_combat_mode_button.toggle_mode = true
	_combat_mode_button.button_group = group
	_combat_mode_button.custom_minimum_size = Vector2(155.0, 34.0)
	_combat_mode_button.pressed.connect(_set_mode.bind("combat"))
	row.add_child(_combat_mode_button)
	_mode_note_label = _new_label("", 12, Color("#c9b58d"))
	_mode_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_mode_note_label)


func _build_action_panel(overlay: Control) -> void:
	var panel := _new_panel("ActionPanel")
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-342.0, 16.0)
	panel.size = Vector2(326.0, 688.0)
	overlay.add_child(panel)
	var content := _panel_content(panel, 10)
	content.add_child(_new_label("动作检视", 21, Color("#f0cb7a")))
	var note := _new_label("角色永远不会执行的动作不列出；当前模式不兼容的动作会保留但禁用。", 12, Color("#aeb9b3"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.name = "ActionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_action_grid = GridContainer.new()
	_action_grid.name = "ActionGrid"
	_action_grid.columns = 2
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.add_theme_constant_override("h_separation", 8)
	_action_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_action_grid)


func _build_equipment_panel(overlay: Control) -> void:
	var panel := _new_panel("EquipmentPanel")
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(8.0, -348.0)
	panel.size = Vector2(316.0, 332.0)
	overlay.add_child(panel)
	var content := _panel_content(panel, 8)
	var mannequin := Control.new()
	mannequin.name = "EquipmentMannequin"
	mannequin.custom_minimum_size = Vector2(300.0, 300.0)
	content.add_child(mannequin)
	var silhouette_script := load("res://scripts/ui/EquipmentSilhouette.gd")
	var silhouette := silhouette_script.new() as Control
	silhouette.name = "TwoHeadSilhouette"
	silhouette.position = Vector2(10.0, 6.0)
	silhouette.size = Vector2(280.0, 250.0)
	mannequin.add_child(silhouette)
	for slot in SLOT_ORDER:
		var button := Button.new()
		button.name = "%sSlotButton" % str(slot).to_pascal_case()
		button.position = SLOT_POSITIONS[slot]
		button.size = Vector2(70.0, 58.0)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_constant_override("icon_max_width", 52)
		button.pressed.connect(_on_equipment_slot_pressed.bind(slot))
		mannequin.add_child(button)
		_equipment_buttons[slot] = button


func _build_status_panel(overlay: Control) -> void:
	var panel := _new_panel("StatusPanel")
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-245.0, -104.0)
	panel.size = Vector2(490.0, 88.0)
	overlay.add_child(panel)
	var content := _panel_content(panel, 8)
	_status_label = _new_label("正在初始化角色检视场景…", 14, Color("#e6e9df"))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)


func _build_picker_panel(overlay: Control) -> void:
	_picker_panel = _new_panel("EquipmentPicker")
	_picker_panel.visible = false
	_picker_panel.position = Vector2(404.0, 338.0)
	_picker_panel.size = Vector2(245.0, 330.0)
	overlay.add_child(_picker_panel)
	var content := _panel_content(_picker_panel, 8)
	var header := HBoxContainer.new()
	content.add_child(header)
	_picker_title = _new_label("选择装备", 18, Color("#f0cb7a"))
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_picker_title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: _picker_panel.visible = false)
	header.add_child(close)
	var note := _new_label("正式模型截图图标｜点击装配", 12, Color("#aeb9b3"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_picker_items = VBoxContainer.new()
	_picker_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_items.add_theme_constant_override("separation", 6)
	scroll.add_child(_picker_items)


func _on_unit_selected(index: int) -> void:
	_select_unit(str(_unit_select.get_item_metadata(index)))


func _select_unit(unit_id: String) -> void:
	if not _units_by_id.has(unit_id):
		return
	_selected_unit_id = unit_id
	var unit: Dictionary = _units_by_id[unit_id]
	if _picker_panel != null:
		_picker_panel.visible = false
	if str(unit.get("side", "")) == "enemy":
		_mode = "combat"
	_selected_action_id = "idle"
	if _mode == "combat" and _unit_has_preview_mount(unit) and (unit.get("action_ids", []) as Array).has("mounted_pose"):
		_selected_action_id = "mounted_pose"
	for index in _unit_select.item_count:
		if str(_unit_select.get_item_metadata(index)) == unit_id:
			_unit_select.select(index)
			break
	_spawn_character(unit)
	_refresh_all()


func _spawn_character(unit: Dictionary) -> void:
	if is_instance_valid(_character):
		_character.free()
	_character = null
	var scene_path := str(unit.get("scene", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_status_label.text = "角色场景加载失败：%s" % scene_path
		return
	var rider_or_character := packed.instantiate() as Node3D
	if rider_or_character == null:
		return
	if _is_enemy_mounted_unit(unit):
		var fixed_weapon_id := str(((unit.get("default_loadout", {}) as Dictionary).get("main_weapon", {}) as Dictionary).get("id", ""))
		rider_or_character.set("equipment_mode", "sword_shield" if fixed_weapon_id == "sword_shield" else "none")
		var mounted_art := ENEMY_MOUNTED_ART_SCRIPT.new() as Node3D
		mounted_art.name = "PreviewCharacter"
		_character_mount.add_child(mounted_art)
		mounted_art.setup(rider_or_character, str(unit.get("id", "enemy_preview")), str(unit.get("role", "cavalry")))
		if rider_or_character.has_method("debug_set_equipment_preview"):
			rider_or_character.call("debug_set_equipment_preview", fixed_weapon_id, true)
		mounted_art.escape_completed.connect(_on_enemy_mounted_escape_completed)
		_character = mounted_art
		_apply_enemy_mounted_profile(100, false, "idle")
	else:
		_character = rider_or_character
		_character.name = "PreviewCharacter"
		_character_mount.add_child(_character)
	_character.position = Vector3.ZERO
	if _character.has_method("set_facing_direction"):
		_character.call("set_facing_direction", Vector3.BACK)


func _set_mode(mode: String) -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if unit.is_empty():
		return
	if str(unit.get("side", "")) == "enemy" and mode != "combat":
		_status_label.text = "敌方单位固定为战斗模式。"
		return
	if not mode in ["work", "combat"]:
		return
	_mode = mode
	if _mode == "combat" and _unit_has_preview_mount(unit):
		_selected_action_id = "mounted_pose"
	if not _action_matches_mode(_selected_action_id, _mode):
		_selected_action_id = "idle"
	_refresh_all()


func _trigger_action(action_id: String) -> void:
	if not _can_trigger_action(action_id):
		return
	var action: Dictionary = _actions_by_id[action_id]
	var modes: Array = action.get("modes", [])
	if not modes.has(_mode):
		var target_mode := _preferred_action_mode(modes)
		if target_mode.is_empty():
			return
		_mode = target_mode
	_selected_action_id = action_id
	_refresh_all()


func _apply_action() -> void:
	if not _actions_by_id.has(_selected_action_id):
		return
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if _is_enemy_mounted_unit(unit):
		_apply_enemy_mounted_action(unit)
		return
	if _character == null:
		return
	if _selected_action_id != FRIENDLY_MOUNTED_UNCONSCIOUS_ACTION_ID and _friendly_mounted_fall_is_active():
		_spawn_character(unit)
	if _selected_action_id == FRIENDLY_MOUNTED_UNCONSCIOUS_ACTION_ID:
		_apply_friendly_mounted_unconscious()
		return
	var action: Dictionary = _actions_by_id[_selected_action_id]
	var state := str(action.get("animation_state", "idle"))
	var mounted := _mode == "combat" and not (_current_loadout().get("mount", {}) as Dictionary).is_empty()
	if mounted and MOUNTED_ACTION_STATES.has(_selected_action_id):
		state = str(MOUNTED_ACTION_STATES[_selected_action_id])
	var result: Dictionary = _character.call("debug_force_action_preview", _selected_action_id, state) if _character.has_method("debug_force_action_preview") else (_character.call("debug_force_animation_state", state) if _character.has_method("debug_force_animation_state") else {})
	if not result.is_empty() and not bool(result.get("ready", result.get("ok", true))):
		_status_label.text = "动作预览失败：%s" % str(result.get("error", state))


func _apply_friendly_mounted_unconscious() -> void:
	if not is_instance_valid(_character) or not _character.has_method("apply_profile"):
		return
	var weapon: Dictionary = (_current_loadout().get("main_weapon", {}) as Dictionary).duplicate(true)
	var base_profile := {
		"id": _selected_unit_id,
		"equipment": {"main_weapon": weapon},
		"states": {
			"hp": 100,
			"max_hp": 100,
			"current_action": "idle",
			"behavior_mode": "combat",
			"unconscious": false,
			"escaped": false,
			"combat_mounted": true,
		}
	}
	_character.apply_profile(base_profile)
	var unconscious_profile: Dictionary = base_profile.duplicate(true)
	var unconscious_states: Dictionary = (unconscious_profile.get("states", {}) as Dictionary).duplicate(true)
	unconscious_states["hp"] = 0
	unconscious_states["current_action"] = "unconscious"
	unconscious_states["unconscious"] = true
	unconscious_states["combat_mounted"] = false
	unconscious_profile["states"] = unconscious_states
	_character.apply_profile(unconscious_profile)


func _friendly_mounted_fall_is_active() -> bool:
	if not is_instance_valid(_character) or not _character.has_method("debug_get_snapshot"):
		return false
	var snapshot: Dictionary = _character.debug_get_snapshot()
	return bool(snapshot.get("mounted_fall_active", false)) or bool(snapshot.get("mounted_fall_recovering", false))


func _apply_enemy_mounted_action(unit: Dictionary) -> void:
	if not _ensure_enemy_mounted_preview(unit):
		return
	if _selected_action_id == ENEMY_MOUNTED_DEFEAT_ACTION_ID:
		_character.set_movement_active(false, 0.0)
		_apply_enemy_mounted_profile(0, true, "unconscious")
		var escape_direction := (_character_mount.global_basis * Vector3.RIGHT).normalized()
		var escape_target := _character.global_position + escape_direction * ENEMY_MOUNTED_ESCAPE_DISTANCE
		_character.begin_mounted_defeat_escape(escape_target)
		return
	_character.set_movement_active(false, 0.0)
	match _selected_action_id:
		"walk":
			_apply_enemy_mounted_profile(100, false, "idle")
			_character.set_movement_active(true, 3.2)
		"run":
			_apply_enemy_mounted_profile(100, false, "idle")
			_character.set_movement_active(true, 7.0)
		"attack":
			_apply_enemy_mounted_profile(100, false, "attacking_dev_lab_target")
		"hit_react":
			_apply_enemy_mounted_profile(100, false, "idle")
			_apply_enemy_mounted_profile(90, false, "idle")
		_:
			_apply_enemy_mounted_profile(100, false, "idle")


func _ensure_enemy_mounted_preview(unit: Dictionary) -> bool:
	if is_instance_valid(_character) and _character.has_method("debug_get_snapshot"):
		var snapshot: Dictionary = _character.debug_get_snapshot()
		if str(snapshot.get("escape_phase", "mounted")) == "mounted":
			return true
	_spawn_character(unit)
	return is_instance_valid(_character)


func _apply_enemy_mounted_profile(hp: int, unconscious: bool, current_action: String) -> void:
	if not is_instance_valid(_character) or not _character.has_method("apply_profile"):
		return
	_character.apply_profile({
		"id": _selected_unit_id,
		"states": {
			"hp": hp,
			"max_hp": 100,
			"current_action": current_action,
			"behavior_mode": "combat",
			"unconscious": unconscious,
			"escaped": false,
			"combat_mounted": not unconscious and hp > 0,
		}
	})


func _on_enemy_mounted_escape_completed(snapshot: Dictionary) -> void:
	_last_enemy_mounted_escape_snapshot = snapshot.duplicate(true)
	if str(snapshot.get("enemy_id", "")) == _selected_unit_id:
		_character = null
		_status_label.text = "%s｜骑手坠亡完成｜马匹已逃出检视范围并释放\n再次点击任一动作即可重新生成正式骑兵包装。" % str((_units_by_id.get(_selected_unit_id, {}) as Dictionary).get("display_name", "敌方骑兵"))


func _on_equipment_slot_pressed(slot: String) -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if _is_enemy_unit(unit):
		_status_label.text = "%s｜敌军装备由兵种固定，切换敌人即可查看其他配置。" % str(unit.get("display_name", "敌方单位"))
		return
	var loadout := _current_loadout()
	var item: Dictionary = loadout.get(slot, {})
	if not item.is_empty():
		_unequip_slot(slot)
		return
	_open_equipment_picker(slot)


func _open_equipment_picker(slot: String) -> void:
	for child in _picker_items.get_children():
		child.queue_free()
	_picker_title.text = "选择%s" % str(SLOT_LABELS.get(slot, slot))
	var options: Array = _equipment_options.get(slot, [])
	if options.is_empty():
		var empty := _new_label("该部位暂无正式配置。", 13, Color("#c6aaa0"))
		_picker_items.add_child(empty)
	else:
		for raw_item in options:
			var item := raw_item as Dictionary
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_picker_items.add_child(row)
			var icon_button := Button.new()
			icon_button.name = "%sIconButton" % str(item.get("id", "item")).to_pascal_case()
			icon_button.custom_minimum_size = Vector2(62.0, 62.0)
			icon_button.icon = _load_item_icon(item)
			icon_button.expand_icon = true
			icon_button.add_theme_constant_override("icon_max_width", 56)
			icon_button.focus_mode = Control.FOCUS_NONE
			icon_button.tooltip_text = str(item.get("name", item.get("id", "未命名装备")))
			icon_button.pressed.connect(_equip_slot.bind(slot, item.duplicate(true)))
			row.add_child(icon_button)
			var name_button := Button.new()
			name_button.text = str(item.get("name", item.get("id", "未命名装备")))
			name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_button.focus_mode = Control.FOCUS_NONE
			name_button.tooltip_text = _item_model_note(slot, item)
			name_button.pressed.connect(_equip_slot.bind(slot, item.duplicate(true)))
			row.add_child(name_button)
	_picker_panel.visible = true


func _equip_slot(slot: String, item: Dictionary) -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if _is_enemy_unit(unit):
		if _picker_panel != null:
			_picker_panel.visible = false
		_status_label.text = "%s｜敌军装备由兵种固定，不能换装。" % str(unit.get("display_name", "敌方单位"))
		return
	var loadout := _current_loadout()
	loadout[slot] = item.duplicate(true)
	_shared_loadout = loadout
	_mode = "combat"
	if slot == "mount":
		_selected_action_id = "mounted_pose"
	if not _action_matches_mode(_selected_action_id, _mode):
		_selected_action_id = "idle"
	_picker_panel.visible = false
	_refresh_all()


func _unequip_slot(slot: String) -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if _is_enemy_unit(unit):
		_status_label.text = "%s｜敌军装备由兵种固定，不能卸装。" % str(unit.get("display_name", "敌方单位"))
		return
	var loadout := _current_loadout()
	loadout[slot] = {}
	_shared_loadout = loadout
	if slot == "mount" and _selected_action_id in ["mounted_pose", FRIENDLY_MOUNTED_UNCONSCIOUS_ACTION_ID]:
		_selected_action_id = "idle"
	_refresh_all()


func _refresh_all() -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if unit.is_empty():
		return
	_unit_name_label.text = "%s · %s" % [str(unit.get("display_name", "")), str(unit.get("role_label", ""))]
	_unit_detail_label.text = "%s｜%s\n%s" % [
		str(unit.get("side_label", "")),
		str(unit.get("model_status", "")),
		str((_lab_config.get("enemy_preview", {}) as Dictionary).get("note", "")) if str(unit.get("side", "")) == "enemy" else "角色来自 character_appearances.json 的正式生产映射。",
	]
	_work_mode_button.disabled = str(unit.get("side", "")) == "enemy"
	_work_mode_button.tooltip_text = "敌方单位没有工作模式。" if _work_mode_button.disabled else "隐藏战斗装备，检查日常与职业动作。"
	_work_mode_button.button_pressed = _mode == "work"
	_combat_mode_button.button_pressed = _mode == "combat"
	_mode_note_label.text = "敌方单位固定战斗模式与兵种装备；只能切换敌人查看" if _work_mode_button.disabled else "模式跨角色共享，装配跨我方 NPC 共享；装配或点击工作 / 战斗动作会自动切换模式"
	_refresh_action_buttons()
	_refresh_equipment_buttons()
	_refresh_character_equipment()
	_refresh_mount_visual()
	_apply_action()
	_refresh_status()


func _refresh_action_buttons() -> void:
	for child in _action_grid.get_children():
		child.queue_free()
	_action_buttons.clear()
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	var allowed_ids: Array = unit.get("action_ids", [])
	for action_id in _action_order:
		if not allowed_ids.has(action_id):
			continue
		var action: Dictionary = _actions_by_id[action_id]
		var button := Button.new()
		button.name = "%sActionButton" % action_id.to_pascal_case()
		button.text = str(action.get("label", action_id))
		button.custom_minimum_size = Vector2(137.0, 38.0)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not _can_trigger_action(action_id)
		button.button_pressed = action_id == _selected_action_id
		button.tooltip_text = _action_tooltip(action)
		button.pressed.connect(_trigger_action.bind(action_id))
		_action_grid.add_child(button)
		_action_buttons[action_id] = button


func _refresh_equipment_buttons() -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	var loadout := _current_loadout()
	var enemy_locked := _is_enemy_unit(unit)
	for slot in SLOT_ORDER:
		var button := _equipment_buttons.get(slot) as Button
		var item: Dictionary = loadout.get(slot, {})
		var label := str(SLOT_LABELS.get(slot, slot))
		button.disabled = enemy_locked
		if enemy_locked:
			button.tooltip_text = "%s｜%s：%s\n敌军兵种固定，不能换装或卸装。" % [
				str(unit.get("display_name", "敌方单位")),
				label,
				"空" if item.is_empty() else str(item.get("name", item.get("id", "敌军固有"))),
			]
		else:
			button.tooltip_text = "点击选择%s" % label if item.is_empty() else "%s：%s\n再次点击立即卸下。\n%s" % [label, str(item.get("name", "")), _item_model_note(slot, item)]
		button.text = "+" if item.is_empty() else ""
		button.icon = null if item.is_empty() else _load_item_icon(item, slot)
		button.expand_icon = not item.is_empty()


func _refresh_character_equipment() -> void:
	if _character == null:
		return
	var loadout := _current_loadout()
	var weapon: Dictionary = loadout.get("main_weapon", {})
	var weapon_id := str(weapon.get("id", ""))
	if _character.has_method("debug_set_equipment_preview"):
		_character.call("debug_set_equipment_preview", weapon_id, _mode == "combat")
	if _character.has_method("debug_set_armor_preview"):
		var armor_ids := {}
		for slot in ["helmet", "chest", "bracers", "greaves"]:
			var armor_item: Dictionary = loadout.get(slot, {}) if loadout.get(slot, {}) is Dictionary else {}
			armor_ids[slot] = str(armor_item.get("id", ""))
		_character.call("debug_set_armor_preview", armor_ids, _mode == "combat")


func _refresh_mount_visual() -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if _is_enemy_mounted_unit(unit):
		if is_instance_valid(_horse_model):
			_horse_model.visible = false
		_seat_preview.visible = false
		_position_character_mount(false, false)
		return
	var mount_item: Dictionary = _current_loadout().get("mount", {})
	var should_show := _mode == "combat" and not mount_item.is_empty()
	if should_show and not is_instance_valid(_horse_model):
		var packed := load(HORSE_SCENE_PATH) as PackedScene
		if packed != null:
			_horse_model = packed.instantiate() as Node3D
			_horse_model.name = "PreviewHorse"
			_horse_mount.position = MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_ROOT_POSITION
			_horse_model.scale = MOUNTED_PRESENTATION_REFERENCE.FRIENDLY_HORSE_SCALE
			_horse_model.rotation_degrees.y = 0.0
			_horse_mount.add_child(_horse_model)
	if is_instance_valid(_horse_model):
		_horse_model.visible = should_show
	_sync_horse_animation(should_show)
	var show_seat_preview := (
		not should_show
		and _mode == "work"
		and NON_MOUNTED_SEATED_ACTION_IDS.has(_selected_action_id)
	)
	_seat_preview.visible = show_seat_preview
	_position_character_mount(should_show, show_seat_preview)


func _sync_horse_animation(mounted: bool) -> void:
	if not is_instance_valid(_horse_model):
		return
	var animation_player := _horse_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	if not mounted:
		animation_player.stop()
		return
	var horse_clip := str(MOUNTED_HORSE_ACTION_CLIPS.get(_selected_action_id, "Idle"))
	if not animation_player.has_animation(horse_clip):
		horse_clip = "Idle"
	if animation_player.current_animation != horse_clip or not animation_player.is_playing():
		animation_player.play(horse_clip, 0.18)


func _position_character_mount(mounted: bool, show_seat_preview: bool) -> void:
	var preview_rotation := Basis(Vector3.UP, deg_to_rad(_preview_yaw_degrees))
	if mounted:
		var horse_forward := (preview_rotation * HORSE_VISIBLE_FORWARD_LOCAL).normalized()
		_character_mount.position = MOUNTED_PRESENTATION_REFERENCE.get_friendly_rider_root_offset(horse_forward)
		return
	# The stabilized Synty wrapper visibly faces local +Z (Godot Vector3.BACK).
	var character_forward := (preview_rotation * Vector3.BACK).normalized()
	_seat_preview.position = -character_forward * SEAT_PREVIEW_BACKWARD_OFFSET if show_seat_preview else Vector3.ZERO
	var seated_forward_offset := SEATED_EATING_FORWARD_OFFSET if show_seat_preview and _selected_action_id in ["work_clinic_doctor", "seated_prayer", "seated_study", "seated_eating"] else 0.0
	_character_mount.position = Vector3(
		character_forward.x * seated_forward_offset,
		CHARACTER_MOUNT_BASE_Y + (_seated_height_compensation() if show_seat_preview else 0.0),
		character_forward.z * seated_forward_offset
	)


func _seated_height_compensation() -> float:
	if _character == null:
		return 0.0
	for property_info in _character.get_property_list():
		if str(property_info.get("name", "")) == "seated_pose_offset_y":
			return maxf(0.0, -float(_character.get("seated_pose_offset_y")))
	return 0.0


func _refresh_status() -> void:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	var action: Dictionary = _actions_by_id.get(_selected_action_id, {})
	var weapon: Dictionary = _current_loadout().get("main_weapon", {})
	var weapon_id := str(weapon.get("id", ""))
	var visual_note := "工作模式隐藏战斗装备与坐骑；临时装配仍保留。"
	if _is_enemy_mounted_unit(unit):
		visual_note = "正式骑兵包装：敌方马匹无独立 HP，坠亡与逃马直接复用 Main。"
	elif _is_enemy_unit(unit):
		visual_note = "敌军兵种固定装备：%s；无坐骑。切换敌人查看其他配置。" % str(weapon.get("name", "未配置主武器"))
	elif _selected_action_id == FRIENDLY_MOUNTED_UNCONSCIOUS_ACTION_ID:
		visual_note = "正式友方状态边沿：骑乘 → 昏迷，复用 Main 的 mounted_fall / Death_A。"
	elif _mode == "combat":
		if weapon_id == "crossbow":
			visual_note = "弩模型与步战瞄准、射击、重装动作已接入；飞行弩矢仅负责表现。"
		else:
			visual_note = "%s 模型、持握姿势与攻击动作已接入。" % str(weapon.get("name", "主武器")) if FORMAL_WEAPON_MODEL_IDS.has(weapon_id) else ("%s 的 3D 模型待制作。" % str(weapon.get("name", "未装备主武器")) if not weapon_id.is_empty() else "当前未装备主武器。")
	_status_label.text = "%s｜%s｜动作：%s\n%s" % [
		str(unit.get("display_name", "")),
		"工作模式" if _mode == "work" else "战斗模式",
		str(action.get("label", "待机")),
		visual_note,
	]


func _can_trigger_action(action_id: String) -> bool:
	var action: Dictionary = _actions_by_id.get(action_id, {})
	if action.is_empty():
		return false
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if not (unit.get("action_ids", []) as Array).has(action_id):
		return false
	if bool(action.get("requires_mount", false)):
		return _unit_has_preview_mount(unit)
	if bool(action.get("requires_friendly_mount", false)):
		return str(unit.get("side", "")) == "friendly" and not (_current_loadout().get("mount", {}) as Dictionary).is_empty()
	if bool(action.get("requires_enemy_mount", false)):
		return _is_enemy_mounted_unit(unit)
	return true


func _action_tooltip(action: Dictionary) -> String:
	var modes: Array = action.get("modes", [])
	if not modes.has(_mode):
		return "点击后自动切换到%s并播放。" % _mode_label(_preferred_action_mode(modes))
	if bool(action.get("requires_mount", false)) and not _unit_has_preview_mount(_units_by_id.get(_selected_unit_id, {})):
		return "需要先在左下坐骑槽选择一匹马。"
	if bool(action.get("requires_friendly_mount", false)) and (_current_loadout().get("mount", {}) as Dictionary).is_empty():
		return "需要我方 NPC 先在左下坐骑槽选择一匹马。"
	return "立即播放：%s" % str(action.get("label", "动作"))


func _preferred_action_mode(modes: Array) -> String:
	if modes.has("combat") and not modes.has("work"):
		return "combat"
	if modes.has("work"):
		return "work"
	return "combat" if modes.has("combat") else ""


func _action_matches_mode(action_id: String, mode: String) -> bool:
	var action: Dictionary = _actions_by_id.get(action_id, {})
	return not action.is_empty() and (action.get("modes", []) as Array).has(mode)


func _mode_label(mode: String) -> String:
	return "工作模式" if mode == "work" else "战斗模式"


func _item_model_note(slot: String, item: Dictionary) -> String:
	if slot == "mount":
		return "已有马匹模型与骑乘动作；仅战斗模式显示。"
	if slot == "main_weapon" and FORMAL_WEAPON_MODEL_IDS.has(str(item.get("id", ""))):
		return "已有可检视的正式低模武器、持握姿势与攻击动作。"
	if slot in ["helmet", "chest", "bracers", "greaves"]:
		return "已有跟随对应骨骼的独立低模部件；仅战斗模式显示。"
	return "配置已存在；对应 3D 模型待制作。"


func _load_item_icon(item: Dictionary, slot_hint: String = "") -> Texture2D:
	var icon_path := str(item.get("icon", "")).strip_edges()
	if icon_path.is_empty() and not slot_hint.is_empty():
		var item_id := str(item.get("id", ""))
		var template_id := str(item.get("template_id", ""))
		for raw_option in _equipment_options.get(slot_hint, []):
			var option := raw_option as Dictionary
			if str(option.get("id", "")) != item_id:
				continue
			if not template_id.is_empty() and str(option.get("template_id", "")) != template_id:
				continue
			icon_path = str(option.get("icon", "")).strip_edges()
			if not icon_path.is_empty():
				break
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _is_enemy_mounted_unit(unit: Dictionary) -> bool:
	return _is_enemy_unit(unit) and str(unit.get("role", "")) in ENEMY_MOUNTED_UNIT_TYPES


func _is_enemy_unit(unit: Dictionary) -> bool:
	return str(unit.get("side", "")) == "enemy"


func _unit_has_preview_mount(unit: Dictionary) -> bool:
	if _is_enemy_unit(unit):
		return not ((unit.get("default_loadout", {}) as Dictionary).get("mount", {}) as Dictionary).is_empty()
	return not (_current_loadout().get("mount", {}) as Dictionary).is_empty()


func _current_loadout() -> Dictionary:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	if _is_enemy_unit(unit):
		return (unit.get("default_loadout", _empty_loadout()) as Dictionary).duplicate(true)
	if _shared_loadout.is_empty():
		_shared_loadout = _empty_loadout()
	return _shared_loadout.duplicate(true)


func _empty_loadout() -> Dictionary:
	var result := {}
	for slot in SLOT_ORDER:
		result[slot] = {}
	return result


func _normalize_loadout(raw_equipment: Variant) -> Dictionary:
	var result := _empty_loadout()
	if raw_equipment is Dictionary:
		for slot in SLOT_ORDER:
			var item: Variant = (raw_equipment as Dictionary).get(slot, {})
			if item is Dictionary:
				result[slot] = (item as Dictionary).duplicate(true)
	return result


func _find_equipment_item(path: String, item_id: String) -> Dictionary:
	for raw_item in _read_json_array(path):
		if raw_item is Dictionary and str((raw_item as Dictionary).get("id", "")) == item_id:
			return (raw_item as Dictionary).duplicate(true)
	return {"id": item_id, "name": item_id, "slot": "main_weapon"}


func _merge_unique(first: Array, second: Variant) -> Array:
	var result: Array = []
	for raw_value in first:
		if not result.has(str(raw_value)):
			result.append(str(raw_value))
	if second is Array:
		for raw_value in second:
			if not result.has(str(raw_value)):
				result.append(str(raw_value))
	return result


func _unit_type_label(unit_type: String) -> String:
	match unit_type:
		"melee_infantry": return "近战步兵"
		"polearm_infantry": return "长杆步兵"
		"archer": return "弓箭兵"
		"crossbowman": return "弩兵"
		"cavalry": return "近战骑兵"
		"mounted_ranged": return "骑射单位"
		_: return unit_type


func _new_panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _panel_style())
	return panel


func _panel_content(panel: PanelContainer, margin_size: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	return content


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.047, 0.95)
	style.border_color = Color(0.55, 0.42, 0.24, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _new_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _read_json_dictionary(path: String) -> Dictionary:
	var value: Variant = _read_json(path)
	return value if value is Dictionary else {}


func _read_json_array(path: String) -> Array:
	var value: Variant = _read_json(path)
	return value if value is Array else []


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


func _return_to_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func debug_select_unit(unit_id: String) -> Dictionary:
	_select_unit(unit_id)
	return debug_get_snapshot()


func debug_set_mode(mode: String) -> Dictionary:
	_set_mode(mode)
	return debug_get_snapshot()


func debug_trigger_action(action_id: String) -> Dictionary:
	_trigger_action(action_id)
	return debug_get_snapshot()


func debug_equip(slot: String, item_id: String) -> Dictionary:
	for raw_item in _equipment_options.get(slot, []):
		var item := raw_item as Dictionary
		if str(item.get("id", "")) == item_id or str(item.get("horse_id", "")) == item_id:
			_equip_slot(slot, item)
			break
	return debug_get_snapshot()


func debug_unequip(slot: String) -> Dictionary:
	_unequip_slot(slot)
	return debug_get_snapshot()


func debug_get_snapshot() -> Dictionary:
	var unit: Dictionary = _units_by_id.get(_selected_unit_id, {})
	var usable_actions: Array = []
	var disabled_actions: Array = []
	for action_id in unit.get("action_ids", []):
		if _can_trigger_action(str(action_id)):
			usable_actions.append(str(action_id))
		else:
			disabled_actions.append(str(action_id))
	var character_snapshot := {}
	if _character != null and _character.has_method("debug_get_snapshot"):
		character_snapshot = _character.call("debug_get_snapshot")
	var character_visible_forward := Vector3(character_snapshot.get("visual_forward", Vector3.ZERO)).normalized()
	var horse_visible_forward := Vector3.ZERO
	var formal_enemy_mount := bool(character_snapshot.get("mounted_enemy_wrapper", false))
	if formal_enemy_mount:
		horse_visible_forward = Vector3(character_snapshot.get("horse_visible_forward", Vector3.ZERO)).normalized()
	elif is_instance_valid(_horse_model):
		horse_visible_forward = (_horse_model.global_basis * HORSE_VISIBLE_FORWARD_LOCAL).normalized()
	var mounted_forward_dot := 0.0
	if not character_visible_forward.is_zero_approx() and not horse_visible_forward.is_zero_approx():
		mounted_forward_dot = character_visible_forward.dot(horse_visible_forward)
	var seat_top := _seat_preview.get_node_or_null("SeatTop") as Node3D
	var horse_animation := str(character_snapshot.get("horse_animation", "")) if formal_enemy_mount else ""
	if not formal_enemy_mount and is_instance_valid(_horse_model):
		var horse_player := _horse_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if horse_player != null:
			horse_animation = horse_player.current_animation
	var seat_top_world_position := seat_top.global_position if seat_top != null else Vector3.ZERO
	var hips_world_position := Vector3(character_snapshot.get("hips_global_position", Vector3.ZERO))
	var seat_hips_horizontal_distance := Vector2(seat_top_world_position.x, seat_top_world_position.z).distance_to(Vector2(hips_world_position.x, hips_world_position.z))
	return {
		"ready": not _units.is_empty() and _character != null,
		"unit_count": _units.size(),
		"friendly_count": _units.filter(func(value: Variant) -> bool: return str((value as Dictionary).get("side", "")) == "friendly").size(),
		"enemy_count": _units.filter(func(value: Variant) -> bool: return str((value as Dictionary).get("side", "")) == "enemy").size(),
		"unit_ids": _units.map(func(value: Variant) -> String: return str((value as Dictionary).get("id", ""))),
		"selected_unit_id": _selected_unit_id,
		"selected_side": str(unit.get("side", "")),
		"mode": _mode,
		"mode_scope": "shared_across_units",
		"selected_action_id": _selected_action_id,
		"usable_actions": usable_actions,
		"disabled_actions": disabled_actions,
		"loadout": _current_loadout(),
		"loadout_scope": "fixed_by_enemy_type" if _is_enemy_unit(unit) else "shared_across_friendlies",
		"enemy_equipment_locked": _is_enemy_unit(unit),
		"mount_visible": bool(character_snapshot.get("horse_visible", false)) if formal_enemy_mount else (is_instance_valid(_horse_model) and _horse_model.visible),
		"uses_formal_enemy_mount": formal_enemy_mount,
		"enemy_mount_has_independent_hp": bool(character_snapshot.get("horse_has_independent_hp", false)) if formal_enemy_mount else null,
		"enemy_mount_damage_routing": str(character_snapshot.get("damage_routing", "")) if formal_enemy_mount else "",
		"enemy_mount_escape_phase": str(character_snapshot.get("escape_phase", "")) if formal_enemy_mount else "",
		"last_enemy_mounted_escape": _last_enemy_mounted_escape_snapshot.duplicate(true),
		"horse_animation": horse_animation,
		"horse_root_position": Vector3(character_snapshot.get("horse_local_position", Vector3.ZERO)) if formal_enemy_mount else _horse_mount.position,
		"horse_model_scale": Vector3(character_snapshot.get("horse_scale", Vector3.ZERO)) if formal_enemy_mount else (_horse_model.scale if is_instance_valid(_horse_model) else Vector3.ZERO),
		"mounted_presentation_reference": "shared_production_reference",
		"character_mount_position": _character_mount.position,
		"character_mount_y": _character_mount.position.y,
		"seated_height_compensation": _seated_height_compensation(),
		"seat_preview_visible": _seat_preview.visible,
		"seat_preview_position": _seat_preview.position,
		"seat_preview_yaw_degrees": _seat_preview.rotation_degrees.y,
		"seat_surface_world_y": seat_top_world_position.y + 0.06,
		"seat_top_world_position": seat_top_world_position,
		"seat_hips_horizontal_distance": seat_hips_horizontal_distance,
		"preview_yaw_degrees": _preview_yaw_degrees,
		"rotation_drag_active": _rotation_drag_active,
		"horse_yaw_degrees": _horse_mount.rotation_degrees.y,
		"horse_model_local_yaw_degrees": _horse_model.rotation_degrees.y if not formal_enemy_mount and is_instance_valid(_horse_model) else 0.0,
		"character_visible_forward": character_visible_forward,
		"horse_visible_forward": horse_visible_forward,
		"mounted_forward_dot": mounted_forward_dot,
		"picker_visible": _picker_panel != null and _picker_panel.visible,
		"character": character_snapshot,
		"authority_role": "developer_preview_only",
	}


func debug_begin_rotation_drag() -> Dictionary:
	_rotation_drag_active = true
	return debug_get_snapshot()


func debug_drag_rotation(horizontal_pixels: float) -> Dictionary:
	if _rotation_drag_active:
		_rotate_preview_by_pixels(horizontal_pixels)
	return debug_get_snapshot()


func debug_end_rotation_drag() -> Dictionary:
	_end_rotation_drag()
	return debug_get_snapshot()


func debug_advance_enemy_mounted_escape(seconds: float) -> Dictionary:
	if is_instance_valid(_character) and _character.has_method("debug_advance_escape"):
		_character.debug_advance_escape(seconds)
	return debug_get_snapshot()
