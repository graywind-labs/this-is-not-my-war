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
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if [npc_system, action_system, crafting_system, resource_system, memory_system, time_system].has(null):
		_fail("Required systems not found")
		return
	time_system.set_paused(false)
	var glen := _get_npc_node(npc_system, NPC_ID)
	if glen == null:
		_fail("Glen scene node not found")
		return
	time_system.set_paused(true)
	await process_frame
	time_system.set_paused(false)
	await process_frame
	if not _expect(str(glen.debug_get_character_art_snapshot().get("current_state", "")) == "idle", "AnimationTree did not restore its desired state after gameplay resumed"):
		return
	# Keep this presentation test slow enough to observe the locomotion state
	# between deferred formal-map synchronization and forge arrival.
	glen.set("move_speed", 10.0)

	resource_system.add_resource("iron", 30)
	resource_system.add_resource("wood", 30)
	resource_system.add_resource("stone", 30)
	var target_result: Dictionary = crafting_system.set_target(BUILDING_ID, "craft_iron_helmet", true)
	if not bool(target_result.get("ok", false)):
		_fail("Failed to select blacksmith crafting target")
		return

	var start_position: Vector3 = glen.global_position
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Failed to dispatch blacksmith work")
		return
	if not await _wait_for_movement(glen):
		_fail("Glen never began physical movement: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	var moving_art: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(
		["walk", "run"].has(str(moving_art.get("last_locomotion_state", "")))
		and int(moving_art.get("movement_activation_count", 0)) > 0,
		"Real route did not select a locomotion animation: %s" % JSON.stringify(moving_art)
	):
		return
	if not await _wait_for_action(npc_system, ACTION_ID):
		_fail("Glen did not reach the forge and start work")
		return
	await create_timer(0.18).timeout
	var active_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var active_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	var active_art: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(glen.global_position.distance_to(start_position) > 1.0, "Glen action label changed without physical movement"):
		return
	if not _expect(str(active_state.get("current_location", "")) == BUILDING_ID, "Forge arrival did not commit indoor location"):
		return
	if not _expect(str(active_spatial.get("path_phase", "")) == "active_workstation", "Forge arrival did not commit workstation authority"):
		return
	if not _expect(not (active_spatial.get("occupancy", {}) as Dictionary).is_empty(), "Forge work has no workstation occupancy"):
		return
	if not _expect(_location_has_npc(memory_system, BUILDING_ID, NPC_ID), "Indoor people_present did not mirror the door crossing"):
		return
	if not _expect(str(active_art.get("desired_state", "")) == "work", "Authoritative work action did not select work animation"):
		return
	if not _expect(str(active_art.get("hammer_parent", "")) == "RightHand", "Authoritative work did not move hammer to RightHand"):
		return
	var cycle_before_pause := float(active_art.get("work_cycle_position", -1.0))
	time_system.set_paused(true)
	await process_frame
	await create_timer(0.45).timeout
	var cycle_while_paused := float(glen.debug_get_character_art_snapshot().get("work_cycle_position", -1.0))
	if not _expect(absf(cycle_while_paused - cycle_before_pause) < 0.04, "Gameplay pause did not freeze the work animation cycle"):
		return
	time_system.set_paused(false)
	# GameStartup may finish an asynchronous backend check during this headless fixture and
	# re-apply its startup pause. Keep the fixture explicitly resumed for the observation window.
	for _resume_frame in range(24):
		time_system.set_paused(false)
		await process_frame
	var cycle_after_resume := float(glen.debug_get_character_art_snapshot().get("work_cycle_position", -1.0))
	if not _expect(cycle_after_resume > 0.08, "Work animation cycle did not resume with gameplay: before=%.3f paused=%.3f resumed=%.3f" % [cycle_before_pause, cycle_while_paused, cycle_after_resume]):
		return

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	if not _expect(bool(damage_result.get("ok", false)), "Authoritative damage API failed"):
		return
	await process_frame
	var unconscious_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var unconscious_art: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(bool(unconscious_state.get("unconscious", false)), "Glen did not become authoritatively unconscious"):
		return
	if not _expect(str(unconscious_art.get("desired_state", "")) == "unconscious", "Unconscious authority did not select fall animation"):
		return
	if not _expect((npc_system.debug_get_spatial_migration_snapshot(NPC_ID).get("occupancy", {}) as Dictionary).is_empty(), "Unconscious Glen retained forge occupancy"):
		return

	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	if not _expect(not (recovery_result.get("revived", []) as Array).is_empty(), "Recovery API did not revive Glen: %s" % JSON.stringify(recovery_result)):
		return
	await process_frame
	var revived_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var revived_art: Dictionary = glen.debug_get_character_art_snapshot()
	if not _expect(not bool(revived_state.get("unconscious", true)), "Glen remained authoritatively unconscious after recovery"):
		return
	if not _expect(str(revived_art.get("desired_state", "")) == "get_up", "Revival authority did not select get-up animation"):
		return
	await create_timer(1.35).timeout
	if not _expect(str(glen.debug_get_character_art_snapshot().get("desired_state", "")) == "idle", "Get-up animation did not settle back to idle"):
		return

	print("T0128 character authority integration passed: %s" % JSON.stringify(active_art))
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_movement(glen: Node, max_frames: int = 600) -> bool:
	for _frame in range(max_frames):
		var art: Dictionary = glen.debug_get_character_art_snapshot()
		var motion: Dictionary = glen.debug_get_motion_snapshot()
		# The headless fixture can finish the short indoor route before this
		# coroutine samples its next frame. The activation counter is durable
		# proof that the authoritative route did select locomotion.
		if int(art.get("movement_activation_count", 0)) > 0:
			return true
		if bool(art.get("logical_moving", false)):
			return true
		if bool(motion.get("active", false)):
			# motion_started is emitted inside request_motion, one line before the
			# NPC forwards locomotion to the art view. Let that call stack settle.
			await process_frame
			if bool(glen.debug_get_character_art_snapshot().get("logical_moving", false)):
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
