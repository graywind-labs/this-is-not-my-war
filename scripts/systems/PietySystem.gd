extends Node

const WorldFeedbackPayload = preload("res://scripts/core/WorldFeedbackPayload.gd")
const CONFIG_FILE := "piety_ability.json"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"
const EFFECTS_ROOT_PATH := "/root/Main/WorldRoot/Station/Effects"
const CAMERA_RIG_PATH := "/root/Main/CameraRig"
const METEOR_PRESENTATION_SCRIPT := preload("res://scripts/presentation/combat/FormalMeteorArt.gd")
const SYSTEM_ACTOR_ID := "guard_officer"
const PLAZA_LOCATION_ID := "plaza"
const WORLD_FEEDBACK_EPSILON := 0.00001

var _config: Dictionary = {}
var _current_piety := 0.0
var _total_generated := 0.0
var _generated_by_npc: Dictionary = {}
var _world_feedback_accumulators: Dictionary = {}
var _cast_sequence := 0
var _pending_meteors: Dictionary = {}
var _burn_zones: Dictionary = {}
var _meteor_visuals: Dictionary = {}
var _burn_visuals: Dictionary = {}
var _landed_meteor_visuals: Dictionary = {}
var _permanent_crater_visuals: Dictionary = {}
var _crater_lifetimes: Dictionary = {}
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
	if event_bus != null and not event_bus.event_recorded.is_connected(_on_event_recorded):
		event_bus.event_recorded.connect(_on_event_recorded)


func _process(real_delta_seconds: float) -> void:
	if real_delta_seconds <= 0.0 or _pending_meteors.is_empty() or _is_gameplay_time_paused():
		return
	_advance_pending_meteors(real_delta_seconds)


func initialize() -> void:
	_clear_effect_visuals()
	_current_piety = 0.0
	_total_generated = 0.0
	_generated_by_npc.clear()
	_world_feedback_accumulators.clear()
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
		_record_piety_world_feedback(npc_id, added)
	return _last_generation_result.duplicate(true)


func _record_piety_world_feedback(npc_id: String, added: float) -> void:
	if npc_id.is_empty() or added <= 0.0:
		return
	var accumulated := float(_world_feedback_accumulators.get(npc_id, 0.0)) + added
	var visible_amount := floori(accumulated + WORLD_FEEDBACK_EPSILON)
	if visible_amount <= 0:
		_world_feedback_accumulators[npc_id] = accumulated
		return
	var remainder := maxf(0.0, accumulated - float(visible_amount))
	if remainder <= WORLD_FEEDBACK_EPSILON:
		_world_feedback_accumulators.erase(npc_id)
	else:
		_world_feedback_accumulators[npc_id] = remainder
	var entry := WorldFeedbackPayload.make_value_entry("虔诚", visible_amount, "piety")
	if entry.is_empty():
		return
	WorldFeedbackPayload.emit_npc(self, npc_id, "piety", [entry], true)


func request_meteor_cast(target_position: Vector3) -> Dictionary:
	if not is_ready_to_cast():
		return _failure("piety_not_full", "虔诚尚未充满。")
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and bool(game_state.get("game_over")):
		return _failure("game_over", "游戏已经结算，不能施放陨石。")
	var validation := get_target_position_validation(target_position)
	if not bool(validation.get("allowed", false)):
		return _failure(
			str(validation.get("reason", "invalid_target")),
			str(validation.get("message", "陨石落点坐标无效。"))
		)

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
	_world_feedback_accumulators.clear()
	var state := {
		"cast_id": cast_id,
		"target_position": normalized_target,
		"elapsed_seconds": 0.0,
		"fall_duration_seconds": maxf(0.01, float(meteor_config.get("fall_duration_seconds", 1.0))),
		"start_height": maxf(1.0, float(meteor_config.get("start_height", 20.0))),
		"start_position": _get_meteor_start_position(normalized_target, meteor_config),
		"radius": maxf(0.1, float(meteor_config.get("radius", 5.0))),
		"piety_spent": piety_spent
	}
	_pending_meteors[cast_id] = state
	_create_meteor_visual(state)
	_request_camera_shake(
		float(state["fall_duration_seconds"]),
		maxf(0.0, float(meteor_config.get("descent_camera_shake_amplitude", 0.1))),
		maxf(1.0, float(meteor_config.get("descent_camera_shake_frequency", 9.0)))
	)
	_emit_piety_changed(-piety_spent, "meteor_cast")
	_emit_event_bus_signal("meteor_cast_started", [cast_id, normalized_target, float(state["radius"])])
	_last_cast_result = {
		"ok": true,
		"cast_id": cast_id,
		"target_position": _vector3_to_dict(normalized_target),
		"radius": float(state["radius"]),
		"piety_spent": piety_spent
	}
	return _last_cast_result.duplicate(true)


func is_target_position_allowed(target_position: Vector3) -> bool:
	return bool(get_target_position_validation(target_position).get("allowed", false))


func get_target_position_validation(target_position: Vector3) -> Dictionary:
	var finite := not (
		is_nan(target_position.x)
		or is_nan(target_position.y)
		or is_nan(target_position.z)
		or is_inf(target_position.x)
		or is_inf(target_position.y)
		or is_inf(target_position.z)
	)
	if not finite:
		return {
			"allowed": false,
			"reason": "invalid_target",
			"message": "陨石落点坐标无效。",
		}
	var meteor := get_meteor_config()
	var radius := maxf(0.1, float(meteor.get("radius", 5.0)))
	var controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if controller != null and controller.has_method("get_building_area_overlap"):
		var blocker: Dictionary = controller.get_building_area_overlap(target_position, radius)
		if not blocker.is_empty():
			return {
				"allowed": false,
				"reason": "building_overlap",
				"message": "赖天主仁慈，陨石不能砸到建筑",
				"blocker": blocker,
				"radius": radius,
			}
	return {
		"allowed": true,
		"reason": "",
		"message": "",
		"radius": radius,
	}


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
		"scope": "unbounded_ground_plane_except_buildings"
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
		"landed_meteors": _get_landed_meteor_snapshots(),
		"craters": _get_crater_snapshots(),
		"permanent_craters": _get_permanent_crater_snapshots(),
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
	_advance_crater_lifetimes(game_delta_seconds)
	_advance_burn_zones(_get_combat_action_seconds(game_delta_seconds))


func _on_event_recorded(event: Dictionary) -> void:
	if str(event.get("type", "")) != "combat_ended":
		return
	_remove_landed_meteor_bodies()


func _advance_effects(combat_delta_seconds: float) -> void:
	if combat_delta_seconds <= 0.0:
		return
	_advance_burn_zones(combat_delta_seconds)
	_advance_pending_meteors(combat_delta_seconds)


func _advance_pending_meteors(combat_delta_seconds: float) -> void:
	if combat_delta_seconds <= 0.0:
		return
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


func _is_gameplay_time_paused() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return (
		time_system != null
		and time_system.has_method("is_gameplay_paused")
		and bool(time_system.is_gameplay_paused())
	)


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
	var meteor := get_meteor_config()
	var visual := _meteor_visuals.get(cast_id, null) as Node3D
	var landed_collision_radius := maxf(0.1, float(meteor.get("body_radius", 4.2)) * 0.78)
	if visual != null and visual.has_method("get_landed_collision_radius"):
		landed_collision_radius = maxf(0.1, float(visual.get_landed_collision_radius()))
	var friendly_displacement := _displace_friendly_npcs_for_landed_body(
		state.get("target_position", Vector3.ZERO),
		landed_collision_radius,
		cast_id,
		maxf(0.02, float(meteor.get("friendly_displacement_margin", 0.12)))
	)
	if visual != null and visual.has_method("impact_at"):
		visual.impact_at(state.get("target_position", Vector3.ZERO))
		_landed_meteor_visuals[cast_id] = visual
		_permanent_crater_visuals[cast_id] = visual
		_crater_lifetimes[cast_id] = {
			"cast_id": cast_id,
			"elapsed_game_seconds": 0.0,
			"duration_game_seconds": maxf(
				1.0,
				float(meteor.get("crater_lifetime_game_seconds", 86400.0))
			),
			"fade_progress": 0.0,
			"opacity": 1.0,
		}
	_meteor_visuals.erase(cast_id)
	_request_camera_shake(
		maxf(0.1, float(meteor.get("impact_camera_shake_duration_seconds", 2.0))),
		maxf(0.0, float(meteor.get("impact_camera_shake_amplitude", 0.82))),
		maxf(1.0, float(meteor.get("impact_camera_shake_frequency", 23.0)))
	)
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
	var defeat_event := _record_meteor_defeat_event(state, defeated_count)
	_last_impact_result = {
		"ok": not damage_result.is_empty(),
		"cast_id": cast_id,
		"target_position": _vector3_to_dict(state.get("target_position", Vector3.ZERO)),
		"radius": float(state.get("radius", 0.0)),
		"max_targets": maxi(0, int(meteor.get("impact_max_targets", 0))),
		"hit_count": hit_count,
		"defeated_count": defeated_count,
		"damage_result": damage_result,
		"friendly_displacement": friendly_displacement,
		"burn_zone": _serialize_effect_state(burn_zone),
		"presentation": (
			visual.get_presentation_snapshot()
			if visual != null and visual.has_method("get_presentation_snapshot")
			else {}
		),
		"event": event,
		"defeat_event": defeat_event
	}
	_emit_event_bus_signal("meteor_impacted", [cast_id, _last_impact_result.duplicate(true)])


func _displace_friendly_npcs_for_landed_body(
	center: Vector3,
	obstacle_radius: float,
	cast_id: String,
	clearance_margin: float
) -> Dictionary:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("displace_npcs_from_world_obstacle"):
		return {
			"ok": false,
			"reason": "npc_displacement_authority_unavailable",
			"affected_count": 0,
			"displaced_count": 0,
		}
	return npc_system.displace_npcs_from_world_obstacle(
		center,
		obstacle_radius,
		cast_id,
		clearance_margin
	)


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
			"piety_per_prayer_hour": 2.5,
			"contributing_action_ids": ["pray_at_chapel", "lead_mass"],
			"action_multipliers": {
				"pray_at_chapel": 1.0,
				"lead_mass": 2.0
			},
			"prayer_mode_multipliers": {
				"personal_prayer": 1.0,
				"mass_attendance": 2.0
			},
			"combat_action_game_seconds_per_second": 1.0,
			"target_ground_y": 0.0,
			"meteor": {
				"radius": 5.5,
				"fall_duration_seconds": 2.8,
				"start_height": 30.0,
				"start_horizontal_offset": 15.0,
				"body_radius": 4.2,
				"friendly_displacement_margin": 0.12,
				"crater_radius": 4.8,
				"crater_lifetime_game_seconds": 86400.0,
				"descent_camera_shake_amplitude": 0.1,
				"descent_camera_shake_frequency": 9.0,
				"impact_camera_shake_duration_seconds": 2.0,
				"impact_camera_shake_amplitude": 0.82,
				"impact_camera_shake_frequency": 23.0,
				"impact_vfx_duration_seconds": 2.0,
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
	_config["piety_per_prayer_hour"] = maxf(0.0, float(_config.get("piety_per_prayer_hour", 2.5)))


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


func _record_meteor_defeat_event(state: Dictionary, defeated_count: int) -> Dictionary:
	if defeated_count <= 0:
		return {}
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "piety_meteor_enemy_defeated",
		"subject_npc_id": SYSTEM_ACTOR_ID,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [str(state.get("cast_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 98,
		"payload": {
			"cast_id": str(state.get("cast_id", "")),
			"enemy_defeated_count": defeated_count
		}
	})


func _create_meteor_visual(state: Dictionary) -> void:
	var effects_root := get_node_or_null(EFFECTS_ROOT_PATH) as Node3D
	if effects_root == null:
		return
	var cast_id := str(state.get("cast_id", ""))
	var visual := METEOR_PRESENTATION_SCRIPT.new() as Node3D
	visual.name = "%sVisual" % cast_id.to_pascal_case()
	visual.set_meta("cast_id", cast_id)
	effects_root.add_child(visual)
	visual.configure(get_meteor_config())
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
	var start_position: Vector3 = state.get(
		"start_position",
		target + Vector3(0.0, float(state.get("start_height", 20.0)), 0.0)
	)
	var eased_progress := pow(progress, 1.35)
	var landing_position := target + Vector3(0.0, 0.02, 0.0)
	if visual.has_method("set_fall_transform"):
		var visual_position := start_position.lerp(landing_position, eased_progress)
		if visual.has_method("get_fall_world_position"):
			visual_position = visual.get_fall_world_position(start_position, target, progress)
		visual.set_fall_transform(visual_position, progress)


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
	# The approved crater supplies the ground surface; retain the burn emitter root.
	disk.visible = false
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(zone.get("radius", 5.0))
	mesh.bottom_radius = float(zone.get("radius", 5.0))
	mesh.height = 0.035
	mesh.radial_segments = 64
	disk.mesh = mesh
	disk.set_surface_override_material(0, _make_effect_material(Color(1.0, 0.13, 0.01, 0.16), true))
	visual.add_child(disk)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0.0, 1.0, 0.0)
	light.light_color = Color(1.0, 0.26, 0.04, 1.0)
	light.light_energy = 1.5
	light.omni_range = float(zone.get("radius", 5.0)) * 1.6
	visual.add_child(light)
	for index in range(14):
		var angle := TAU * float(index) / 14.0 + 0.37 * float(index % 3)
		var distance := float(zone.get("radius", 5.0)) * (0.22 + 0.055 * float(index % 7))
		var flame := _make_ground_flame_particles(index)
		flame.position = Vector3(cos(angle) * distance, 0.08, sin(angle) * distance)
		visual.add_child(flame)
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


func _remove_landed_meteor_bodies() -> void:
	for raw_cast_id in _landed_meteor_visuals.keys():
		var cast_id := str(raw_cast_id)
		var visual := _landed_meteor_visuals.get(raw_cast_id, null) as Node
		if visual is Node and is_instance_valid(visual) and visual.has_method("remove_landed_body"):
			visual.remove_landed_body()
		if (
			visual != null
			and is_instance_valid(visual)
			and not _permanent_crater_visuals.has(cast_id)
		):
			visual.queue_free()
	_landed_meteor_visuals.clear()


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
	for visual in _permanent_crater_visuals.values():
		if visual is Node and is_instance_valid(visual) and not visual.is_queued_for_deletion():
			(visual as Node).queue_free()
	for visual in _landed_meteor_visuals.values():
		if visual is Node and is_instance_valid(visual) and not visual.is_queued_for_deletion():
			(visual as Node).queue_free()
	_meteor_visuals.clear()
	_burn_visuals.clear()
	_landed_meteor_visuals.clear()
	_permanent_crater_visuals.clear()
	_crater_lifetimes.clear()


func _get_combat_action_seconds(game_seconds: float) -> float:
	var divisor := maxf(1.0, float(_config.get("combat_action_game_seconds_per_second", 1.0)))
	return game_seconds / divisor


func _emit_piety_changed(delta: float, reason: String) -> void:
	var max_piety := get_max_piety()
	var previous_piety := _current_piety - delta
	_emit_event_bus_signal(
		"piety_changed",
		[_current_piety, max_piety, delta, reason]
	)
	if previous_piety < max_piety - 0.001 and _current_piety >= max_piety - 0.001:
		_emit_event_bus_signal("piety_ready", [_current_piety, max_piety, reason])


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
	if result.get("start_position") is Vector3:
		result["start_position"] = _vector3_to_dict(result["start_position"])
	return result


func _get_meteor_start_position(target: Vector3, meteor: Dictionary) -> Vector3:
	var horizontal_direction := Vector3(0.0, 0.0, -1.0)
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH) as Node3D
	if camera_rig != null:
		var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
		if camera != null:
			horizontal_direction = -camera.global_basis.z
			horizontal_direction.y = 0.0
			if horizontal_direction.length_squared() > 0.0001:
				horizontal_direction = horizontal_direction.normalized()
	var horizontal_offset := maxf(0.0, float(meteor.get("start_horizontal_offset", 15.0)))
	var start_height := maxf(1.0, float(meteor.get("start_height", 30.0)))
	return target + horizontal_direction * horizontal_offset + Vector3.UP * start_height


func _request_camera_shake(duration: float, amplitude: float, frequency: float) -> void:
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if camera_rig != null and camera_rig.has_method("request_camera_shake"):
		camera_rig.request_camera_shake(duration, amplitude, frequency)


func _get_landed_meteor_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_cast_id in _landed_meteor_visuals.keys():
		var visual := _landed_meteor_visuals.get(raw_cast_id, null) as Node
		result.append({
			"cast_id": str(raw_cast_id),
			"presentation": (
				visual.get_presentation_snapshot()
				if visual != null and visual.has_method("get_presentation_snapshot")
				else {}
			)
		})
	return result


func _get_crater_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_cast_id in _permanent_crater_visuals.keys():
		var cast_id := str(raw_cast_id)
		var visual := _permanent_crater_visuals.get(raw_cast_id, null) as Node
		var lifetime: Dictionary = _crater_lifetimes.get(cast_id, {})
		result.append({
			"cast_id": cast_id,
			"present": visual != null and is_instance_valid(visual),
			"elapsed_game_seconds": float(lifetime.get("elapsed_game_seconds", 0.0)),
			"duration_game_seconds": float(lifetime.get("duration_game_seconds", 0.0)),
			"fade_progress": float(lifetime.get("fade_progress", 0.0)),
			"opacity": float(lifetime.get("opacity", 1.0)),
			"presentation": (
				visual.get_presentation_snapshot()
				if visual != null and visual.has_method("get_presentation_snapshot")
				else {}
			)
		})
	return result


func _get_permanent_crater_snapshots() -> Array[Dictionary]:
	# Compatibility alias for T0165-era GM/tests. Entries now expire after 24 game hours.
	return _get_crater_snapshots()


func _advance_crater_lifetimes(game_delta_seconds: float) -> void:
	if game_delta_seconds <= 0.0 or _crater_lifetimes.is_empty():
		return
	for raw_cast_id in _crater_lifetimes.keys():
		var cast_id := str(raw_cast_id)
		if not _crater_lifetimes.has(cast_id):
			continue
		var lifetime: Dictionary = _crater_lifetimes.get(cast_id, {})
		var duration := maxf(1.0, float(lifetime.get("duration_game_seconds", 86400.0)))
		var elapsed := minf(
			duration,
			float(lifetime.get("elapsed_game_seconds", 0.0)) + game_delta_seconds
		)
		var fade_progress := clampf(elapsed / duration, 0.0, 1.0)
		lifetime["elapsed_game_seconds"] = elapsed
		lifetime["fade_progress"] = fade_progress
		lifetime["opacity"] = 1.0 - fade_progress
		_crater_lifetimes[cast_id] = lifetime
		var visual := _permanent_crater_visuals.get(cast_id, null) as Node
		if visual != null and is_instance_valid(visual) and visual.has_method("set_crater_fade_progress"):
			visual.set_crater_fade_progress(fade_progress)
		if elapsed >= duration:
			_remove_expired_crater(cast_id)


func _remove_expired_crater(cast_id: String) -> void:
	var visual := _permanent_crater_visuals.get(cast_id, null) as Node
	if visual != null and is_instance_valid(visual) and visual.has_method("remove_crater"):
		visual.remove_crater()
	_permanent_crater_visuals.erase(cast_id)
	_crater_lifetimes.erase(cast_id)
	if (
		visual != null
		and is_instance_valid(visual)
		and not _landed_meteor_visuals.has(cast_id)
	):
		visual.queue_free()


func _make_ground_flame_particles(index: int) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "GroundFlame%02d" % index
	particles.amount = 12
	particles.lifetime = 0.72 + 0.06 * float(index % 3)
	particles.preprocess = 0.5
	particles.visibility_aabb = AABB(Vector3(-2.0, -0.5, -2.0), Vector3(4.0, 6.0, 4.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.46
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.6
	process.gravity = Vector3(0.0, 0.55, 0.0)
	process.scale_min = 0.65
	process.scale_max = 1.5
	particles.process_material = process
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.02
	flame_mesh.bottom_radius = 0.18
	flame_mesh.height = 0.72
	flame_mesh.radial_segments = 10
	flame_mesh.material = _make_effect_material(
		Color(1.0, 0.12 + 0.035 * float(index % 4), 0.015, 0.78),
		true
	)
	particles.draw_pass_1 = flame_mesh
	return particles


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _failure(error: String, message: String) -> Dictionary:
	return {"ok": false, "error": error, "message": message}
