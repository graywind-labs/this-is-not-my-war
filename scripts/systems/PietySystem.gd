extends Node

const CONFIG_FILE := "piety_ability.json"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const EFFECTS_ROOT_PATH := "/root/Main/WorldRoot/Station/Effects"
const SYSTEM_ACTOR_ID := "guard_officer"
const PLAZA_LOCATION_ID := "plaza"

var _config: Dictionary = {}
var _current_piety := 0.0
var _total_generated := 0.0
var _generated_by_npc: Dictionary = {}
var _cast_sequence := 0
var _pending_meteors: Dictionary = {}
var _burn_zones: Dictionary = {}
var _meteor_visuals: Dictionary = {}
var _burn_visuals: Dictionary = {}
var _last_generation_result: Dictionary = {}
var _last_cast_result: Dictionary = {}
var _last_impact_result: Dictionary = {}
var _last_burn_tick_result: Dictionary = {}


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if (
		event_bus != null
		and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick)
	):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func initialize() -> void:
	_clear_effect_visuals()
	_current_piety = 0.0
	_total_generated = 0.0
	_generated_by_npc.clear()
	_cast_sequence = 0
	_pending_meteors.clear()
	_burn_zones.clear()
	_last_generation_result.clear()
	_last_cast_result.clear()
	_last_impact_result.clear()
	_last_burn_tick_result.clear()
	_load_config()
	_emit_piety_changed(0.0, "initialized")


func add_prayer_progress(
	npc_id: String,
	action_id: String,
	active_game_seconds: float,
	prayer_mode: String = ""
) -> Dictionary:
	var contributing_actions: Array = _config.get("contributing_action_ids", [])
	if (
		npc_id.is_empty()
		or not contributing_actions.has(action_id)
		or active_game_seconds <= 0.0
	):
		return {
			"ok": false,
			"reason": "invalid_prayer_progress",
			"added": 0.0
		}
	var max_piety := get_max_piety()
	if _current_piety >= max_piety - 0.0001:
		return {
			"ok": true,
			"reason": "piety_full",
			"added": 0.0,
			"current_piety": _current_piety,
			"max_piety": max_piety
		}
	var action_multipliers: Dictionary = _config.get("action_multipliers", {})
	var mode_multipliers: Dictionary = _config.get("prayer_mode_multipliers", {})
	var action_multiplier := maxf(0.0, float(action_multipliers.get(action_id, 1.0)))
	var mode_multiplier := maxf(0.0, float(mode_multipliers.get(prayer_mode, 1.0)))
	var rate_per_hour := maxf(0.0, float(_config.get("piety_per_prayer_hour", 0.0)))
	var requested_delta := (
		rate_per_hour
		* action_multiplier
		* mode_multiplier
		* active_game_seconds
		/ 3600.0
	)
	var before := _current_piety
	_current_piety = clampf(before + requested_delta, 0.0, max_piety)
	var added := _current_piety - before
	_total_generated += added
	_generated_by_npc[npc_id] = float(_generated_by_npc.get(npc_id, 0.0)) + added
	_last_generation_result = {
		"ok": true,
		"npc_id": npc_id,
		"action_id": action_id,
		"prayer_mode": prayer_mode,
		"active_game_seconds": active_game_seconds,
		"rate_per_prayer_hour": rate_per_hour,
		"added": added,
		"current_piety": _current_piety,
		"max_piety": max_piety,
		"ready": is_ready_to_cast()
	}
	if added > 0.0:
		_emit_piety_changed(added, "prayer_progress")
	return _last_generation_result.duplicate(true)


func request_meteor_cast(target_position: Vector3) -> Dictionary:
	if not is_ready_to_cast():
		return _failure("piety_not_full", "虔诚尚未充满。")
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.get("game_over")):
		return _failure("game_over", "游戏已经结算，不能施放陨石。")
	if not is_target_position_allowed(target_position):
		return _failure("invalid_target", "陨石落点必须位于驿站地表范围内。")

	var normalized_target := Vector3(
		target_position.x,
		float(_config.get("target_ground_y", 0.0)),
		target_position.z
	)
	var meteor_config := get_meteor_config()
	_cast_sequence += 1
	var cast_id := "piety_meteor_%03d" % _cast_sequence
	var piety_spent := _current_piety
	_current_piety = 0.0
	var state := {
		"cast_id": cast_id,
		"target_position": normalized_target,
		"elapsed_seconds": 0.0,
		"fall_duration_seconds": maxf(0.01, float(meteor_config.get("fall_duration_seconds", 1.0))),
		"start_height": maxf(1.0, float(meteor_config.get("start_height", 20.0))),
		"radius": maxf(0.1, float(meteor_config.get("radius", 5.0))),
		"piety_spent": piety_spent
	}
	_pending_meteors[cast_id] = state
	_create_meteor_visual(state)
	_emit_piety_changed(-piety_spent, "meteor_cast")
	_emit_event_bus_signal("meteor_cast_started", [cast_id, normalized_target, float(state["radius"])])
	var event := _record_meteor_cast_event(state)
	_last_cast_result = {
		"ok": true,
		"cast_id": cast_id,
		"target_position": _vector3_to_dict(normalized_target),
		"radius": float(state["radius"]),
		"piety_spent": piety_spent,
		"event": event
	}
	return _last_cast_result.duplicate(true)


func is_target_position_allowed(target_position: Vector3) -> bool:
	if (
		is_nan(target_position.x)
		or is_nan(target_position.y)
		or is_nan(target_position.z)
		or is_inf(target_position.x)
		or is_inf(target_position.y)
		or is_inf(target_position.z)
	):
		return false
	var bounds: Dictionary = _config.get("target_bounds", {})
	return (
		target_position.x >= float(bounds.get("min_x", -28.5))
		and target_position.x <= float(bounds.get("max_x", 28.5))
		and target_position.z >= float(bounds.get("min_z", -33.5))
		and target_position.z <= float(bounds.get("max_z", 33.5))
	)


func get_current_piety() -> float:
	return _current_piety


func get_max_piety() -> float:
	return maxf(1.0, float(_config.get("max_piety", 100.0)))


func is_ready_to_cast() -> bool:
	return _current_piety >= get_max_piety() - 0.001


func get_meteor_config() -> Dictionary:
	var meteor: Variant = _config.get("meteor", {})
	return (meteor as Dictionary).duplicate(true) if meteor is Dictionary else {}


func get_targeting_snapshot() -> Dictionary:
	var meteor := get_meteor_config()
	return {
		"radius": maxf(0.1, float(meteor.get("radius", 5.0))),
		"ground_y": float(_config.get("target_ground_y", 0.0)),
		"bounds": (_config.get("target_bounds", {}) as Dictionary).duplicate(true)
	}


func get_piety_snapshot() -> Dictionary:
	return {
		"current_piety": _current_piety,
		"max_piety": get_max_piety(),
		"progress": clampf(_current_piety / get_max_piety(), 0.0, 1.0),
		"ready": is_ready_to_cast(),
		"piety_per_prayer_hour": float(_config.get("piety_per_prayer_hour", 0.0)),
		"total_generated": _total_generated,
		"generated_by_npc": _generated_by_npc.duplicate(true),
		"pending_meteors": _serialize_effect_map(_pending_meteors),
		"burn_zones": _serialize_effect_map(_burn_zones),
		"last_generation_result": _last_generation_result.duplicate(true),
		"last_cast_result": _last_cast_result.duplicate(true),
		"last_impact_result": _last_impact_result.duplicate(true),
		"last_burn_tick_result": _last_burn_tick_result.duplicate(true),
		"config": _config.duplicate(true)
	}


func debug_set_piety(value: float) -> Dictionary:
	var before := _current_piety
	_current_piety = clampf(value, 0.0, get_max_piety())
	_emit_piety_changed(_current_piety - before, "gm_set")
	return get_piety_snapshot()


func debug_fill_piety() -> Dictionary:
	return debug_set_piety(get_max_piety())


func debug_advance_effects(game_seconds: float) -> Dictionary:
	_advance_effects(_get_combat_action_seconds(maxf(0.0, game_seconds)))
	return get_piety_snapshot()


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	_advance_effects(_get_combat_action_seconds(game_delta_seconds))


func _advance_effects(combat_delta_seconds: float) -> void:
	if combat_delta_seconds <= 0.0:
		return
	_advance_burn_zones(combat_delta_seconds)
	var cast_ids := _pending_meteors.keys()
	for raw_cast_id in cast_ids:
		var cast_id := str(raw_cast_id)
		if not _pending_meteors.has(cast_id):
			continue
		var state: Dictionary = _pending_meteors.get(cast_id, {})
		var duration := maxf(0.01, float(state.get("fall_duration_seconds", 1.0)))
		var elapsed := minf(duration, float(state.get("elapsed_seconds", 0.0)) + combat_delta_seconds)
		state["elapsed_seconds"] = elapsed
		_pending_meteors[cast_id] = state
		_update_meteor_visual(state)
		if elapsed < duration:
			continue
		_pending_meteors.erase(cast_id)
		_resolve_meteor_impact(state)


func _advance_burn_zones(combat_delta_seconds: float) -> void:
	var zone_ids := _burn_zones.keys()
	for raw_zone_id in zone_ids:
		var zone_id := str(raw_zone_id)
		if not _burn_zones.has(zone_id):
			continue
		var zone: Dictionary = _burn_zones.get(zone_id, {})
		var duration := maxf(0.01, float(zone.get("duration_seconds", 0.0)))
		var elapsed_before := clampf(float(zone.get("elapsed_seconds", 0.0)), 0.0, duration)
		var active_delta := minf(combat_delta_seconds, maxf(0.0, duration - elapsed_before))
		var tick_interval := maxf(0.05, float(zone.get("tick_interval_seconds", 1.0)))
		var tick_accumulator := float(zone.get("tick_accumulator", 0.0)) + active_delta
		while tick_accumulator >= tick_interval:
			tick_accumulator -= tick_interval
			_apply_burn_tick(zone)
		zone["tick_accumulator"] = tick_accumulator
		zone["elapsed_seconds"] = elapsed_before + active_delta
		_burn_zones[zone_id] = zone
		if float(zone["elapsed_seconds"]) < duration:
			continue
		_burn_zones.erase(zone_id)
		_remove_burn_visual(zone_id)


func _resolve_meteor_impact(state: Dictionary) -> void:
	var cast_id := str(state.get("cast_id", ""))
	_remove_meteor_visual(cast_id)
	var meteor := get_meteor_config()
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	var damage_result: Dictionary = {}
	if combat_system != null and combat_system.has_method("apply_enemy_area_damage"):
		damage_result = combat_system.apply_enemy_area_damage(
			state.get("target_position", Vector3.ZERO),
			float(state.get("radius", meteor.get("radius", 5.0))),
			maxf(0.0, float(meteor.get("impact_damage", 0.0))),
			{
				"penetration": maxf(0.0, float(meteor.get("impact_penetration", 0.0))),
				"max_targets": maxi(0, int(meteor.get("impact_max_targets", 0))),
				"source_type": "piety_meteor_impact",
				"source_id": cast_id,
				"source_name": "陨石",
				"mode_exit_reason": "enemies_defeated_by_meteor"
			}
		)
	var burn_zone := _create_burn_zone(state, meteor)
	var hit_count := int(damage_result.get("hit_count", 0))
	var defeated_count := int(damage_result.get("defeated_count", 0))
	var event := _record_meteor_impact_event(
		state,
		hit_count,
		defeated_count,
		float(burn_zone.get("duration_seconds", 0.0))
	)
	_last_impact_result = {
		"ok": not damage_result.is_empty(),
		"cast_id": cast_id,
		"target_position": _vector3_to_dict(state.get("target_position", Vector3.ZERO)),
		"radius": float(state.get("radius", 0.0)),
		"max_targets": maxi(0, int(meteor.get("impact_max_targets", 0))),
		"hit_count": hit_count,
		"defeated_count": defeated_count,
		"damage_result": damage_result,
		"burn_zone": _serialize_effect_state(burn_zone),
		"event": event
	}
	_emit_event_bus_signal("meteor_impacted", [cast_id, _last_impact_result.duplicate(true)])


func _create_burn_zone(state: Dictionary, meteor: Dictionary) -> Dictionary:
	var cast_id := str(state.get("cast_id", ""))
	var zone_id := "%s_burn" % cast_id
	var zone := {
		"zone_id": zone_id,
		"cast_id": cast_id,
		"target_position": state.get("target_position", Vector3.ZERO),
		"radius": float(state.get("radius", meteor.get("radius", 5.0))),
		"elapsed_seconds": 0.0,
		"duration_seconds": maxf(0.01, float(meteor.get("burn_duration_seconds", 10.0))),
		"tick_interval_seconds": maxf(0.05, float(meteor.get("burn_tick_interval_seconds", 1.0))),
		"tick_accumulator": 0.0,
		"damage": maxf(0.0, float(meteor.get("burn_damage", 1.0))),
		"penetration": maxf(0.0, float(meteor.get("burn_penetration", 0.0)))
	}
	_burn_zones[zone_id] = zone
	_create_burn_visual(zone)
	return zone


func _apply_burn_tick(zone: Dictionary) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("apply_enemy_area_damage"):
		return
	_last_burn_tick_result = combat_system.apply_enemy_area_damage(
		zone.get("target_position", Vector3.ZERO),
		float(zone.get("radius", 0.0)),
		float(zone.get("damage", 0.0)),
		{
			"penetration": float(zone.get("penetration", 0.0)),
			"source_type": "piety_meteor_burn",
			"source_id": str(zone.get("zone_id", "")),
			"source_name": "燃烧地面",
			"mode_exit_reason": "enemies_defeated_by_meteor_burn"
		}
	)


func _load_config() -> void:
	var loaded: Variant = {}
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader != null:
		loaded = config_loader.load_data_file(CONFIG_FILE, {})
	_config = (loaded as Dictionary).duplicate(true) if loaded is Dictionary else {}
	if _config.is_empty():
		push_error("PietySystem could not load %s." % CONFIG_FILE)
		_config = {
			"max_piety": 100.0,
			"piety_per_prayer_hour": 3.0,
			"contributing_action_ids": ["pray_at_chapel", "lead_mass"],
			"action_multipliers": {},
			"prayer_mode_multipliers": {},
			"combat_action_game_seconds_per_second": 60.0,
			"target_ground_y": 0.0,
			"target_bounds": {
				"min_x": -28.5,
				"max_x": 28.5,
				"min_z": -33.5,
				"max_z": 33.5
			},
			"meteor": {
				"radius": 5.5,
				"fall_duration_seconds": 1.15,
				"start_height": 20.0,
				"impact_damage": 48.0,
				"impact_penetration": 5.0,
				"impact_max_targets": 12,
				"burn_duration_seconds": 10.0,
				"burn_tick_interval_seconds": 1.0,
				"burn_damage": 1.0,
				"burn_penetration": 0.0
			}
		}
	_config["max_piety"] = maxf(1.0, float(_config.get("max_piety", 100.0)))
	_config["piety_per_prayer_hour"] = maxf(0.0, float(_config.get("piety_per_prayer_hour", 3.0)))


func _record_meteor_cast_event(state: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "piety_meteor_cast",
		"subject_npc_id": SYSTEM_ACTOR_ID,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [str(state.get("cast_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 90,
		"payload": {
			"cast_id": str(state.get("cast_id", "")),
			"target_position": _vector3_to_dict(state.get("target_position", Vector3.ZERO)),
			"radius": float(state.get("radius", 0.0)),
			"piety_spent": float(state.get("piety_spent", 0.0))
		}
	})


func _record_meteor_impact_event(
	state: Dictionary,
	hit_count: int,
	defeated_count: int,
	burn_duration_seconds: float
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var meteor := get_meteor_config()
	return memory_system.add_event({
		"type": "piety_meteor_impact",
		"subject_npc_id": SYSTEM_ACTOR_ID,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [str(state.get("cast_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 95,
		"payload": {
			"cast_id": str(state.get("cast_id", "")),
			"target_position": _vector3_to_dict(state.get("target_position", Vector3.ZERO)),
			"radius": float(state.get("radius", 0.0)),
			"impact_damage": float(meteor.get("impact_damage", 0.0)),
			"impact_max_targets": maxi(0, int(meteor.get("impact_max_targets", 0))),
			"enemy_hit_count": hit_count,
			"enemy_defeated_count": defeated_count,
			"burn_duration_seconds": burn_duration_seconds,
			"friendly_fire": false
		}
	})


func _create_meteor_visual(state: Dictionary) -> void:
	var effects_root := get_node_or_null(EFFECTS_ROOT_PATH) as Node3D
	if effects_root == null:
		return
	var cast_id := str(state.get("cast_id", ""))
	var visual := Node3D.new()
	visual.name = "%sVisual" % cast_id.to_pascal_case()
	visual.set_meta("cast_id", cast_id)
	var body := MeshInstance3D.new()
	body.name = "MeteorBody"
	var sphere := SphereMesh.new()
	sphere.radius = 0.48
	sphere.height = 0.96
	body.mesh = sphere
	body.set_surface_override_material(0, _make_effect_material(Color(1.0, 0.24, 0.04, 1.0), false))
	visual.add_child(body)
	var light := OmniLight3D.new()
	light.name = "MeteorLight"
	light.light_color = Color(1.0, 0.34, 0.08, 1.0)
	light.light_energy = 4.0
	light.omni_range = 8.0
	visual.add_child(light)
	effects_root.add_child(visual)
	_meteor_visuals[cast_id] = visual
	_update_meteor_visual(state)


func _update_meteor_visual(state: Dictionary) -> void:
	var cast_id := str(state.get("cast_id", ""))
	var visual := _meteor_visuals.get(cast_id, null) as Node3D
	if visual == null:
		return
	var duration := maxf(0.01, float(state.get("fall_duration_seconds", 1.0)))
	var progress := clampf(float(state.get("elapsed_seconds", 0.0)) / duration, 0.0, 1.0)
	var target: Vector3 = state.get("target_position", Vector3.ZERO)
	var start_height := float(state.get("start_height", 20.0))
	visual.global_position = target + Vector3(0.0, lerpf(start_height, 0.45, progress), 0.0)


func _create_burn_visual(zone: Dictionary) -> void:
	var effects_root := get_node_or_null(EFFECTS_ROOT_PATH) as Node3D
	if effects_root == null:
		return
	var zone_id := str(zone.get("zone_id", ""))
	var visual := Node3D.new()
	visual.name = "%sVisual" % zone_id.to_pascal_case()
	visual.set_meta("zone_id", zone_id)
	var disk := MeshInstance3D.new()
	disk.name = "BurningGround"
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(zone.get("radius", 5.0))
	mesh.bottom_radius = float(zone.get("radius", 5.0))
	mesh.height = 0.035
	mesh.radial_segments = 64
	disk.mesh = mesh
	disk.set_surface_override_material(0, _make_effect_material(Color(1.0, 0.18, 0.015, 0.34), true))
	visual.add_child(disk)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0.0, 1.0, 0.0)
	light.light_color = Color(1.0, 0.26, 0.04, 1.0)
	light.light_energy = 1.5
	light.omni_range = float(zone.get("radius", 5.0)) * 1.6
	visual.add_child(light)
	effects_root.add_child(visual)
	visual.global_position = zone.get("target_position", Vector3.ZERO) + Vector3(0.0, 0.04, 0.0)
	_burn_visuals[zone_id] = visual


func _make_effect_material(color: Color, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 2.0
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _remove_meteor_visual(cast_id: String) -> void:
	var visual := _meteor_visuals.get(cast_id, null) as Node
	if visual != null:
		visual.queue_free()
	_meteor_visuals.erase(cast_id)


func _remove_burn_visual(zone_id: String) -> void:
	var visual := _burn_visuals.get(zone_id, null) as Node
	if visual != null:
		visual.queue_free()
	_burn_visuals.erase(zone_id)


func _clear_effect_visuals() -> void:
	for visual in _meteor_visuals.values():
		if visual is Node and is_instance_valid(visual):
			(visual as Node).queue_free()
	for visual in _burn_visuals.values():
		if visual is Node and is_instance_valid(visual):
			(visual as Node).queue_free()
	_meteor_visuals.clear()
	_burn_visuals.clear()


func _get_combat_action_seconds(game_seconds: float) -> float:
	var divisor := maxf(1.0, float(_config.get("combat_action_game_seconds_per_second", 60.0)))
	return game_seconds / divisor


func _emit_piety_changed(delta: float, reason: String) -> void:
	_emit_event_bus_signal(
		"piety_changed",
		[_current_piety, get_max_piety(), delta, reason]
	)


func _emit_event_bus_signal(signal_name: String, args: Array) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null or not event_bus.has_signal(signal_name):
		return
	match args.size():
		2:
			event_bus.emit_signal(signal_name, args[0], args[1])
		3:
			event_bus.emit_signal(signal_name, args[0], args[1], args[2])
		4:
			event_bus.emit_signal(signal_name, args[0], args[1], args[2], args[3])


func _serialize_effect_map(source: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in source.keys():
		var state: Dictionary = source.get(key, {})
		result.append(_serialize_effect_state(state))
	return result


func _serialize_effect_state(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	if result.get("target_position") is Vector3:
		result["target_position"] = _vector3_to_dict(result["target_position"])
	return result


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _failure(error: String, message: String) -> Dictionary:
	return {"ok": false, "error": error, "message": message}
