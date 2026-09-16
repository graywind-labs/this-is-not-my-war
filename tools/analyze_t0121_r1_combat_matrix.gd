extends SceneTree

## T0121-R1 combat-stage sampling harness.
##
## This is an analysis tool, not a gameplay authority. It deliberately uses the
## live Main scene, fixed physics frames, formal combat actors/projectiles, and
## public equipment/device APIs. The near-gate fixture removes the long approach
## so the report can isolate attack timing, physical hit resolution, target
## allocation, and damage-driven attack interruption.
##
## Example:
## godot --headless --fixed-fps 60 --path . \
##   --script res://tools/analyze_t0121_r1_combat_matrix.gd -- \
##   --wave=1 --scenario=tower_only --seed=12101 --seconds=180

const NPC_ORDER: Array[String] = [
	"veteran_deputy_01",
	"cook_01",
	"stableman_01",
	"blacksmith_01",
	"engineer_01",
	"gardener_01",
	"doctor_01",
]

const RECRUIT_BY_WAVE := {
	1: ["veteran_deputy_01", "cook_01"],
	2: ["veteran_deputy_01", "cook_01", "stableman_01"],
	3: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01"],
	4: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01", "gardener_01"],
	5: ["veteran_deputy_01", "cook_01", "stableman_01", "blacksmith_01", "engineer_01", "gardener_01", "doctor_01"],
}

const WEAPON_PLAN := {
	"cook_01": "polearm",
	"stableman_01": "bow",
	"blacksmith_01": "sword_shield",
	"engineer_01": "crossbow",
	"gardener_01": "polearm",
	"doctor_01": "bow",
}

const ARMOR_PLAN := [
	{"wave": 3, "npc_id": "veteran_deputy_01", "armor": "iron_helmet"},
	{"wave": 3, "npc_id": "blacksmith_01", "armor": "iron_helmet"},
	{"wave": 4, "npc_id": "veteran_deputy_01", "armor": "mail_chest"},
	{"wave": 4, "npc_id": "veteran_deputy_01", "armor": "iron_bracers"},
	{"wave": 4, "npc_id": "blacksmith_01", "armor": "iron_bracers"},
	{"wave": 4, "npc_id": "veteran_deputy_01", "armor": "iron_greaves"},
	{"wave": 5, "npc_id": "cook_01", "armor": "iron_helmet"},
	{"wave": 5, "npc_id": "cook_01", "armor": "iron_greaves"},
]

const DEVICE_PLAN := [
	{"wave": 1, "device": "wall_arrow_tower", "slot": "main_hall_slot_03"},
	{"wave": 3, "device": "wall_ballista", "slot": "wall_slot_01"},
	{"wave": 4, "device": "wall_arrow_tower", "slot": "wall_slot_02"},
	{"wave": 5, "device": "wall_arrow_tower", "slot": "main_hall_slot_04"},
]

const STOCK_BY_ITEM := {
	"polearm": "item_polearm",
	"bow": "item_bow",
	"sword_shield": "item_sword_shield",
	"crossbow": "item_crossbow",
	"iron_helmet": "item_iron_helmet",
	"mail_chest": "item_mail_chest",
	"iron_bracers": "item_iron_bracers",
	"iron_greaves": "item_iron_greaves",
	"wall_ballista": "item_wall_ballista",
	"wall_arrow_tower": "item_wall_arrow_tower",
}

var _options := {
	"wave": "1",
	"scenario": "baseline",
	"seed": "12101",
	"seconds": "180",
	"first_tower_slot": "wall_slot_01",
}
var _systems := {}
var _event_counts := {}
var _enemy_damage_by_source := {}
var _friendly_damage_by_target_type := {}
var _enemy_interrupt_max := {}
var _enemy_windup_interrupt_max := {}
var _npc_interrupt_max := {}
var _npc_windup_interrupt_max := {}
var _target_frame_counts := {}
var _device_last_hp := {}
var _device_max_hp := {}
var _device_destroyed := {}
var _first_enemy_damage_frame := -1
var _first_friendly_damage_frame := -1
var _current_frame := 0


func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	_run()


func _run() -> void:
	var wave := clampi(int(_options.wave), 1, 5)
	var scenario := str(_options.scenario)
	seed(int(_options.seed))
	if not scenario in ["baseline", "tower_only", "npc_only", "ada_only", "no_alarm"]:
		_fail("Unknown scenario: %s" % scenario)
		return
	var main := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	main.get_node("Systems/LLMBridge").set("_transport_shutdown_requested", true)
	if not _resolve_systems(main):
		return
	_prepare_isolated_runtime()
	var setup_result := _configure_build(wave, scenario)
	if not bool(setup_result.get("ok", false)):
		_fail("Build setup failed: %s" % JSON.stringify(setup_result))
		return
	var event_bus: Node = _systems.event_bus
	event_bus.combat_audio_event.connect(_on_combat_audio_event)
	_capture_device_hp()

	# The controlled contact fixture is intentionally identical across scenarios.
	# Long-route/alarm timing belongs in the separate end-to-end cohort gate.
	var spawn_result: Dictionary = _systems.combat.debug_spawn_wave(wave, true, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Wave spawn failed: %s" % JSON.stringify(spawn_result))
		return
	if scenario != "no_alarm":
		_activate_combatants(wave, scenario)

	var initial_enemy_count: int = _systems.combat.get_active_enemy_count()
	var max_frames := maxi(60, int(ceil(float(_options.seconds) * 60.0)))
	for frame in range(max_frames):
		_current_frame = frame
		_sample_frame()
		if _systems.combat.get_active_enemy_count() <= 0 or bool(_systems.game_state.get("game_over")):
			break
		await physics_frame
		await process_frame
	_current_frame += 1
	_sample_frame()

	var report := _build_report(wave, scenario, initial_enemy_count)
	var output_dir := "res://artifacts/analysis/t0121_r1"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file_name := "wave%d_%s_%s_seed%s.json" % [
		wave,
		scenario,
		str(_options.first_tower_slot).validate_filename(),
		str(_options.seed).validate_filename(),
	]
	var output_path := "%s/%s" % [output_dir, file_name]
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		_fail("Cannot write analysis report: %s" % output_path)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("T0121_R1_COMBAT_MATRIX %s" % JSON.stringify(report))
	print("T0121_R1_REPORT=%s" % output_path)
	main.queue_free()
	await process_frame
	quit(0)


func _resolve_systems(main: Node) -> bool:
	_systems = {
		"time": main.get_node_or_null("Systems/TimeSystem"),
		"npc": main.get_node_or_null("Systems/NPCSystem"),
		"resource": main.get_node_or_null("Systems/ResourceSystem"),
		"equipment": main.get_node_or_null("Systems/EquipmentSystem"),
		"building": main.get_node_or_null("Systems/BuildingSystem"),
		"device": main.get_node_or_null("Systems/DefenseDeviceSystem"),
		"combat": main.get_node_or_null("Systems/CombatSystem"),
		"daily_plan": main.get_node_or_null("Systems/DailyPlanSystem"),
		"reflection": main.get_node_or_null("Systems/DailyReflectionSystem"),
		"llm": main.get_node_or_null("Systems/LLMBridge"),
		"game_state": root.get_node_or_null("/root/GameState"),
		"event_bus": root.get_node_or_null("/root/EventBus"),
	}
	for system_id in _systems:
		if _systems[system_id] == null:
			_fail("Missing system: %s" % system_id)
			return false
	return true


func _prepare_isolated_runtime() -> void:
	_systems.daily_plan.set_auto_execution_enabled(false)
	_systems.time.set_current_time(1, 12)
	_systems.time.set_time_scale(1.0)
	_systems.time.set_paused(false)


func _configure_build(wave: int, scenario: String) -> Dictionary:
	var include_npcs := scenario in ["baseline", "npc_only", "no_alarm", "ada_only"]
	var include_devices := scenario in ["baseline", "tower_only", "no_alarm"]
	var recruited: Array = ["veteran_deputy_01"] if scenario == "ada_only" else RECRUIT_BY_WAVE[wave]
	if include_npcs:
		for raw_npc_id in recruited:
			var npc_id := str(raw_npc_id)
			if not _systems.npc.set_npc_recruited(npc_id, true):
				return {"ok": false, "reason": "recruit_failed", "npc_id": npc_id}
			if WEAPON_PLAN.has(npc_id):
				var weapon_id := str(WEAPON_PLAN[npc_id])
				_add_stock(STOCK_BY_ITEM[weapon_id], 1)
				var equip_result: Dictionary = _systems.equipment.equip_npc_main_weapon(npc_id, weapon_id, "private")
				if not bool(equip_result.get("ok", false)):
					return {"ok": false, "reason": "weapon_failed", "npc_id": npc_id, "result": equip_result}
		for raw_entry in ARMOR_PLAN:
			var entry: Dictionary = raw_entry
			if int(entry.wave) > wave or not recruited.has(str(entry.npc_id)):
				continue
			var armor_id := str(entry.armor)
			_add_stock(STOCK_BY_ITEM[armor_id], 1)
			var armor_def: Dictionary = _systems.equipment.get_armor_def(armor_id)
			var armor_result: Dictionary = _systems.equipment.equip_npc_armor(str(entry.npc_id), str(armor_def.get("slot", "")), armor_id, "private")
			if not bool(armor_result.get("ok", false)):
				return {"ok": false, "reason": "armor_failed", "npc_id": str(entry.npc_id), "result": armor_result}
	else:
		# Keep every NPC outside the controlled contact contest. This does not alter
		# the formal game's failure rule; it creates the tower-only negative control.
		for raw_npc_id in _systems.npc.get_npc_ids():
			var npc_id := str(raw_npc_id)
			if not _systems.npc.set_npc_recruited(npc_id, false):
				return {"ok": false, "reason": "tower_only_unrecruit_failed", "npc_id": npc_id}
			_systems.npc.set_npc_behavior_mode(npc_id, "avoid", "t0121_r1_device_only", {
				"request_plan_reevaluation": false,
			})
			if bool(_systems.npc.get_npc(npc_id).get("recruited", true)):
				return {"ok": false, "reason": "tower_only_recruit_leak", "npc_id": npc_id}

	if include_devices:
		_set_building_level("wall", 2 if wave >= 4 else 1)
		_set_building_level("main_hall", 3 if wave >= 5 else 1)
		for raw_entry in DEVICE_PLAN:
			var entry: Dictionary = raw_entry
			if int(entry.wave) > wave:
				continue
			var slot_id := str(entry.slot)
			if int(entry.wave) == 1 and wave == 1:
				slot_id = str(_options.first_tower_slot)
			_add_stock(STOCK_BY_ITEM[str(entry.device)], 1)
			var deploy_result: Dictionary = _systems.device.deploy_device(str(entry.device), slot_id)
			if not bool(deploy_result.get("ok", false)):
				return {"ok": false, "reason": "deploy_failed", "entry": entry, "slot_id": slot_id, "result": deploy_result}
	return {"ok": true}


func _activate_combatants(wave: int, scenario: String) -> void:
	if scenario == "tower_only":
		return
	var recruited: Array = ["veteran_deputy_01"] if scenario == "ada_only" else RECRUIT_BY_WAVE[wave]
	var formation_anchor := Vector3(0.0, 0.0, 16.2)
	var outward := Vector3(0.0, 0.0, 1.0)
	var first_slot: Dictionary = _systems.device.get_slot(str(_options.first_tower_slot))
	var slot_position: Dictionary = first_slot.get("position", {}) if first_slot.get("position", {}) is Dictionary else {}
	var slot_facing: Dictionary = first_slot.get("facing_direction", {}) if first_slot.get("facing_direction", {}) is Dictionary else {}
	if not slot_position.is_empty():
		formation_anchor = _vector3_from_dict(slot_position)
		formation_anchor.y = 0.0
	if not slot_facing.is_empty():
		outward = _vector3_from_dict(slot_facing).normalized()
	var tangent := Vector3(outward.z, 0.0, -outward.x).normalized()
	var melee_count := 0
	var ranged_count := 0
	for raw_npc_id in recruited:
		var unit_type := str(_systems.equipment.get_npc_unit_type(str(raw_npc_id)))
		if unit_type in ["archer", "crossbowman", "mounted_ranged"]:
			ranged_count += 1
		else:
			melee_count += 1
	var front_index := 0
	var back_index := 0
	for raw_npc_id in recruited:
		var npc_id := str(raw_npc_id)
		var unit_type := str(_systems.equipment.get_npc_unit_type(npc_id))
		var ranged := unit_type in ["archer", "crossbowman", "mounted_ranged"]
		var lane_index := back_index if ranged else front_index
		var lane_count := ranged_count if ranged else melee_count
		var lateral := (float(lane_index) - float(lane_count - 1) * 0.5) * 2.1
		var position := formation_anchor + tangent * lateral + outward * (-2.4 if ranged else 2.0)
		position.y = 0.0
		if ranged:
			back_index += 1
		else:
			front_index += 1
		_set_npc_world_position(npc_id, position)
		_systems.combat.set_npc_combat_strategy(npc_id, "attack", "private", "t0121_r1_combat_matrix")
		_systems.npc.set_npc_behavior_mode(npc_id, "combat", "t0121_r1_combat_matrix", {
			"state_changes": {"current_action": "combat_ready", "combat_attack_cooldown": 0.0},
			"request_plan_reevaluation": false,
		})


func _sample_frame() -> void:
	for raw_enemy_id in _systems.combat.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		var enemy: Dictionary = _systems.combat.get_enemy(enemy_id)
		_enemy_interrupt_max[enemy_id] = maxi(int(_enemy_interrupt_max.get(enemy_id, 0)), int(enemy.get("damage_attack_interrupt_count", 0)))
		_enemy_windup_interrupt_max[enemy_id] = maxi(int(_enemy_windup_interrupt_max.get(enemy_id, 0)), int(enemy.get("damage_windup_interrupt_count", 0)))
		var target: Dictionary = enemy.get("target", {}) if enemy.get("target", {}) is Dictionary else {}
		var target_key := str(target.get("type", "none"))
		_target_frame_counts[target_key] = int(_target_frame_counts.get(target_key, 0)) + 1
	for raw_npc_id in _systems.npc.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var state: Dictionary = _systems.npc.get_npc_state(npc_id)
		_npc_interrupt_max[npc_id] = maxi(int(_npc_interrupt_max.get(npc_id, 0)), int(state.get("combat_damage_attack_interrupt_count", 0)))
		_npc_windup_interrupt_max[npc_id] = maxi(int(_npc_windup_interrupt_max.get(npc_id, 0)), int(state.get("combat_damage_windup_interrupt_count", 0)))
	_capture_device_hp()


func _capture_device_hp() -> void:
	for raw_deployment in _systems.device.get_deployments():
		var deployment: Dictionary = raw_deployment
		var deployment_id := str(deployment.get("deployment_id", deployment.get("id", "")))
		if deployment_id.is_empty():
			continue
		_device_last_hp[deployment_id] = int(deployment.get("hp", 0))
		_device_max_hp[deployment_id] = int(deployment.get("max_hp", 0))


func _on_combat_audio_event(event: Dictionary) -> void:
	var event_type := str(event.get("event_type", ""))
	_event_counts[event_type] = int(_event_counts.get(event_type, 0)) + 1
	if event_type == "actor_damaged" and str(event.get("target_type", "")) == "enemy":
		var source_type := str(event.get("source_type", "unknown"))
		_enemy_damage_by_source[source_type] = int(_enemy_damage_by_source.get(source_type, 0)) + int(event.get("damage", 0))
		if _first_enemy_damage_frame < 0:
			_first_enemy_damage_frame = _current_frame
	elif event_type in ["actor_damaged", "structure_damaged"]:
		var target_type := str(event.get("target_type", "unknown"))
		_friendly_damage_by_target_type[target_type] = int(_friendly_damage_by_target_type.get(target_type, 0)) + int(event.get("damage", 0))
		if target_type == "defense_device":
			var deployment_id := str(event.get("target_id", ""))
			_device_last_hp[deployment_id] = int(event.get("hp_after", 0))
			_device_destroyed[deployment_id] = bool(event.get("destroyed", false))
		if _first_friendly_damage_frame < 0:
			_first_friendly_damage_frame = _current_frame


func _build_report(wave: int, scenario: String, initial_enemy_count: int) -> Dictionary:
	var npc_end := {}
	var conscious_count := 0
	var total_npc_missing_hp := 0
	for raw_npc_id in _systems.npc.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var profile: Dictionary = _systems.npc.get_npc(npc_id)
		var state: Dictionary = _systems.npc.get_npc_state(npc_id)
		if not bool(profile.get("recruited", false)):
			continue
		var hp := int(state.get("hp", profile.get("hp", 0)))
		var max_hp := int(state.get("max_hp", profile.get("max_hp", 0)))
		var unconscious := bool(state.get("unconscious", false))
		if not unconscious:
			conscious_count += 1
		total_npc_missing_hp += maxi(0, max_hp - hp)
		npc_end[npc_id] = {"hp": hp, "max_hp": max_hp, "unconscious": unconscious}
	var building_end := {}
	var minimum_building_ratio := 1.0
	for building_id in ["front_gate", "wall", "warehouse", "main_hall"]:
		var building: Dictionary = _systems.building.get_building(building_id)
		var hp := int(building.get("hp", 0))
		var max_hp := maxi(1, int(building.get("max_hp", 1)))
		building_end[building_id] = {"hp": hp, "max_hp": max_hp}
		minimum_building_ratio = minf(minimum_building_ratio, float(hp) / float(max_hp))
	var devices := {}
	var device_missing_hp := 0
	for deployment_id in _device_max_hp:
		var max_hp := int(_device_max_hp[deployment_id])
		var hp := int(_device_last_hp.get(deployment_id, 0))
		device_missing_hp += maxi(0, max_hp - hp)
		devices[deployment_id] = {"hp": hp, "max_hp": max_hp, "destroyed": bool(_device_destroyed.get(deployment_id, hp <= 0))}
	var target_total_frames := 0
	for count in _target_frame_counts.values():
		target_total_frames += int(count)
	var target_share := {}
	for target_type in _target_frame_counts:
		target_share[target_type] = snappedf(float(_target_frame_counts[target_type]) / float(maxi(1, target_total_frames)), 0.0001)
	var total_enemy_damage := 0
	for damage in _enemy_damage_by_source.values():
		total_enemy_damage += int(damage)
	var device_damage := int(_enemy_damage_by_source.get("defense_device", 0))
	var result := "timeout"
	if _systems.combat.get_active_enemy_count() == 0:
		result = "cleared"
	elif bool(_systems.game_state.get("game_over")):
		result = str(_systems.game_state.get("game_result"))
	return {
		"task": "T0121-R1",
		"fixture": "live_main_near_gate_fixed_physics",
		"wave": wave,
		"scenario": scenario,
		"first_tower_slot": str(_options.first_tower_slot),
		"seed": int(_options.seed),
		"max_seconds": float(_options.seconds),
		"result": result,
		"elapsed_seconds": snappedf(float(_current_frame) / 60.0, 0.01),
		"initial_enemy_count": initial_enemy_count,
		"remaining_enemy_count": _systems.combat.get_active_enemy_count(),
		"enemy_defeated_count": initial_enemy_count - _systems.combat.get_active_enemy_count(),
		"first_enemy_damage_seconds": -1.0 if _first_enemy_damage_frame < 0 else snappedf(float(_first_enemy_damage_frame) / 60.0, 0.01),
		"first_friendly_damage_seconds": -1.0 if _first_friendly_damage_frame < 0 else snappedf(float(_first_friendly_damage_frame) / 60.0, 0.01),
		"enemy_damage_by_source": _enemy_damage_by_source.duplicate(true),
		"device_damage_share": snappedf(float(device_damage) / float(maxi(1, total_enemy_damage)), 0.0001),
		"friendly_damage_by_target_type": _friendly_damage_by_target_type.duplicate(true),
		"enemy_attack_interrupts": _sum_values(_enemy_interrupt_max),
		"enemy_windup_interrupts": _sum_values(_enemy_windup_interrupt_max),
		"npc_attack_interrupts": _sum_values(_npc_interrupt_max),
		"npc_windup_interrupts": _sum_values(_npc_windup_interrupt_max),
		"enemy_target_time_share": target_share,
		"npc_end": npc_end,
		"conscious_count": conscious_count,
		"total_npc_missing_hp": total_npc_missing_hp,
		"device_end": devices,
		"total_device_missing_hp": device_missing_hp,
		"building_end": building_end,
		"minimum_building_hp_ratio": snappedf(minimum_building_ratio, 0.0001),
		"combat_events": _event_counts.duplicate(true),
		"game_result": str(_systems.game_state.get("game_result")),
		"game_over_reason": str(_systems.game_state.get("game_over_reason")),
	}


func _sum_values(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func _add_stock(resource_id: String, amount: int) -> void:
	_systems.resource.add_resource(resource_id, amount)


func _set_building_level(building_id: String, level: int) -> void:
	var buildings: Dictionary = _systems.building.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	_systems.building.set("_buildings", buildings)


func _set_npc_world_position(npc_id: String, position: Vector3) -> void:
	var npc_paths: Dictionary = _systems.npc.get("_npc_nodes")
	var npc_node := _systems.npc.get_node_or_null(npc_paths.get(npc_id, NodePath(""))) as Node3D
	if npc_node != null:
		npc_node.global_position = position


func _vector3_from_dict(value: Dictionary) -> Vector3:
	return Vector3(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("z", 0.0))
	)


func _fail(message: String) -> void:
	push_error("T0121-R1: %s" % message)
	quit(1)
