extends SceneTree


const UPGRADE_BUILDING_ID := "front_gate"
const REPAIR_BUILDING_ID := "back_gate"
const UPGRADE_HELPERS := ["engineer_01", "doctor_01", "priest_01"]
const REPAIR_HELPERS := ["stableman_01", "gardener_01", "blacksmith_01"]
const HEALING_TARGET_ID := "cook_01"
const HEALING_HELPERS := ["engineer_01", "doctor_01"]
const HEALING_OVERFLOW_ID := "priest_01"

var _action_system: Node
var _building_system: Node
var _npc_system: Node
var _resource_system: Node
var _time_system: Node
var _controller: Node


func _init() -> void:
	var main := preload("res://scenes/main/Main.tscn").instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		# This is a pure movement/authority regression. Never start the eight-NPC
		# planning batch or contact a model provider.
		startup.set("_startup_running", true)
	root.add_child(main)
	await process_frame
	await physics_frame
	_action_system = root.get_node("Main/Systems/ActionSystem")
	_building_system = root.get_node("Main/Systems/BuildingSystem")
	_npc_system = root.get_node("Main/Systems/NPCSystem")
	_resource_system = root.get_node("Main/Systems/ResourceSystem")
	_time_system = root.get_node("Main/Systems/TimeSystem")
	_controller = root.get_node("Main/Presentation/StationLayoutController")
	_time_system.set_time_scale(0.0)
	_time_system.set_paused(false)
	_resource_system.add_resources({"wood": 999, "stone": 999, "iron": 999, "money": 999})
	_controller.debug_set_preview_enabled(true)
	await physics_frame
	await process_frame
	_controller.force_sync_production_navigation()

	if not _verify_all_service_slots_reachable_and_distinct():
		return
	if not await _verify_three_upgrade_helpers():
		return
	if not await _verify_three_repair_helpers():
		return
	if not await _verify_healing_assist_boundary():
		return
	print("T0320 multi-assist movement verification passed.")
	quit(0)


func _verify_all_service_slots_reachable_and_distinct() -> bool:
	var navigation_map: RID = _controller.get_production_navigation_map_rid()
	var station_origin := NavigationServer3D.map_get_closest_point(navigation_map, Vector3.ZERO)
	for raw_building_id in _building_system.get_building_ids():
		var building_id := str(raw_building_id)
		for service_kind in ["repair", "upgrade"]:
			var slots: Array[Dictionary] = _controller.get_building_exterior_service_slots(building_id, service_kind)
			if slots.is_empty():
				_fail("No reachable %s service slot for %s" % [service_kind, building_id])
				return false
			for index in range(slots.size()):
				var position: Variant = slots[index].get("position")
				if not position is Vector3:
					_fail("Invalid %s service position for %s" % [service_kind, building_id])
					return false
				var closest := NavigationServer3D.map_get_closest_point(navigation_map, position)
				if position.distance_to(closest) > 0.01:
					_fail("Off-nav %s service position remains for %s" % [service_kind, building_id])
					return false
				if float(slots[index].get("snap_error", 0.0)) > 0.45:
					_fail("Excessively adjusted %s service position remains for %s" % [service_kind, building_id])
					return false
				var station_path := NavigationServer3D.map_get_path(navigation_map, station_origin, position, true)
				if station_path.size() < 2 and _horizontal_distance(station_origin, position) > 0.25:
					_fail("Disconnected %s service position remains for %s at %s" % [service_kind, building_id, position])
					return false
				for other_index in range(index):
					var other_position: Variant = slots[other_index].get("position")
					if other_position is Vector3 and _horizontal_distance(position, other_position) < 0.9:
						_fail("Collapsed %s service positions remain for %s" % [service_kind, building_id])
						return false
	return true


func _verify_three_upgrade_helpers() -> bool:
	var slots: Array[Dictionary] = _controller.get_building_exterior_service_slots(UPGRADE_BUILDING_ID, "upgrade")
	if slots.size() < 3:
		_fail("Front gate does not expose three distinct reachable upgrade slots")
		return false
	# Occupy the two already-reachable right-hand points first. Before T0320 the
	# third command then reserved the off-map left point and stopped after walking.
	_place_npc_near_slot(UPGRADE_HELPERS[0], slots[1], 13.0)
	_place_npc_near_slot(UPGRADE_HELPERS[1], slots[2], 13.0)
	_place_npc_near_slot(UPGRADE_HELPERS[2], slots[0], 13.0)
	if not _building_system.upgrade_building(UPGRADE_BUILDING_ID):
		_fail("Could not start front-gate upgrade")
		return false
	for index in range(2):
		var npc_id: String = UPGRADE_HELPERS[index]
		if not _action_system.debug_assign_upgrade_assist(npc_id, UPGRADE_BUILDING_ID, true):
			_fail("Could not assign initial upgrade helper %s" % npc_id)
			return false
		if not await _wait_for_building_helper("upgrade", UPGRADE_BUILDING_ID, npc_id, 2400):
			_fail_with_snapshot("Initial upgrade helper failed", npc_id, UPGRADE_BUILDING_ID, "upgrade")
			return false
	var third_id: String = UPGRADE_HELPERS[2]
	var start_position: Variant = _npc_system.get_npc_world_position(third_id)
	if not _action_system.debug_assign_upgrade_assist(third_id, UPGRADE_BUILDING_ID, true):
		_fail("Could not assign third upgrade helper")
		return false
	if not await _wait_for_building_helper("upgrade", UPGRADE_BUILDING_ID, third_id, 2400):
		_fail_with_snapshot("Third upgrade helper stopped in transit", third_id, UPGRADE_BUILDING_ID, "upgrade")
		return false
	var end_position: Variant = _npc_system.get_npc_world_position(third_id)
	var status: Dictionary = _building_system.get_upgrade_status(UPGRADE_BUILDING_ID)
	if (
		not start_position is Vector3
		or not end_position is Vector3
		or start_position.distance_to(end_position) < 3.0
		or int(status.get("helper_count", 0)) != 3
		or float(status.get("speed_multiplier", 1.0)) <= 1.0
	):
		_fail("Third upgrade helper did not complete a real approach and efficiency commit")
		return false
	return true


func _verify_three_repair_helpers() -> bool:
	var slots: Array[Dictionary] = _controller.get_building_exterior_service_slots(REPAIR_BUILDING_ID, "repair")
	var exact_slots: Array[Dictionary] = []
	for slot in slots:
		if float(slot.get("snap_error", 0.0)) <= 0.01:
			exact_slots.append(slot)
	if exact_slots.size() < 3:
		_fail("Back gate does not expose three distinct reachable repair slots")
		return false
	for index in range(3):
		_place_npc_near_slot(REPAIR_HELPERS[index], exact_slots[index], 6.0)
	if not _building_system.debug_damage_building(REPAIR_BUILDING_ID, 50):
		_fail("Could not damage back gate")
		return false
	if not _building_system.repair_building(REPAIR_BUILDING_ID):
		_fail("Could not start back-gate repair")
		return false
	# Commit two helpers first, then issue the third command: this is the same
	# ordering as the reported gate-upgrade bug and also exercises repair through
	# the shared exterior-assistance route.
	for npc_id in REPAIR_HELPERS:
		if not _action_system.debug_assign_repair_assist(npc_id, REPAIR_BUILDING_ID, true):
			_fail("Could not assign repair helper %s" % npc_id)
			return false
		if not await _wait_for_building_helper("repair", REPAIR_BUILDING_ID, npc_id, 2400):
			_fail_with_snapshot("Repair helper stopped in transit", npc_id, REPAIR_BUILDING_ID, "repair")
			return false
	var status: Dictionary = _building_system.get_repair_status(REPAIR_BUILDING_ID)
	if int(status.get("helper_count", 0)) != 3 or float(status.get("speed_multiplier", 1.0)) <= 1.0:
		_fail("Three repair helpers did not commit to the shared repair job")
		return false
	return true


func _verify_healing_assist_boundary() -> bool:
	for npc_id in UPGRADE_HELPERS:
		_action_system.interrupt_npc_action(npc_id, "t0320_prepare_healing", true)
	_place_npc_at_world(HEALING_TARGET_ID, Vector3(0.0, 0.0, 8.0))
	_place_npc_at_world(HEALING_HELPERS[0], Vector3(-7.0, 0.0, 8.0))
	_place_npc_at_world(HEALING_HELPERS[1], Vector3(7.0, 0.0, 8.0))
	_place_npc_at_world(HEALING_OVERFLOW_ID, Vector3(0.0, 0.0, 1.0))
	var damage_result: Dictionary = _npc_system.debug_damage_npc(HEALING_TARGET_ID, 999, "local_public")
	if not bool(damage_result.get("ok", false)):
		_fail("Could not prepare unconscious healing target")
		return false
	for healer_id in HEALING_HELPERS:
		if not _action_system.debug_assign_heal_assist(healer_id, HEALING_TARGET_ID, true):
			_fail("Could not assign healing helper %s" % healer_id)
			return false
	for healer_id in HEALING_HELPERS:
		if not await _wait_for_healing_helper(healer_id, 2400):
			_fail_with_snapshot("Healing helper stopped in transit", healer_id, HEALING_TARGET_ID, "healing")
			return false
	if _action_system.debug_assign_heal_assist(HEALING_OVERFLOW_ID, HEALING_TARGET_ID, true):
		_fail("A third healing helper bypassed the authoritative two-helper limit")
		return false
	if (
		_action_system.has_pending_action(HEALING_OVERFLOW_ID)
		or bool(_npc_system.get_formal_workstation_action_snapshot(HEALING_OVERFLOW_ID).get("active", false))
	):
		_fail("Rejected healing overflow left a movement/session commitment")
		return false
	return true


func _wait_for_building_helper(kind: String, building_id: String, npc_id: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		var status: Dictionary = (
			_building_system.get_upgrade_status(building_id)
			if kind == "upgrade"
			else _building_system.get_repair_status(building_id)
		)
		var helpers: Dictionary = status.get("helpers", {})
		if helpers.has(npc_id):
			return true
		if not _action_system.has_pending_action(npc_id):
			return false
	return false


func _wait_for_healing_helper(healer_id: String, max_frames: int) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		if _action_system.get_healing_helpers_for_target(HEALING_TARGET_ID).has(healer_id):
			return true
		if not _action_system.has_pending_action(healer_id):
			return false
	return false


func _place_npc_near_slot(npc_id: String, slot: Dictionary, distance: float) -> void:
	var position: Variant = slot.get("position")
	var facing: Variant = slot.get("facing_direction")
	if position is Vector3 and facing is Vector3:
		_place_npc_at_world(npc_id, position - facing * distance)


func _place_npc_at_world(npc_id: String, requested_position: Vector3) -> void:
	_npc_system.debug_enter_location_immediately(npc_id, "plaza")
	var navigation_map: RID = _controller.get_production_navigation_map_rid()
	var position := NavigationServer3D.map_get_closest_point(navigation_map, requested_position)
	var actor := _npc_system.get_node_or_null(_npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if actor != null:
		actor.global_position = position


func _fail_with_snapshot(message: String, npc_id: String, target_id: String, kind: String) -> void:
	var target_status: Dictionary = {}
	if kind == "upgrade":
		target_status = _building_system.get_upgrade_status(target_id)
	elif kind == "repair":
		target_status = _building_system.get_repair_status(target_id)
	var world_position: Variant = _npc_system.get_npc_world_position(npc_id)
	var nav_position: Variant = null
	if world_position is Vector3:
		nav_position = NavigationServer3D.map_get_closest_point(
			_controller.get_production_navigation_map_rid(),
			world_position
		)
	_fail("%s: %s" % [message, JSON.stringify({
		"npc_id": npc_id,
		"state": _npc_system.get_npc_state(npc_id),
		"spatial": _npc_system.debug_get_spatial_migration_snapshot(npc_id),
		"runtime": _action_system.get_runtime_action_snapshot(npc_id),
		"world_position": world_position,
		"nav_closest_position": nav_position,
		"nav_snap_distance": world_position.distance_to(nav_position) if world_position is Vector3 and nav_position is Vector3 else -1.0,
		"target_status": target_status,
	})])


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
