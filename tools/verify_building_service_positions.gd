extends SceneTree

const MAIN_SCENE := "res://scenes/main/Main.tscn"


func _init() -> void:
	var main_scene := load(MAIN_SCENE) as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await process_frame

	var event_bus := root.get_node_or_null("EventBus")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if (
		event_bus == null
		or building_system == null
		or action_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or memory_system == null
		or llm_bridge == null
	):
		_fail("Required systems are missing")
		return

	if not _verify_initial_positions(building_system, memory_system):
		return
	if not _verify_mass_eligibility(action_system, npc_system, building_system, llm_bridge):
		return
	if not _verify_life_positions_and_dining_upgrade(action_system, npc_system, building_system, resource_system, memory_system):
		return
	if not _verify_clinic_team(action_system, npc_system, building_system, resource_system, event_bus):
		return
	if not _verify_training_team(action_system, npc_system, building_system, resource_system, equipment_system):
		return

	print("T0043 building service positions verification passed.")
	quit(0)


func _verify_initial_positions(building_system: Node, memory_system: Node) -> bool:
	var expectations := {
		"chapel": {"chapel_altar": 1, "chapel_prayer_seat": 10},
		"clinic": {"clinic_doctor_station": 1, "clinic_patient_bed": 2},
		"training_ground": {"training_instructor_station": 1, "training_practice_slot": 2},
		"dining_hall": {"dining_kitchen_station": 1, "dining_seat": 10},
		"dormitory": {"dormitory_bed": 10}
	}
	for building_id in expectations.keys():
		var building: Dictionary = building_system.get_building(str(building_id))
		for station_type in expectations[building_id].keys():
			var expected_count := int(expectations[building_id][station_type])
			var actual_count := _count_type(building.get("workstations", []), str(station_type))
			if actual_count != expected_count:
				_fail("%s %s expected %d positions, got %d" % [building_id, station_type, expected_count, actual_count])
				return false
		for raw_station in building.get("workstations", []):
			if raw_station is Dictionary and str(raw_station.get("name", "")).is_empty():
				_fail("Every configured position needs a player-facing name: %s" % JSON.stringify(raw_station))
				return false

	var chapel_stations: Array = building_system.get_building("chapel").get("workstations", [])
	if str(chapel_stations[0].get("name", "")) != "祭坛" or str(chapel_stations[1].get("name", "")) != "祈祷席1":
		_fail("Chapel positions should preserve altar-first display order")
		return false
	var clinic_snapshot: Dictionary = memory_system.get_location_snapshot("clinic")
	var snapshot_stations: Array = clinic_snapshot.get("workstations", [])
	if snapshot_stations.size() != 3 or str(snapshot_stations[0].get("name", "")) != "诊疗位1":
		_fail("Location snapshot should expose full named position state")
		return false
	return true


func _verify_mass_eligibility(action_system: Node, npc_system: Node, building_system: Node, llm_bridge: Node) -> bool:
	var cook_id := "cook_01"
	var priest_id := "priest_01"
	var cook_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(cook_id, {"requires_time_slowdown": false})
	var priest_payload: Dictionary = llm_bridge.build_npc_daily_plan_payload(priest_id, {"requires_time_slowdown": false})
	var cook_mass := _find_candidate(cook_payload.get("allowed_actions", []), "lead_mass")
	var priest_mass := _find_candidate(priest_payload.get("allowed_actions", []), "lead_mass")
	if cook_mass.is_empty() or priest_mass.is_empty():
		_fail("lead_mass must remain visible in every NPC candidate catalog")
		return false
	var cook_context: Dictionary = cook_mass.get("context", {})
	var priest_context: Dictionary = priest_mass.get("context", {})
	if bool(cook_context.get("eligible", true)) or str(cook_context.get("required_ability", "")) != "主持弥撒":
		_fail("Non-priest mass candidate needs explicit ineligible ability context")
		return false
	if not bool(priest_context.get("eligible", false)):
		_fail("Priest should be eligible to lead Mass")
		return false

	npc_system.debug_enter_location_immediately(cook_id, "chapel")
	if action_system.debug_assign_action(cook_id, "lead_mass"):
		_fail("NPC without Mass ability must be rejected")
		return false
	if not str(npc_system.get_npc_state(cook_id).get("last_action_result", "")).contains("ineligible"):
		_fail("Ineligible Mass execution should produce an explicit failure")
		return false

	npc_system.debug_enter_location_immediately(priest_id, "chapel")
	if not action_system.debug_assign_action(priest_id, "lead_mass"):
		_fail("Eligible priest should be able to claim the altar")
		return false
	if not _is_type_occupied_by(building_system.get_building("chapel").get("workstations", []), "chapel_altar", priest_id):
		_fail("Mass should occupy the altar")
		return false
	action_system.interrupt_npc_action(priest_id, "t0043_mass_checked")

	npc_system.update_npc_state(priest_id, {"escaped": true})
	if not action_system.debug_assign_action(cook_id, "pray_at_chapel"):
		_fail("Ordinary prayer must remain usable after the priest leaves")
		return false
	if not _is_type_occupied_by(building_system.get_building("chapel").get("workstations", []), "chapel_prayer_seat", cook_id):
		_fail("Prayer should occupy a prayer seat, not the altar")
		return false
	action_system.interrupt_npc_action(cook_id, "t0043_prayer_checked")
	return true


func _verify_life_positions_and_dining_upgrade(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	resource_system: Node,
	memory_system: Node
) -> bool:
	for resource_id in ["wood", "stone", "money", "meal", "grain"]:
		resource_system.add_resource(resource_id, 100)
	var claimed_seat_ids: Array[String] = []
	for index in range(10):
		var claimant_id := "capacity_probe_%02d" % (index + 1)
		npc_system._profiles[claimant_id] = {
			"id": claimant_id,
			"name": "容量探针%d" % (index + 1),
			"states": {"current_action": "idle", "current_location": "plaza"}
		}
		var claim: Dictionary = building_system.claim_workstation("dining_hall", claimant_id, "dining_seat")
		if not bool(claim.get("ok", false)):
			_fail("Program should auto-assign every free dining seat")
			return false
		claimed_seat_ids.append(str(claim.get("workstation_id", "")))
	var full_claim: Dictionary = building_system.claim_workstation("dining_hall", "capacity_probe_11", "dining_seat")
	if bool(full_claim.get("ok", false)) or str(full_claim.get("reason", "")) != "no_free_workstation":
		_fail("An exhausted position type should return no_free_workstation")
		return false
	for index in range(claimed_seat_ids.size()):
		building_system.release_workstation(
			"dining_hall",
			"capacity_probe_%02d" % (index + 1),
			claimed_seat_ids[index]
		)
		npc_system._profiles.erase("capacity_probe_%02d" % (index + 1))

	var sleeper_id := "stableman_01"
	npc_system.debug_enter_location_immediately(sleeper_id, "dormitory")
	if not action_system.debug_assign_action(sleeper_id, "sleep_in_dormitory"):
		_fail("Sleep should claim a dormitory bed")
		return false
	if not _is_type_occupied_by(building_system.get_building("dormitory").get("workstations", []), "dormitory_bed", sleeper_id):
		_fail("Sleeping NPC did not occupy a bed")
		return false
	action_system.interrupt_npc_action(sleeper_id, "t0043_sleep_checked", true)
	if _is_occupied_by(building_system.get_building("dormitory").get("workstations", []), sleeper_id):
		_fail("Interrupted sleep should release its bed")
		return false

	var diner_id := "gardener_01"
	npc_system.debug_enter_location_immediately(diner_id, "dining_hall")
	if not action_system.debug_assign_action(diner_id, "eat_at_dining_hall"):
		_fail("Eating should claim a dining seat")
		return false
	var full_duration := float(action_system.get_runtime_action_snapshot(diner_id).get("duration_seconds", 0.0))
	action_system.interrupt_npc_action(diner_id, "t0043_full_efficiency_checked")

	var dining_full_hp := int(building_system.get_building("dining_hall").get("max_hp", 1))
	building_system.debug_damage_building("dining_hall", int(round(float(dining_full_hp) * 0.5)))
	var damaged_efficiency := float(building_system.get_building_activity_efficiency_multiplier("dining_hall", "meal_recovery"))
	if damaged_efficiency >= 1.0:
		_fail("Dining damage should lower recovery efficiency")
		return false
	var propagated_efficiency := float(memory_system.get_location_snapshot("dining_hall").get("operational_efficiency", -1.0))
	if not is_equal_approx(propagated_efficiency, 0.5):
		_fail("Memory should expose the 50% efficiency band instead of exact per-HP efficiency")
		return false
	npc_system.debug_enter_location_immediately(diner_id, "dining_hall")
	if not action_system.debug_assign_action(diner_id, "eat_at_dining_hall"):
		_fail("Damaged but surviving dining hall should remain usable")
		return false
	var damaged_duration := float(action_system.get_runtime_action_snapshot(diner_id).get("duration_seconds", 0.0))
	if damaged_duration <= full_duration:
		_fail("Damage should lengthen the dining recovery cycle")
		return false
	action_system.interrupt_npc_action(diner_id, "t0043_damage_checked")
	building_system.restore_building_hp("dining_hall", dining_full_hp)

	npc_system.debug_enter_location_immediately(diner_id, "dining_hall")
	if not action_system.debug_assign_action(diner_id, "eat_at_dining_hall"):
		_fail("Failed to start dining before upgrade closure check")
		return false
	if not building_system.upgrade_building("dining_hall"):
		_fail("Dining hall upgrade should start")
		return false
	var during_upgrade: Dictionary = building_system.get_building("dining_hall")
	if bool(during_upgrade.get("is_enterable", true)) or str(during_upgrade.get("condition", "")) != "upgrading":
		_fail("Upgrading building must be closed")
		return false
	if _is_occupied_by(during_upgrade.get("workstations", []), diner_id):
		_fail("Upgrade start should release existing positions")
		return false
	if str(npc_system.get_npc_state(diner_id).get("current_location", "")) != "plaza":
		_fail("Upgrade start should evacuate occupants to the plaza")
		return false
	var blocked_claim: Dictionary = building_system.claim_workstation("dining_hall", "debug_diner", "dining_seat")
	if bool(blocked_claim.get("ok", false)) or str(blocked_claim.get("reason", "")) != "building_unavailable":
		_fail("Position claim during upgrade should return building_unavailable")
		return false
	building_system._on_logical_time_tick(100000.0, 1.0)
	var upgraded: Dictionary = building_system.get_building("dining_hall")
	if _count_type(upgraded.get("workstations", []), "dining_seat") != 10:
		_fail("Dining seats must remain fixed at ten after upgrade")
		return false
	if _count_type(upgraded.get("workstations", []), "dining_kitchen_station") != 2:
		_fail("Dining upgrade should add a kitchen station")
		return false
	if float(building_system.get_building_activity_efficiency_multiplier("dining_hall", "meal_recovery")) <= 1.0:
		_fail("Dining upgrade should improve meal recovery efficiency")
		return false
	return true


func _verify_clinic_team(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	resource_system: Node,
	event_bus: Node
) -> bool:
	for resource_id in ["wood", "stone", "money"]:
		resource_system.add_resource(resource_id, 100)
	for target_level in [2, 3]:
		if not building_system.upgrade_building("clinic"):
			_fail("Clinic upgrade to level %d should start" % target_level)
			return false
		building_system._on_logical_time_tick(100000.0, 1.0)
	var clinic: Dictionary = building_system.get_building("clinic")
	if _count_type(clinic.get("workstations", []), "clinic_doctor_station") != 2:
		_fail("Level-three clinic should have two doctor stations")
		return false
	if _count_type(clinic.get("workstations", []), "clinic_patient_bed") != 4:
		_fail("Level-three clinic should have four beds")
		return false

	var doctor_ids := ["doctor_01", "engineer_01"]
	for doctor_id in doctor_ids:
		npc_system.debug_enter_location_immediately(str(doctor_id), "clinic")
		if not action_system.debug_assign_action(str(doctor_id), "work_clinic_doctor"):
			_fail("Both configured clinic positions should accept doctors")
			return false
	var first_rate := float(action_system._get_clinic_hp_per_hour(str(doctor_ids[0])))
	var team_rate := float(action_system.get_clinic_team_hp_per_hour())
	if team_rate <= first_rate:
		_fail("Two active doctors should provide a higher team recovery rate")
		return false

	var patient_ids := ["cook_01", "stableman_01"]
	for patient_id in patient_ids:
		npc_system.update_npc_state(str(patient_id), {"hp": 40, "max_hp": 100, "unconscious": false})
		npc_system.debug_enter_location_immediately(str(patient_id), "clinic")
		if not action_system.debug_assign_action(str(patient_id), "receive_clinic_treatment"):
			_fail("Both clinic beds should accept patients")
			return false
	event_bus.logical_time_tick.emit(1800.0, 1.0)
	for patient_id in patient_ids:
		if int(npc_system.get_npc_state(str(patient_id)).get("hp", 0)) <= 40:
			_fail("The doctor team should heal every occupied bed")
			return false

	var clinic_hp := int(building_system.get_building("clinic").get("max_hp", 1))
	building_system.debug_damage_building("clinic", int(round(float(clinic_hp) * 0.5)))
	var damaged_team_rate := float(action_system.get_clinic_team_hp_per_hour())
	if damaged_team_rate >= team_rate:
		_fail("Clinic damage should reduce the live doctor-team rate")
		return false
	for npc_id in doctor_ids + patient_ids:
		action_system.interrupt_npc_action(str(npc_id), "t0043_clinic_checked", true)
	return true


func _verify_training_team(
	action_system: Node,
	npc_system: Node,
	building_system: Node,
	resource_system: Node,
	equipment_system: Node
) -> bool:
	for resource_id in ["wood", "stone", "item_sword_shield"]:
		resource_system.add_resource(resource_id, 100)
	for target_level in [2, 3]:
		if not building_system.upgrade_building("training_ground"):
			_fail("Training-ground upgrade to level %d should start" % target_level)
			return false
		building_system._on_logical_time_tick(100000.0, 1.0)
	var training_ground: Dictionary = building_system.get_building("training_ground")
	if _count_type(training_ground.get("workstations", []), "training_instructor_station") != 2:
		_fail("Level-three training ground should have two instructor positions")
		return false
	if _count_type(training_ground.get("workstations", []), "training_practice_slot") != 4:
		_fail("Level-three training ground should have four training positions")
		return false

	var instructor_ids := ["stableman_01", "engineer_01"]
	var student_id := "cook_01"
	for npc_id in instructor_ids + [student_id]:
		npc_system.set_npc_recruited(str(npc_id), true)
		var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(str(npc_id), "sword_shield", "private")
		if not bool(equip_result.get("ok", false)):
			_fail("Failed to equip training participant %s: %s" % [npc_id, JSON.stringify(equip_result)])
			return false
	_set_skill(npc_system, str(instructor_ids[0]), "剑盾", 70)
	_set_skill(npc_system, str(instructor_ids[0]), "教练", 50)
	_set_skill(npc_system, str(instructor_ids[1]), "剑盾", 55)
	_set_skill(npc_system, str(instructor_ids[1]), "教练", 35)
	_set_skill(npc_system, student_id, "剑盾", 5)
	for instructor_id in instructor_ids:
		npc_system.debug_enter_location_immediately(str(instructor_id), "training_ground")
		if not action_system.debug_assign_action(str(instructor_id), "work_training_instructor"):
			_fail("Both instructor positions should accept equipped instructors")
			return false
	npc_system.debug_enter_location_immediately(student_id, "training_ground")
	if not action_system.debug_assign_action(student_id, "receive_weapon_training"):
		_fail("Training position should accept equipped student")
		return false
	var student_action: Dictionary = action_system.get_action("receive_weapon_training")
	var one_instructor_interval := float(action_system._get_training_team_skill_interval_seconds(
		[str(instructor_ids[0])], student_id, "剑盾", student_action
	))
	var two_instructor_interval := float(action_system._get_training_team_skill_interval_seconds(
		instructor_ids, student_id, "剑盾", student_action
	))
	if two_instructor_interval >= one_instructor_interval:
		_fail("A second active instructor should shorten the student training interval")
		return false
	var training_hp := int(training_ground.get("max_hp", 1))
	building_system.debug_damage_building("training_ground", int(round(float(training_hp) * 0.5)))
	var damaged_interval := float(action_system._get_training_team_skill_interval_seconds(
		instructor_ids, student_id, "剑盾", student_action
	))
	if damaged_interval <= two_instructor_interval:
		_fail("Training-ground damage should lengthen the live team interval")
		return false
	for npc_id in instructor_ids + [student_id]:
		action_system.interrupt_npc_action(str(npc_id), "t0043_training_checked", true)
	return true


func _find_candidate(raw_candidates: Variant, action_id: String) -> Dictionary:
	if not raw_candidates is Array:
		return {}
	for raw_candidate in raw_candidates:
		if raw_candidate is Dictionary and str(raw_candidate.get("action_id", "")) == action_id:
			return raw_candidate
	return {}


func _count_type(workstations: Array, station_type: String) -> int:
	var count := 0
	for raw_station in workstations:
		if raw_station is Dictionary and str(raw_station.get("type", "")) == station_type:
			count += 1
	return count


func _is_type_occupied_by(workstations: Array, station_type: String, npc_id: String) -> bool:
	for raw_station in workstations:
		if (
			raw_station is Dictionary
			and str(raw_station.get("type", "")) == station_type
			and str(raw_station.get("occupied_by", "")) == npc_id
		):
			return true
	return false


func _is_occupied_by(workstations: Array, npc_id: String) -> bool:
	for raw_station in workstations:
		if raw_station is Dictionary and str(raw_station.get("occupied_by", "")) == npc_id:
			return true
	return false


func _set_skill(npc_system: Node, npc_id: String, skill_name: String, value: int) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills[skill_name] = value
	profile["skills"] = skills
	npc_system._profiles[npc_id] = profile


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
