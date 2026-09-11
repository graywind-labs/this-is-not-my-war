extends SceneTree


const TARGET_ID := "cook_01"
const HEALER_ID := "doctor_01"
const SECOND_HEALER_ID := "engineer_01"
const THIRD_HEALER_ID := "priest_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main scene missing")
		return
	var main := packed.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup.set("_startup_running", true)
	root.add_child(main)
	await process_frame
	await physics_frame
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if action_system == null or npc_system == null or resource_system == null or memory_system == null or time_system == null or controller == null:
		_fail("Required systems missing")
		return
	time_system.set_paused(false)
	time_system.set_time_scale(0.0)
	resource_system.add_resources({"money": 999})
	controller.debug_set_preview_enabled(true)
	await physics_frame
	await process_frame
	controller.force_sync_production_navigation()
	for npc_id in [TARGET_ID, SECOND_HEALER_ID, THIRD_HEALER_ID]:
		if not npc_system.debug_enter_location_immediately(npc_id, "clinic"):
			_fail("Could not prepare NPC location: %s" % npc_id)
			return
	if not npc_system.debug_enter_location_immediately(HEALER_ID, "dormitory"):
		_fail("Could not place healer in another building")
		return
	_set_debug_move_speed(npc_system, HEALER_ID, 8.0)
	_set_debug_move_speed(npc_system, SECOND_HEALER_ID, 8.0)
	_set_debug_move_speed(npc_system, THIRD_HEALER_ID, 8.0)
	var damage_result: Dictionary = npc_system.debug_damage_npc(TARGET_ID, 999, "local_public")
	if not bool(damage_result.get("ok", false)) or not bool(npc_system.get_npc_state(TARGET_ID).get("unconscious", false)):
		_fail("Could not make formal healing target unconscious")
		return
	var money_before := int(resource_system.get_resource("money"))
	var hp_before := int(npc_system.get_npc_state(TARGET_ID).get("hp", -1))
	var healing_started_before := _count_events(memory_system.get_all_events(), "healing_started")
	var healing_completed_before := _count_events(memory_system.get_all_events(), "healing_completed")
	if not action_system.debug_assign_heal_assist(HEALER_ID, TARGET_ID):
		_fail("Could not assign first formal healing helper")
		return
	var first_formal: Dictionary = npc_system.get_formal_healing_approach_snapshot(HEALER_ID)
	var first_session: Dictionary = first_formal.get("session", {}) if first_formal.get("session", {}) is Dictionary else {}
	if (
		not bool(first_formal.get("active", false))
		or str(first_session.get("action_id", "")) != "assist_heal"
		or str(first_session.get("healing_target_npc_id", "")) != TARGET_ID
		or not first_session.get("healing_approach_position") is Vector3
	):
		_fail("First formal healing approach session was not reserved")
		return
	if not action_system.debug_assign_heal_assist(SECOND_HEALER_ID, TARGET_ID):
		_fail("Could not reserve the second healing approach")
		return
	var second_formal: Dictionary = npc_system.get_formal_healing_approach_snapshot(SECOND_HEALER_ID)
	var second_session: Dictionary = second_formal.get("session", {}) if second_formal.get("session", {}) is Dictionary else {}
	var first_position: Variant = first_session.get("healing_approach_position")
	var second_position: Variant = second_session.get("healing_approach_position")
	if (
		not first_position is Vector3
		or not second_position is Vector3
		or Vector2(first_position.x - second_position.x, first_position.z - second_position.z).length() < 0.85
	):
		_fail("Two formal healers did not reserve distinct approach positions")
		return
	if action_system.debug_assign_heal_assist(THIRD_HEALER_ID, TARGET_ID):
		_fail("Third healer was not rejected while two helpers were still in transit")
		return
	action_system.interrupt_npc_action(SECOND_HEALER_ID, "test_second_healing_slot_released", true)
	if bool(npc_system.get_formal_healing_approach_snapshot(SECOND_HEALER_ID).get("active", false)):
		_fail("Stopping a pending healer did not release the formal session")
		return
	if (
		int(resource_system.get_resource("money")) != money_before
		or int(npc_system.get_npc_state(TARGET_ID).get("hp", -1)) != hp_before
		or not action_system.get_healing_helpers_for_target(TARGET_ID).is_empty()
		or _count_events(memory_system.get_all_events(), "healing_started") != healing_started_before
	):
		_fail("Healing facts committed before physical arrival")
		return
	var healer_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(HEALER_ID, NodePath())) as Node3D
	if healer_node == null:
		_fail("Formal healer body missing")
		return
	var pending_healer_art: Dictionary = healer_node.debug_get_character_art_snapshot()
	if (
		str(pending_healer_art.get("desired_state", "")) == "medical_treatment"
		or bool(pending_healer_art.get("medical_book_visible", true))
		or bool(pending_healer_art.get("medical_bandage_visible", true))
		or not bool(pending_healer_art.get("medical_satchel_visible", false))
	):
		_fail("Lina exposed treatment presentation before physical arrival: %s" % JSON.stringify(pending_healer_art))
		return
	var paused_position := healer_node.global_position
	time_system.set_paused(true)
	for frame in range(6):
		await physics_frame
	if healer_node.global_position.distance_to(paused_position) > 0.001:
		_fail("Pending healer moved while gameplay was paused")
		return
	time_system.set_paused(false)
	var arrived := false
	for frame in range(2400):
		await physics_frame
		var healer_state: Dictionary = npc_system.get_npc_state(HEALER_ID)
		if str(healer_state.get("last_action_result", "")) == "assist_heal_started_%s" % TARGET_ID:
			arrived = true
			break
		if (
			int(resource_system.get_resource("money")) != money_before
			or int(npc_system.get_npc_state(TARGET_ID).get("hp", -1)) != hp_before
			or not action_system.get_healing_helpers_for_target(TARGET_ID).is_empty()
			or _count_events(memory_system.get_all_events(), "healing_started") != healing_started_before
		):
			_fail("A healing fact changed while the actor was travelling")
			return
	if not arrived:
		_fail("Healer did not physically reach the unconscious target: formal=%s state=%s runtime=%s" % [JSON.stringify(npc_system.get_formal_healing_approach_snapshot(HEALER_ID)), JSON.stringify(npc_system.get_npc_state(HEALER_ID)), JSON.stringify(action_system.get_runtime_action_snapshot(HEALER_ID))])
		return
	var target_position: Variant = npc_system.get_npc_world_position(TARGET_ID)
	var healer_position: Variant = npc_system.get_npc_world_position(HEALER_ID)
	var arrived_state: Dictionary = npc_system.get_npc_state(HEALER_ID)
	var arrived_art: Dictionary = healer_node.debug_get_character_art_snapshot()
	var horizontal_distance := Vector2(healer_position.x - target_position.x, healer_position.z - target_position.z).length()
	if (
		horizontal_distance < 0.8
		or horizontal_distance > 1.7
		or str(arrived_state.get("physical_location_phase", "")) != "formal_healing_approach"
		or str(arrived_state.get("formal_healing_target_npc_id", "")) != TARGET_ID
		or action_system.get_healing_helpers_for_target(TARGET_ID) != [HEALER_ID]
		or int(resource_system.get_resource("money")) != money_before - 1
		or _count_events(memory_system.get_all_events(), "healing_started") != healing_started_before + 3
	):
		_fail("Physical healing arrival did not atomically commit helper, cost and event: distance=%s state=%s helpers=%s money=%s events=%s" % [str(horizontal_distance), JSON.stringify(arrived_state), JSON.stringify(action_system.get_healing_helpers_for_target(TARGET_ID)), str(resource_system.get_resource("money")), str(_count_events(memory_system.get_all_events(), "healing_started"))])
		return
	if (
		str(arrived_art.get("appearance_id", "")) != "lina_doctor_chibi_v1"
		or str(arrived_art.get("desired_state", "")) != "medical_treatment"
		or str(arrived_art.get("current_clip", "")) != "Working_A"
		or int(arrived_art.get("medical_treatment_clip_loop_mode", Animation.LOOP_NONE)) != Animation.LOOP_LINEAR
		or not bool(arrived_art.get("medical_satchel_visible", false))
		or not bool(arrived_art.get("medical_bandage_visible", false))
		or bool(arrived_art.get("medical_book_visible", true))
	):
		_fail("Physical healing arrival did not activate Lina's looping bandage treatment presentation: %s" % JSON.stringify(arrived_art))
		return
	root.get_node("EventBus").logical_time_tick.emit(3600.0, 1.0)
	await process_frame
	if int(npc_system.get_npc_state(TARGET_ID).get("hp", 0)) <= hp_before:
		_fail("Active formal healer did not advance unconscious recovery")
		return
	root.get_node("EventBus").logical_time_tick.emit(4.0 * 3600.0, 1.0)
	await process_frame
	if bool(npc_system.get_npc_state(TARGET_ID).get("unconscious", true)):
		_fail("Formal assisted healing did not revive the target")
		return
	if (
		bool(npc_system.get_formal_healing_approach_snapshot(HEALER_ID).get("active", false))
		or not action_system.get_healing_helpers_for_target(TARGET_ID).is_empty()
		or str(npc_system.get_npc_state(HEALER_ID).get("last_action_result", "")) != "assist_heal_completed_%s" % TARGET_ID
		or _count_events(memory_system.get_all_events(), "healing_completed") != healing_completed_before + 3
	):
		_fail("Target revival left a helper or formal healing session behind")
		return
	await process_frame
	var completed_art: Dictionary = healer_node.debug_get_character_art_snapshot()
	if bool(completed_art.get("medical_bandage_visible", true)) or str(completed_art.get("desired_state", "")) == "medical_treatment":
		_fail("Lina kept the treatment prop or treatment loop after the patient revived: %s" % JSON.stringify(completed_art))
		return
	var transit_target_id := "stableman_01"
	if not npc_system.debug_enter_location_immediately(transit_target_id, "chapel"):
		_fail("Could not prepare transit-resolution target")
		return
	npc_system.debug_damage_npc(transit_target_id, 999, "local_public")
	var money_before_transit := int(resource_system.get_resource("money"))
	if not action_system.debug_assign_heal_assist(THIRD_HEALER_ID, transit_target_id):
		_fail("Could not start transit-resolution healing route")
		return
	npc_system.debug_advance_unconscious_recovery(transit_target_id, 999999.0)
	await process_frame
	if (
		action_system.has_pending_action(THIRD_HEALER_ID)
		or bool(npc_system.get_formal_healing_approach_snapshot(THIRD_HEALER_ID).get("active", false))
		or int(resource_system.get_resource("money")) != money_before_transit
		or str(npc_system.get_npc_state(THIRD_HEALER_ID).get("last_action_result", "")) != "assist_heal_failed_target_not_unconscious"
	):
		_fail("Target revival during travel left a reservation, charge or formal session")
		return
	print("T0129C A5-P6d-3 formal heal assist verification passed.")
	quit(0)


func _set_debug_move_speed(npc_system: Node, npc_id: String, speed: float) -> void:
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath()))
	if npc_node != null:
		npc_node.move_speed = speed


func _count_events(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
