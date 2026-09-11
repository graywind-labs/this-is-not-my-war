extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const HEALER_ID := "gardener_01"
const TARGET_ID := "cook_01"


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if npc_system == null or action_system == null or resource_system == null or time_system == null or combat_system == null or controller == null or gm_panel == null:
		_fail("Required Main systems are missing")
		return
	time_system.set_paused(false)
	time_system.set_time_scale(0.0)
	controller.debug_set_preview_enabled(true)
	await physics_frame
	controller.force_sync_production_navigation()

	var healer := _get_npc_node(npc_system, HEALER_ID)
	var target := _get_npc_node(npc_system, TARGET_ID)
	if healer == null or target == null:
		_fail("Required production NPC actors are missing")
		return
	healer.move_speed = 8.0
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not create the real post-battle fixture: %s" % spawn_result)
		return
	healer.global_position = Vector3(3.493705, 0.0, 68.8144)
	target.global_position = Vector3(3.670451, 0.0, 70.42204)
	var damage_result: Dictionary = npc_system.debug_damage_npc(TARGET_ID, 9999, "local_public")
	if not bool(damage_result.get("ok", false)):
		_fail("Could not create the unconscious treatment target")
		return
	combat_system.debug_clear_enemies()
	await process_frame
	resource_system.debug_add_resource("money", 10)

	gm_panel.call("_run_assist_heal", HEALER_ID, TARGET_ID)
	var initial_runtime: Dictionary = action_system.get_runtime_action_snapshot(HEALER_ID)
	if str(initial_runtime.get("action_id", "")) != "assist_heal":
		_fail("Initial formal healing command was rejected")
		return
	# Reproduce the observed post-battle race: a stale/non-healing movement label
	# is published between formal-session creation and the deferred route handoff.
	npc_system.update_npc_state(HEALER_ID, {
		"current_action": "moving_to_front_gate",
		"movement_target": "front_gate",
		"movement_target_name": "正门",
	})
	var single_command_route_started := false
	for _handoff_frame in range(6):
		await physics_frame
		var handoff_snapshot: Dictionary = npc_system.get_formal_healing_approach_snapshot(HEALER_ID)
		var handoff_session: Dictionary = handoff_snapshot.get("session", {}) if handoff_snapshot.get("session", {}) is Dictionary else {}
		if bool(handoff_session.get("healing_route_started", false)):
			single_command_route_started = true
			break
	if not single_command_route_started:
		_fail("A single accepted treatment command did not supersede the stale movement: %s" % npc_system.get_formal_healing_approach_snapshot(HEALER_ID))
		return
	await process_frame
	var gm_confirmed_execution := false
	var gm_history: Array = gm_panel.get("_history")
	for raw_entry in gm_history:
		var entry := str(raw_entry)
		if entry.begins_with("真实协助治疗 %s -> %s：成功（" % [HEALER_ID, TARGET_ID]):
			gm_confirmed_execution = true
	if not gm_confirmed_execution:
		_fail("GM did not distinguish a started treatment route from preparatory acceptance: %s" % gm_history)
		return
	if not action_system.debug_assign_heal_assist(HEALER_ID, TARGET_ID, true):
		_fail("Repeated command did not accept the existing pending treatment")
		return

	var route_observed := single_command_route_started
	var active_observed := false
	var diagnostic_timeline: Array[Dictionary] = []
	for frame_index in range(600):
		await physics_frame
		var formal: Dictionary = npc_system.get_formal_healing_approach_snapshot(HEALER_ID)
		var session: Dictionary = formal.get("session", {}) if formal.get("session", {}) is Dictionary else {}
		route_observed = route_observed or bool(session.get("healing_route_started", false))
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(HEALER_ID)
		if frame_index < 12 or frame_index in [20, 40, 80, 160, 320, 599]:
			var healer_state: Dictionary = npc_system.get_npc_state(HEALER_ID)
			diagnostic_timeline.append({
				"frame": frame_index,
				"formal_active": bool(formal.get("active", false)),
				"route_started": bool(session.get("healing_route_started", false)),
				"runtime": runtime,
				"current_action": str(healer_state.get("current_action", "")),
				"movement_target": str(healer_state.get("movement_target", "")),
				"spatial_route_phase": str(healer_state.get("spatial_route_phase", "")),
				"last_action_result": str(healer_state.get("last_action_result", "")),
				"last_action_failure_context": healer_state.get("last_action_failure_context", {}),
				"target_unconscious": bool(npc_system.get_npc_state(TARGET_ID).get("unconscious", false)),
			})
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == "assist_heal":
			active_observed = true
			break
	if not route_observed:
		_fail("Pending healing never started its physical route: formal=%s timeline=%s" % [npc_system.get_formal_healing_approach_snapshot(HEALER_ID), JSON.stringify(diagnostic_timeline)])
		return
	if not active_observed:
		_fail("Healer did not physically reach the casualty after pending handoff: %s" % npc_system.get_formal_healing_approach_snapshot(HEALER_ID))
		return

	var healer_position: Vector3 = npc_system.get_npc_world_position(HEALER_ID)
	var target_position: Vector3 = npc_system.get_npc_world_position(TARGET_ID)
	var distance := Vector2(
		healer_position.x - target_position.x,
		healer_position.z - target_position.z
	).length()
	print("T0258_HEAL_PENDING_HANDOFF_METRICS=%s" % JSON.stringify({
		"route_started": route_observed,
		"active": active_observed,
		"distance": distance,
		"healer_action": npc_system.get_npc_state(HEALER_ID).get("current_action", ""),
	}))
	print("T0258 healing pending handoff verification passed.")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
