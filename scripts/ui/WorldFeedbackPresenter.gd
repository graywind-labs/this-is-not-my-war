extends Control

const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const DEFENSE_DEVICE_SYSTEM_PATH := "/root/Main/Systems/DefenseDeviceSystem"
const MERCHANT_SYSTEM_PATH := "/root/Main/Systems/MerchantSystem"
const TOTAL_DURATION_SECONDS := 2.0
const STABLE_DURATION_SECONDS := 1.2
const FADE_DURATION_SECONDS := TOTAL_DURATION_SECONDS - STABLE_DURATION_SECONDS
const DRIFT_DISTANCE_PX := 36.0
const STACK_GAP_PX := 8.0
const SCREEN_MARGIN_PX := 48.0
const MAX_GROUPS_PER_ANCHOR := 2
const SHORT_MERGE_WINDOW_SECONDS := 0.45
const ENTRY_ICON_SIZE := Vector2(22.0, 22.0)

const ROLE_COLORS := {
	"consume": Color(0.62, 0.62, 0.60, 1.0),
	"gain": Color(0.96, 0.92, 0.82, 1.0),
	"growth": Color(0.40, 0.68, 0.92, 1.0),
	"piety": Color(0.91, 0.71, 0.25, 1.0),
	"neutral": Color(0.96, 0.92, 0.82, 1.0),
	"damage": Color(0.72, 0.23, 0.20, 1.0),
	"heal": Color(0.42, 0.72, 0.42, 1.0),
	"trade_out": Color(0.72, 0.23, 0.20, 1.0),
	"trade_in": Color(0.42, 0.72, 0.42, 1.0),
	"warning": Color(0.90, 0.64, 0.24, 1.0)
}

var _groups: Array[Dictionary] = []
var _sequence := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var event_bus := get_node_or_null("/root/EventBus")
	if (
		event_bus != null
		and event_bus.has_signal("world_feedback_requested")
		and not event_bus.world_feedback_requested.is_connected(_on_world_feedback_requested)
	):
		event_bus.world_feedback_requested.connect(_on_world_feedback_requested)


func _process(delta: float) -> void:
	_advance_groups(delta)


func _on_world_feedback_requested(feedback: Dictionary) -> void:
	debug_present(feedback)


func debug_present(feedback: Dictionary) -> void:
	var entries: Array = (feedback.get("entries", []) as Array).duplicate(true)
	var anchor_id := str(feedback.get("anchor_id", ""))
	if anchor_id.is_empty() or entries.is_empty():
		return
	var anchor_key := "%s:%s" % [str(feedback.get("anchor_type", "npc")), anchor_id]
	var channel := str(feedback.get("channel", "default"))
	if bool(feedback.get("merge_channel", false)):
		entries = _merge_recent_channel_entries(anchor_key, channel, entries)
	if bool(feedback.get("replace_channel", false)):
		_remove_matching_group(anchor_key, channel)
	_enforce_anchor_capacity(anchor_key)

	var container := VBoxContainer.new()
	container.name = "FeedbackGroup%d" % _sequence
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.z_index = 1
	container.add_theme_constant_override("separation", 1)
	add_child(container)

	var rendered_entries: Array[Dictionary] = []
	for raw_entry in entries:
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = (raw_entry as Dictionary).duplicate(true)
		if is_zero_approx(float(entry.get("amount", 0.0))):
			continue
		var rendered := _build_entry_row(container, entry)
		if not rendered.is_empty():
			rendered_entries.append(rendered)
	if rendered_entries.is_empty():
		container.queue_free()
		return

	_sequence += 1
	_groups.append({
		"control": container,
		"anchor_key": anchor_key,
		"anchor_type": str(feedback.get("anchor_type", "npc")),
		"anchor_id": anchor_id,
		"anchor_height": float(feedback.get("anchor_height", 4.25)),
		"fallback_world_position": feedback.get("fallback_world_position", null),
		"last_world_position": feedback.get("fallback_world_position", null),
		"prefer_fallback_position": bool(feedback.get("prefer_fallback_position", false)),
		"channel": channel,
		"elapsed": 0.0,
		"sequence": _sequence,
		"entries": rendered_entries
	})
	_position_groups()


func debug_advance_feedback(real_seconds: float) -> void:
	_advance_groups(maxf(0.0, real_seconds))


func debug_get_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for group in _groups:
		var control := group.get("control") as Control
		if not is_instance_valid(control):
			continue
		snapshot.append({
			"anchor_key": str(group.get("anchor_key", "")),
			"anchor_type": str(group.get("anchor_type", "")),
			"anchor_id": str(group.get("anchor_id", "")),
			"anchor_height": float(group.get("anchor_height", 0.0)),
			"fallback_world_position": group.get("fallback_world_position", null),
			"last_world_position": group.get("last_world_position", null),
			"prefer_fallback_position": bool(group.get("prefer_fallback_position", false)),
			"channel": str(group.get("channel", "")),
			"elapsed": float(group.get("elapsed", 0.0)),
			"visible": control.visible,
			"alpha": control.modulate.a,
			"position": control.position,
			"entries": (group.get("entries", []) as Array).duplicate(true)
		})
	return snapshot


func _build_entry_row(parent: VBoxContainer, entry: Dictionary) -> Dictionary:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var icon_path := str(entry.get("icon_path", ""))
	var has_icon := not icon_path.is_empty() and ResourceLoader.exists(icon_path)
	if has_icon:
		var texture := load(icon_path) as Texture2D
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = ENTRY_ICON_SIZE
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)
		else:
			has_icon = false

	var display_name := str(entry.get("display_name", ""))
	var value_text := _format_signed_value(entry.get("amount", 0), str(entry.get("suffix", "")))
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var default_text := value_text if has_icon or display_name.is_empty() else "%s %s" % [display_name, value_text]
	label.text = str(entry.get("text_override", default_text))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.055, 0.045, 0.035, 0.96))
	label.add_theme_color_override(
		"font_color",
		ROLE_COLORS.get(str(entry.get("color_role", "neutral")), ROLE_COLORS["neutral"])
	)
	row.add_child(label)
	return {
		"text": label.text,
		"display_name": display_name,
		"amount": entry.get("amount", 0),
		"color_role": str(entry.get("color_role", "neutral")),
		"icon_path": icon_path if has_icon else "",
		"components": (
			(entry.get("components", []) as Array).duplicate(true)
			if entry.get("components", []) is Array
			else []
		)
	}


func _advance_groups(delta: float) -> void:
	for index in range(_groups.size() - 1, -1, -1):
		var group: Dictionary = _groups[index]
		var control := group.get("control") as Control
		if not is_instance_valid(control):
			_groups.remove_at(index)
			continue
		var elapsed := float(group.get("elapsed", 0.0)) + delta
		group["elapsed"] = elapsed
		if elapsed >= TOTAL_DURATION_SECONDS:
			control.queue_free()
			_groups.remove_at(index)
			continue
		var fade_progress := clampf(
			(elapsed - STABLE_DURATION_SECONDS) / FADE_DURATION_SECONDS,
			0.0,
			1.0
		)
		control.modulate.a = 1.0 - fade_progress
		_groups[index] = group
	_position_groups()


func _position_groups() -> void:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	var viewport_size := get_viewport_rect().size
	var anchor_stack_counts: Dictionary = {}
	for index in range(_groups.size() - 1, -1, -1):
		var group: Dictionary = _groups[index]
		var control := group.get("control") as Control
		if not is_instance_valid(control):
			continue
		var world_position: Variant = _resolve_world_position(group)
		if world_position is Vector3:
			group["last_world_position"] = world_position
			_groups[index] = group
		else:
			world_position = group.get("last_world_position", null)
		if camera == null or not world_position is Vector3 or camera.is_position_behind(world_position):
			control.visible = false
			continue
		var screen_center := camera.unproject_position(world_position)
		var in_view := (
			screen_center.x >= -SCREEN_MARGIN_PX
			and screen_center.y >= -SCREEN_MARGIN_PX
			and screen_center.x <= viewport_size.x + SCREEN_MARGIN_PX
			and screen_center.y <= viewport_size.y + SCREEN_MARGIN_PX
		)
		if not in_view:
			control.visible = false
			continue
		var anchor_key := str(group.get("anchor_key", ""))
		var stack_index := int(anchor_stack_counts.get(anchor_key, 0))
		anchor_stack_counts[anchor_key] = stack_index + 1
		var fade_progress := clampf(
			(float(group.get("elapsed", 0.0)) - STABLE_DURATION_SECONDS) / FADE_DURATION_SECONDS,
			0.0,
			1.0
		)
		var drift := DRIFT_DISTANCE_PX * smoothstep(0.0, 1.0, fade_progress)
		var control_size := control.size
		if control_size.x <= 0.0 or control_size.y <= 0.0:
			control_size = control.get_combined_minimum_size()
		control.position = Vector2(
			screen_center.x - control_size.x * 0.5,
			screen_center.y - control_size.y - drift - float(stack_index) * (control_size.y + STACK_GAP_PX)
		)
		control.visible = true


func _resolve_world_position(group: Dictionary) -> Variant:
	var anchor_type := str(group.get("anchor_type", "npc"))
	var fallback_position: Variant = _to_vector3(group.get("fallback_world_position", null))
	var base_position: Variant = fallback_position if bool(group.get("prefer_fallback_position", false)) else null
	var complete_world_anchor := false
	var anchor_id := str(group.get("anchor_id", ""))
	if not base_position is Vector3:
		match anchor_type:
			"npc":
				var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
				if npc_system != null and npc_system.has_method("get_npc_world_position"):
					base_position = npc_system.get_npc_world_position(anchor_id)
			"enemy":
				var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
				if combat_system != null and combat_system.has_method("get_enemy_world_position"):
					base_position = combat_system.get_enemy_world_position(anchor_id)
			"horse":
				var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
				if horse_system != null and horse_system.has_method("get_horse_snapshot"):
					var horse: Dictionary = horse_system.get_horse_snapshot(anchor_id)
					base_position = horse.get("world_position", null)
			"building":
				var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
				if building_system != null and building_system.has_method("get_building_feedback_anchor_position"):
					base_position = building_system.get_building_feedback_anchor_position(anchor_id)
					complete_world_anchor = base_position is Vector3
				if not complete_world_anchor and building_system != null and building_system.has_method("get_building_entry_position"):
					base_position = building_system.get_building_entry_position(anchor_id)
			"defense_device":
				var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
				if device_system != null and device_system.has_method("get_deployment_feedback_anchor_position"):
					base_position = device_system.get_deployment_feedback_anchor_position(anchor_id)
					complete_world_anchor = base_position is Vector3
				if not complete_world_anchor and device_system != null and device_system.has_method("get_deployment"):
					var deployment: Dictionary = device_system.get_deployment(anchor_id)
					base_position = deployment.get("position", null)
			"merchant":
				var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
				if merchant_system != null and merchant_system.has_method("get_merchant_feedback_anchor_position"):
					base_position = merchant_system.get_merchant_feedback_anchor_position()
					complete_world_anchor = base_position is Vector3
	base_position = _to_vector3(base_position)
	if not base_position is Vector3:
		base_position = fallback_position
	if not base_position is Vector3:
		return null
	if complete_world_anchor:
		return base_position
	return (base_position as Vector3) + Vector3.UP * float(group.get("anchor_height", 0.0))


func _to_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if value is Dictionary and (value as Dictionary).has("x") and (value as Dictionary).has("z"):
		return Vector3(
			float((value as Dictionary).get("x", 0.0)),
			float((value as Dictionary).get("y", 0.0)),
			float((value as Dictionary).get("z", 0.0))
		)
	return null


func _remove_matching_group(anchor_key: String, channel: String) -> void:
	for index in range(_groups.size() - 1, -1, -1):
		var group: Dictionary = _groups[index]
		if str(group.get("anchor_key", "")) != anchor_key or str(group.get("channel", "")) != channel:
			continue
		var control := group.get("control") as Control
		if is_instance_valid(control):
			control.queue_free()
		_groups.remove_at(index)


func _merge_recent_channel_entries(anchor_key: String, channel: String, incoming_entries: Array) -> Array:
	for index in range(_groups.size() - 1, -1, -1):
		var group: Dictionary = _groups[index]
		if (
			str(group.get("anchor_key", "")) != anchor_key
			or str(group.get("channel", "")) != channel
			or float(group.get("elapsed", 0.0)) > SHORT_MERGE_WINDOW_SECONDS
		):
			continue
		var prior_entries: Array = group.get("entries", []) as Array
		if prior_entries.size() != 1 or incoming_entries.size() != 1:
			return incoming_entries
		var prior: Dictionary = prior_entries[0] if prior_entries[0] is Dictionary else {}
		var incoming: Dictionary = (incoming_entries[0] as Dictionary).duplicate(true) if incoming_entries[0] is Dictionary else {}
		if (
			prior.is_empty()
			or incoming.is_empty()
			or str(prior.get("display_name", "")) != str(incoming.get("display_name", ""))
			or str(prior.get("color_role", "")) != str(incoming.get("color_role", ""))
		):
			return incoming_entries
		incoming["amount"] = float(prior.get("amount", 0.0)) + float(incoming.get("amount", 0.0))
		var control := group.get("control") as Control
		if is_instance_valid(control):
			control.queue_free()
		_groups.remove_at(index)
		return [incoming]
	return incoming_entries


func _enforce_anchor_capacity(anchor_key: String) -> void:
	var matching_indices: Array[int] = []
	for index in range(_groups.size()):
		if str(_groups[index].get("anchor_key", "")) == anchor_key:
			matching_indices.append(index)
	while matching_indices.size() >= MAX_GROUPS_PER_ANCHOR:
		var remove_index: int = matching_indices.pop_front()
		var group: Dictionary = _groups[remove_index]
		var control := group.get("control") as Control
		if is_instance_valid(control):
			control.queue_free()
		_groups.remove_at(remove_index)
		for offset in range(matching_indices.size()):
			if matching_indices[offset] > remove_index:
				matching_indices[offset] -= 1


func _format_signed_value(value: Variant, suffix: String) -> String:
	var numeric := float(value)
	var number_text := (
		str(int(round(numeric)))
		if is_equal_approx(numeric, round(numeric))
		else ("%.1f" % numeric).trim_suffix("0").trim_suffix(".")
	)
	var sign_text := "+" if numeric > 0.0 else ""
	return "%s%s%s" % [sign_text, number_text, suffix]
