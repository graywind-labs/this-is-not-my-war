extends SceneTree

const NPC_ID := "blacksmith_01"
const BUILDING_ID := "blacksmith"
const ACTION_ID := "work_blacksmith"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if [npc_system, action_system, building_system, crafting_system, resource_system, memory_system, time_system].has(null):
		_fail("Required systems not found")
		return
	time_system.set_paused(false)
	var art_view := root.get_node_or_null("Main/WorldRoot/Station/Buildings/BlacksmithArtView")
	var click_area := root.get_node_or_null("Main/WorldRoot/Station/Buildings/BlacksmithArtView/ClickArea")
	if art_view == null or click_area == null or str(click_area.get_meta("building_id", "")) != BUILDING_ID:
		_fail("Blacksmith BuildingArtView or unified click metadata is missing")
		return
	var route_contract: Dictionary = building_system.get_building_interior_route(BUILDING_ID, "forge_01")
	for required_key in ["entry_outside_position", "exit_outside_position", "door_inside_position", "interior_target_position"]:
		if not route_contract.has(required_key) or not route_contract[required_key] is Vector3:
			_fail("Blacksmith route contract is missing: %s" % required_key)
			return

	_set_move_speed(npc_system, 40.0)
	resource_system.add_resource("iron", 30)
	resource_system.add_resource("wood", 30)
	resource_system.add_resource("stone", 30)
	var target_result: Dictionary = crafting_system.set_target(BUILDING_ID, "craft_iron_helmet", true)
	if not bool(target_result.get("ok", false)):
		_fail("Failed to select blacksmith crafting target")
		return

	# Normal authority migration: reserve outside, enter at the door, occupy only at the forge.
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch spatial blacksmith work")
		return
	var outside: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect(str(outside.get("logical_location_id", "")) == "plaza", "Outside travel committed indoor location too early"):
		return
	if not _expect(not (outside.get("reservation", {}) as Dictionary).is_empty(), "Outside travel did not reserve a forge"):
		return
	if not _expect((outside.get("occupancy", {}) as Dictionary).is_empty(), "Outside travel occupied a forge before arrival"):
		return
	if not _expect(not _location_has_npc(memory_system, BUILDING_ID, NPC_ID), "Blacksmith people_present changed before door crossing"):
		return

	if not await _wait_for_phase(npc_system, "moving_to_workstation"):
		_fail("NPC never crossed the blacksmith door")
		return
	var inside: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect(str(inside.get("logical_location_id", "")) == BUILDING_ID, "Door crossing did not commit blacksmith location"):
		return
	if not _expect(_location_has_npc(memory_system, BUILDING_ID, NPC_ID), "Door crossing did not update people_present"):
		return
	if not _expect(not (inside.get("reservation", {}) as Dictionary).is_empty(), "Inside path lost forge reservation"):
		return
	if not _expect((inside.get("occupancy", {}) as Dictionary).is_empty(), "Inside path occupied forge before marker arrival"):
		return

	if not await _wait_for_action(npc_system, ACTION_ID):
		_fail("Blacksmith work did not start at forge arrival")
		return
	var active: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect(str(active.get("path_phase", "")) == "active_workstation", "Active work lacks workstation phase"):
		return
	if not _expect((active.get("reservation", {}) as Dictionary).is_empty(), "Forge reservation survived commit"):
		return
	if not _expect(not (active.get("occupancy", {}) as Dictionary).is_empty(), "Forge arrival did not commit occupancy"):
		return
	action_system.interrupt_npc_action(NPC_ID, "t0127_active_interrupt", true)
	await process_frame
	var restored_after_active: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect((restored_after_active.get("occupancy", {}) as Dictionary).is_empty(), "Active interruption left ghost occupancy"):
		return
	if not _expect(str(restored_after_active.get("logical_location_id", "")) == "plaza", "Formal interruption did not restore the pre-session logical location"):
		return
	if not _expect(str(restored_after_active.get("physical_location_phase", "")) == "legacy_location", "Formal interruption did not restore legacy spatial authority"):
		return

	# Interrupt before the door: reservation must disappear without an indoor location claim.
	npc_system.debug_enter_location_immediately(NPC_ID, "plaza")
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch pre-door interruption scenario")
		return
	action_system.interrupt_npc_action(NPC_ID, "t0127_pre_door_interrupt", true)
	await process_frame
	var pre_door_interrupt: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect((pre_door_interrupt.get("reservation", {}) as Dictionary).is_empty(), "Pre-door interruption left ghost reservation"):
		return
	if not _expect(str(pre_door_interrupt.get("logical_location_id", "")) == "plaza", "Pre-door interruption claimed indoor location"):
		return

	# Interrupt after crossing the door: formal staging restores the pre-session
	# legacy world atomically.
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch inside interruption scenario")
		return
	if not await _wait_for_phase(npc_system, "moving_to_workstation"):
		_fail("Inside interruption scenario never crossed the door")
		return
	action_system.interrupt_npc_action(NPC_ID, "t0127_inside_interrupt", true)
	await process_frame
	var reversing: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect(str(reversing.get("logical_location_id", "")) == "plaza", "Inside interruption did not restore the pre-session plaza"):
		return
	if not _expect((reversing.get("reservation", {}) as Dictionary).is_empty(), "Inside interruption left ghost reservation"):
		return
	if not _expect(str(reversing.get("physical_location_phase", "")) == "legacy_location", "Inside interruption retained formal-world authority"):
		return

	# Incapacitation releases the pending forge and restores pre-session authority.
	npc_system.debug_enter_location_immediately(NPC_ID, "plaza")
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch incapacitation scenario")
		return
	if not await _wait_for_phase(npc_system, "moving_to_workstation"):
		_fail("Incapacitation scenario never crossed the door")
		return
	npc_system.debug_damage_npc(NPC_ID, 9999)
	await process_frame
	var incapacitated: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect((incapacitated.get("reservation", {}) as Dictionary).is_empty(), "Incapacitation left ghost reservation"):
		return
	if not _expect((incapacitated.get("occupancy", {}) as Dictionary).is_empty(), "Incapacitation created ghost occupancy"):
		return
	if not _expect(str(incapacitated.get("logical_location_id", "")) == "plaza", "Incapacitation did not restore the pre-session location"):
		return

	# Fresh instance for the arrival-time upgrade rejection contract.
	main.queue_free()
	await process_frame
	main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	npc_system = root.get_node("Main/Systems/NPCSystem")
	action_system = root.get_node("Main/Systems/ActionSystem")
	building_system = root.get_node("Main/Systems/BuildingSystem")
	crafting_system = root.get_node("Main/Systems/CraftingSystem")
	resource_system = root.get_node("Main/Systems/ResourceSystem")
	root.get_node("Main/Systems/TimeSystem").set_paused(false)
	_set_move_speed(npc_system, 40.0)
	resource_system.add_resource("iron", 30)
	resource_system.add_resource("wood", 30)
	resource_system.add_resource("stone", 30)
	crafting_system.set_target(BUILDING_ID, "craft_iron_helmet", true)
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch upgrade rejection scenario")
		return
	if not building_system.upgrade_building(BUILDING_ID):
		_fail("Failed to begin blacksmith upgrade")
		return
	if not await _wait_for_result(npc_system, "work_blacksmith_failed_building_upgrading"):
		_fail("Upgrade was not rejected at the blacksmith door: state=%s spatial=%s" % [
			JSON.stringify(npc_system.get_npc_state(NPC_ID)),
			JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID))
		])
		return
	var rejected: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect((rejected.get("reservation", {}) as Dictionary).is_empty(), "Upgrade rejection left ghost reservation"):
		return
	if not _expect((rejected.get("occupancy", {}) as Dictionary).is_empty(), "Upgrade rejection created occupancy"):
		return
	if not _expect(str(rejected.get("logical_location_id", "")) == "plaza", "Upgrade rejection committed indoor location"):
		return

	# Upgrade after the door: pending work fails, reservation clears, and the
	# reversible formal session restores the legacy world.
	main.queue_free()
	await process_frame
	main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	npc_system = root.get_node("Main/Systems/NPCSystem")
	action_system = root.get_node("Main/Systems/ActionSystem")
	building_system = root.get_node("Main/Systems/BuildingSystem")
	crafting_system = root.get_node("Main/Systems/CraftingSystem")
	resource_system = root.get_node("Main/Systems/ResourceSystem")
	root.get_node("Main/Systems/TimeSystem").set_paused(false)
	_set_move_speed(npc_system, 40.0)
	resource_system.add_resource("iron", 30)
	resource_system.add_resource("wood", 30)
	resource_system.add_resource("stone", 30)
	crafting_system.set_target(BUILDING_ID, "craft_iron_helmet", true)
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch inside-upgrade scenario")
		return
	if not await _wait_for_phase(npc_system, "moving_to_workstation"):
		_fail("Inside-upgrade scenario never crossed the door")
		return
	if not building_system.upgrade_building(BUILDING_ID):
		_fail("Failed to begin inside-upgrade scenario")
		return
	var upgrade_evicting: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect((upgrade_evicting.get("reservation", {}) as Dictionary).is_empty(), "Inside upgrade left ghost reservation"):
		return
	if not _expect(str(upgrade_evicting.get("logical_location_id", "")) == "plaza", "Inside upgrade did not restore the pre-session plaza: %s" % JSON.stringify(upgrade_evicting)):
		return
	if not _expect(str(npc_system.get_npc_state(NPC_ID).get("last_action_result", "")) == "work_blacksmith_failed_building_upgrading", "Inside upgrade lost authoritative action failure: %s" % JSON.stringify(npc_system.get_npc_state(NPC_ID))):
		return
	if not _expect(str(upgrade_evicting.get("physical_location_phase", "")) == "legacy_location", "Inside upgrade retained formal-world authority"):
		return

	print("T0127 blacksmith interior authority verification passed.")
	quit(0)


func _set_move_speed(npc_system: Node, speed: float) -> void:
	for npc_id in npc_system.get_npc_ids():
		var node_path: Variant = npc_system.get("_npc_nodes").get(npc_id)
		var npc_node := npc_system.get_node_or_null(node_path)
		if npc_node != null:
			npc_node.set("move_speed", speed)


func _wait_for_phase(npc_system: Node, phase: String, max_frames: int = 600) -> bool:
	for _frame in range(max_frames):
		if str(npc_system.debug_get_spatial_migration_snapshot(NPC_ID).get("path_phase", "")) == phase:
			return true
		await physics_frame
		await process_frame
	return false


func _wait_for_action(npc_system: Node, action_id: String, max_frames: int = 600) -> bool:
	for _frame in range(max_frames):
		if str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_id:
			return true
		await physics_frame
		await process_frame
	return false


func _wait_for_location(npc_system: Node, location_id: String, max_frames: int = 600) -> bool:
	for _frame in range(max_frames):
		if str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) == location_id:
			return true
		await physics_frame
		await process_frame
	return false


func _wait_for_result(npc_system: Node, result_id: String, max_frames: int = 600) -> bool:
	for _frame in range(max_frames):
		if str(npc_system.get_npc_state(NPC_ID).get("last_action_result", "")) == result_id:
			return true
		await physics_frame
		await process_frame
	return false


func _location_has_npc(memory_system: Node, location_id: String, npc_id: String) -> bool:
	var snapshot: Dictionary = memory_system.get_location_snapshot(location_id)
	return (snapshot.get("people_present", []) as Array).has(npc_id)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
