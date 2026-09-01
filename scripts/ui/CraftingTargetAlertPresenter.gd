extends Control

const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const FORMAL_BUILDING_ROOT_PATH := "/root/Main/WorldRoot/FormalStationLayout/BuildingRoots"
const BUILDING_ROOT_PATH := "/root/Main/WorldRoot/Station/Buildings"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const CRAFTING_SYSTEM_PATH := "/root/Main/Systems/CraftingSystem"
const HARVEST_DIALOG_PATH := "/root/Main/UI/CraftingHarvestDialog"
const SUPPORTED_BUILDING_IDS := ["blacksmith", "workshop"]
const BUILDING_NAMES := {"blacksmith": "铁匠铺", "workshop": "工械坊"}
const ALERT_TOOLTIP := "未选择制造物品"
const ALERT_SIZE := Vector2(32.0, 32.0)
const ALERT_SCALE := Vector2(0.75, 0.75)
const ALERT_DISPLAY_SIZE := ALERT_SIZE * ALERT_SCALE
const ALERT_OFFSET := Vector2(0.0, -30.0)
const HARVEST_ICON_PATH := "res://assets/ui/status_icons/harvest_hand.svg"
const HARVEST_SIZE := Vector2(44.0, 44.0)
const HARVEST_OFFSET := Vector2(0.0, -80.0)
const SCREEN_MARGIN := 0.0
const MINIMUM_ALERT_VIEWPORT_SIZE := Vector2(320.0, 180.0)

var _alerts: Dictionary = {}
var _building_labels: Dictionary = {}
var _needs_alert: Dictionary = {}
var _harvest_buttons: Dictionary = {}
var _harvest_badges: Dictionary = {}
var _pending_totals: Dictionary = {}
var _debug_viewport_size_override := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for raw_building_id in SUPPORTED_BUILDING_IDS:
		var building_id := str(raw_building_id)
		_create_alert(building_id)
		_create_harvest_button(building_id)
		_needs_alert[building_id] = false
		_pending_totals[building_id] = 0

	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system != null:
		if crafting_system.has_signal("project_changed"):
			crafting_system.project_changed.connect(_on_project_changed)
		if crafting_system.has_signal("recipe_catalog_loaded"):
			crafting_system.recipe_catalog_loaded.connect(_on_recipe_catalog_loaded)
		if crafting_system.has_signal("pending_outputs_changed"):
			crafting_system.pending_outputs_changed.connect(_on_pending_outputs_changed)
	call_deferred("_refresh_all_alerts")


func _process(_delta: float) -> void:
	_position_alerts()


func _create_alert(building_id: String) -> void:
	var alert := Button.new()
	alert.name = "%sCraftingTargetAlert" % building_id.to_pascal_case()
	alert.text = "!"
	alert.tooltip_text = ALERT_TOOLTIP
	alert.custom_minimum_size = ALERT_SIZE
	alert.size = ALERT_SIZE
	alert.scale = ALERT_SCALE
	alert.focus_mode = Control.FOCUS_NONE
	alert.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alert.add_theme_font_size_override("font_size", 24)
	alert.add_theme_color_override("font_color", Color(0.95, 0.12, 0.09, 1.0))
	alert.add_theme_color_override("font_hover_color", Color(1.0, 0.34, 0.27, 1.0))
	alert.add_theme_color_override("font_pressed_color", Color(0.82, 0.05, 0.03, 1.0))
	alert.add_theme_color_override("font_outline_color", Color(0.18, 0.01, 0.0, 0.95))
	alert.add_theme_constant_override("outline_size", 4)
	alert.add_theme_stylebox_override("normal", _make_alert_style(Color(0.08, 0.02, 0.01, 0.58)))
	alert.add_theme_stylebox_override("hover", _make_alert_style(Color(0.18, 0.03, 0.02, 0.86)))
	alert.add_theme_stylebox_override("pressed", _make_alert_style(Color(0.30, 0.04, 0.02, 0.92)))
	alert.pressed.connect(_on_alert_pressed.bind(building_id))
	alert.visible = false
	add_child(alert)
	_alerts[building_id] = alert


func _make_alert_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 0.0
	style.content_margin_top = 0.0
	style.content_margin_right = 0.0
	style.content_margin_bottom = 0.0
	return style


func _create_harvest_button(building_id: String) -> void:
	var button := Button.new()
	button.name = "%sCraftingHarvestButton" % building_id.to_pascal_case()
	button.custom_minimum_size = HARVEST_SIZE
	button.size = HARVEST_SIZE
	button.pivot_offset = HARVEST_SIZE * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_constant_override("icon_max_width", 28)
	if ResourceLoader.exists(HARVEST_ICON_PATH):
		button.icon = load(HARVEST_ICON_PATH)
	button.add_theme_stylebox_override("normal", _make_harvest_style(Color(0.24, 0.17, 0.10, 0.96)))
	button.add_theme_stylebox_override("hover", _make_harvest_style(Color(0.38, 0.27, 0.14, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_harvest_style(Color(0.15, 0.10, 0.06, 1.0)))
	button.pressed.connect(_on_harvest_pressed.bind(building_id))
	button.visible = false
	add_child(button)
	_harvest_buttons[building_id] = button

	var badge := Label.new()
	badge.name = "CountBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -20.0
	badge.offset_top = -5.0
	badge.offset_right = 5.0
	badge.offset_bottom = 17.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", _make_harvest_badge_style())
	button.add_child(badge)
	_harvest_badges[building_id] = badge


func _make_harvest_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.73, 0.55, 0.31, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	return style


func _make_harvest_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.62, 0.14, 0.08, 1.0)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _on_recipe_catalog_loaded(_recipe_count: int) -> void:
	_refresh_all_alerts()


func _on_project_changed(building_id: String, _project_snapshot: Dictionary) -> void:
	if SUPPORTED_BUILDING_IDS.has(building_id):
		_refresh_alert(building_id)
		_refresh_harvest_button(building_id)


func _on_pending_outputs_changed(building_id: String, _pending_snapshot: Dictionary) -> void:
	if SUPPORTED_BUILDING_IDS.has(building_id):
		_refresh_harvest_button(building_id)


func _refresh_all_alerts() -> void:
	for raw_building_id in SUPPORTED_BUILDING_IDS:
		var building_id := str(raw_building_id)
		_refresh_alert(building_id)
		_refresh_harvest_button(building_id)
	_position_alerts()


func _refresh_alert(building_id: String) -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var needs_alert := false
	if crafting_system != null and crafting_system.has_method("get_project_snapshot"):
		var project: Dictionary = crafting_system.get_project_snapshot(building_id)
		needs_alert = (
			str(project.get("target_recipe_id", project.get("recipe_id", ""))).is_empty()
			or str(project.get("target_item_id", "")).is_empty()
		)
	_needs_alert[building_id] = needs_alert


func _refresh_harvest_button(building_id: String) -> void:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	var next_total := 0
	if crafting_system != null and crafting_system.has_method("get_pending_output_total"):
		next_total = maxi(0, int(crafting_system.get_pending_output_total(building_id)))
	var previous_total := int(_pending_totals.get(building_id, 0))
	_pending_totals[building_id] = next_total
	var button := _harvest_buttons.get(building_id) as Button
	var badge := _harvest_badges.get(building_id) as Label
	if button != null:
		button.tooltip_text = "收取%s成品（%d）" % [str(BUILDING_NAMES.get(building_id, building_id)), next_total]
	if badge != null:
		badge.text = str(next_total)
	if button != null and next_total > previous_total:
		button.scale = Vector2(1.16, 1.16)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "scale", Vector2.ONE, 0.24)


func _position_alerts() -> void:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	var viewport_size := (
		_debug_viewport_size_override
		if _debug_viewport_size_override.x > 0.0 and _debug_viewport_size_override.y > 0.0
		else get_viewport_rect().size
	)
	var viewport_supported := (
		viewport_size.x >= MINIMUM_ALERT_VIEWPORT_SIZE.x
		and viewport_size.y >= MINIMUM_ALERT_VIEWPORT_SIZE.y
	)
	for raw_building_id in SUPPORTED_BUILDING_IDS:
		var building_id := str(raw_building_id)
		var alert := _alerts.get(building_id) as Button
		var harvest_button := _harvest_buttons.get(building_id) as Button
		if alert == null or harvest_button == null:
			continue
		var label := _get_building_label(building_id)
		if (
			not viewport_supported
			or camera == null
			or label == null
			or camera.is_position_behind(label.global_position)
		):
			alert.visible = false
			harvest_button.visible = false
			continue
		var label_screen_position := camera.unproject_position(label.global_position)
		var label_is_on_screen := Rect2(Vector2.ZERO, viewport_size).has_point(label_screen_position)
		var top_left := label_screen_position + ALERT_OFFSET - ALERT_DISPLAY_SIZE * 0.5
		var max_position := Vector2(
			maxf(SCREEN_MARGIN, viewport_size.x - ALERT_DISPLAY_SIZE.x - SCREEN_MARGIN),
			maxf(SCREEN_MARGIN, viewport_size.y - ALERT_DISPLAY_SIZE.y - SCREEN_MARGIN)
		)
		alert.position = top_left.clamp(Vector2(SCREEN_MARGIN, SCREEN_MARGIN), max_position)
		# Do not pin a crafting warning to a screen edge after its building has
		# moved off camera; that makes the warning appear to belong to another lot.
		alert.visible = bool(_needs_alert.get(building_id, false)) and label_is_on_screen
		var harvest_top_left := label_screen_position + HARVEST_OFFSET - HARVEST_SIZE * 0.5
		var harvest_max_position := Vector2(
			maxf(SCREEN_MARGIN, viewport_size.x - HARVEST_SIZE.x - SCREEN_MARGIN),
			maxf(SCREEN_MARGIN, viewport_size.y - HARVEST_SIZE.y - SCREEN_MARGIN)
		)
		harvest_button.position = harvest_top_left.clamp(Vector2(SCREEN_MARGIN, SCREEN_MARGIN), harvest_max_position)
		harvest_button.visible = int(_pending_totals.get(building_id, 0)) > 0 and label_is_on_screen


func _get_building_label(building_id: String) -> Label3D:
	var cached := _building_labels.get(building_id) as Label3D
	if is_instance_valid(cached):
		return cached

	var formal_buildings_root := get_node_or_null(FORMAL_BUILDING_ROOT_PATH)
	if formal_buildings_root != null:
		for raw_building_root in formal_buildings_root.get_children():
			var formal_building_root := raw_building_root as Node3D
			if formal_building_root == null or str(formal_building_root.get_meta("building_id", "")) != building_id:
				continue
			var formal_label := formal_building_root.get_node_or_null("NameLabel") as Label3D
			if formal_label != null:
				_building_labels[building_id] = formal_label
				return formal_label

	# Keep the legacy lookup as a compatibility fallback for scenes that do not
	# instantiate the formal station layout.
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var building_root := get_node_or_null(BUILDING_ROOT_PATH)
	if building_system == null or building_root == null or not building_system.has_method("get_building"):
		return null
	var building: Dictionary = building_system.get_building(building_id)
	for raw_node_name in building.get("scene_nodes", []):
		var building_node := building_root.get_node_or_null(str(raw_node_name))
		if building_node == null:
			continue
		for child in building_node.get_children():
			if child is Label3D:
				_building_labels[building_id] = child
				return child as Label3D
	return null


func _on_alert_pressed(building_id: String) -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.has_method("select_building"):
		building_system.select_building(building_id)
	var building_panel := get_node_or_null("/root/Main/UI/BuildingPanel")
	if building_panel != null and building_panel.has_method("open_crafting_target_selector"):
		building_panel.open_crafting_target_selector(building_id)


func _on_harvest_pressed(building_id: String) -> void:
	var dialog := get_node_or_null(HARVEST_DIALOG_PATH)
	if dialog != null and dialog.has_method("open_for_building"):
		dialog.open_for_building(building_id)


func debug_get_alert_snapshot(building_id: String) -> Dictionary:
	var alert := _alerts.get(building_id) as Button
	var label := _get_building_label(building_id)
	if alert == null:
		return {}
	return {
		"building_id": building_id,
		"needs_alert": bool(_needs_alert.get(building_id, false)),
		"visible": alert.visible,
		"text": alert.text,
		"tooltip": alert.tooltip_text,
		"position": alert.position,
		"label_path": str(label.get_path()) if label != null else ""
	}


func debug_set_viewport_size_override(viewport_size: Vector2) -> void:
	_debug_viewport_size_override = viewport_size
	_position_alerts()


func debug_get_harvest_snapshot(building_id: String) -> Dictionary:
	var button := _harvest_buttons.get(building_id) as Button
	var badge := _harvest_badges.get(building_id) as Label
	if button == null:
		return {}
	return {
		"building_id": building_id,
		"pending_total": int(_pending_totals.get(building_id, 0)),
		"visible": button.visible,
		"tooltip": button.tooltip_text,
		"badge_text": badge.text if badge != null else "",
		"icon_path": HARVEST_ICON_PATH,
		"position": button.position
	}


func debug_press_harvest(building_id: String) -> void:
	_on_harvest_pressed(building_id)
