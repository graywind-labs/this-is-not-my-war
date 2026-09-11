extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const WORKER_ID := "cook_01"
const HEALER_ID := "doctor_01"
const WORK_ACTION_ID := "work_dining_hall"

var _failures: PackedStringArray = []


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	_check(
		action_system != null
		and npc_system != null
		and equipment_system != null
		and combat_system != null
		and resource_system != null
		and time_system != null
		and controller != null
		and gm_panel != null,
		"T0257 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		_finish({})
		return
	time_system.set_paused(false)
	time_system.set_time_scale(0.0)
	resource_system.add_resources({"money": 999, "grain": 20})
	controller.debug_set_preview_enabled(true)
	await physics_frame
	controller.force_sync_production_navigation()

	var preset_result: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_check(bool(preset_result.get("ok", false)), "One-click combat loadout failed: %s" % preset_result)
	var worker := _get_npc_node(npc_system, WORKER_ID)
	var healer := _get_npc_node(npc_system, HEALER_ID)
	_check(worker != null and healer != null, "Formal worker/healer bodies are missing")
	if not _failures.is_empty():
		_finish({})
		return
	worker.set("move_speed", 8.0)
	healer.set("move_speed", 8.0)
	await process_frame

	# The authoritative loadout remains equipped in work mode, while its combat
	# presentation is stowed. Rallying may reveal it and returning to work hides it.
	var work_idle_art: Dictionary = worker.debug_get_character_art_snapshot()
	_check(str(work_idle_art.get("authority_main_weapon_id", "")) == "sword_shield", "Preset weapon did not reach worker authority")
	_check(not bool(work_idle_art.get("sword_visible", true)) and not bool(work_idle_art.get("shield_visible", true)), "Work mode displayed the equipped sword/shield")
	var rally_result: Dictionary = combat_system.trigger_combat_alarm("t0257_work_presentation")
	_check(bool(rally_result.get("ok", false)), "Could not rally the equipped worker")
	await process_frame
	var rally_art: Dictionary = worker.debug_get_character_art_snapshot()
	_check(bool(rally_art.get("sword_visible", false)) and bool(rally_art.get("shield_visible", false)), "Rally mode did not reveal the equipped sword/shield")
	combat_system.dismiss_combat_rally("t0257_work_presentation")
	await process_frame
	var returned_work_art: Dictionary = worker.debug_get_character_art_snapshot()
	_check(not bool(returned_work_art.get("sword_visible", true)) and not bool(returned_work_art.get("shield_visible", true)), "Returning to work did not stow the sword/shield")

	_check(action_system.debug_assign_action(WORKER_ID, WORK_ACTION_ID, true), "Could not command equipped NPC to cook")
	await process_frame
	var pending_art: Dictionary = worker.debug_get_character_art_snapshot()
	_check(not bool(pending_art.get("sword_visible", true)) and not bool(pending_art.get("shield_visible", true)), "Cooking travel displayed a combat weapon")
	_check(await _wait_for_action(action_system, WORKER_ID, WORK_ACTION_ID, "active"), "Equipped worker did not reach the kitchen")
	await process_frame
	var cooking_art: Dictionary = worker.debug_get_character_art_snapshot()
	_check(bool(cooking_art.get("cook_spoon_visible", false)), "Active cooking did not display its work tool")
	_check(not bool(cooking_art.get("sword_visible", true)) and not bool(cooking_art.get("shield_visible", true)), "Active cooking retained the combat weapon")
	_check(str((equipment_system.get_equipment_snapshot(WORKER_ID).get("main_weapon", {}) as Dictionary).get("id", "")) == "sword_shield", "Stowing presentation incorrectly unequipped the weapon")
	action_system.interrupt_npc_action(WORKER_ID, "t0257_prepare_postbattle", true)
	await process_frame

	# Reproduce the production failure: the casualty's semantic location remains
	# the dining hall while the formal combat body falls on the battlefield.
	worker.global_position = Vector3(-0.5, 0.0, 4.0)
	healer.global_position = Vector3(5.0, 0.0, 4.0)
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn_result.get("ok", false)), "Could not start formal post-battle fixture: %s" % spawn_result)
	var damage_result: Dictionary = npc_system.debug_damage_npc(WORKER_ID, 999, "local_public")
	_check(bool(damage_result.get("ok", false)) and bool(npc_system.get_npc_state(WORKER_ID).get("unconscious", false)), "Could not create a formal battle casualty")
	var fall_position := Vector3(worker.global_position)
	combat_system.debug_clear_enemies()
	await process_frame
	var target_state_after_battle: Dictionary = npc_system.get_npc_state(WORKER_ID)
	_check(worker.global_position.distance_to(fall_position) <= 0.01, "Battle cleanup moved the unconscious body")
	_check(str(target_state_after_battle.get("current_location", "")) == "dining_hall", "Fixture lost the stale semantic location needed for the regression")

	var hp_before := int(target_state_after_battle.get("hp", -1))
	gm_panel.call("_run_assist_heal", HEALER_ID, WORKER_ID)
	await process_frame
	var commanded_runtime: Dictionary = action_system.get_runtime_action_snapshot(HEALER_ID)
	_check(str(commanded_runtime.get("action_id", "")) == "assist_heal", "GM did not dispatch the formal post-battle healing command")
	var heal_snapshot: Dictionary = npc_system.get_formal_healing_approach_snapshot(HEALER_ID)
	var heal_session: Dictionary = heal_snapshot.get("session", {}) if heal_snapshot.get("session", {}) is Dictionary else {}
	_check(bool(heal_session.get("healing_direct_world_route", false)), "Healing did not select the casualty's direct physical route")
	_check(await _wait_for_action(action_system, HEALER_ID, "assist_heal", "active"), "Healer did not reach the post-battle casualty: %s" % npc_system.get_formal_healing_approach_snapshot(HEALER_ID))
	var healer_position := Vector3(healer.global_position)
	var target_position := Vector3(worker.global_position)
	var heal_distance := Vector2(healer_position.x - target_position.x, healer_position.z - target_position.z).length()
	_check(heal_distance >= 0.8 and heal_distance <= 1.7, "Healer did not stop beside the fallen body: %.3f" % heal_distance)
	root.get_node("EventBus").logical_time_tick.emit(3600.0, 1.0)
	await process_frame
	_check(int(npc_system.get_npc_state(WORKER_ID).get("hp", -1)) > hp_before, "Active post-battle healer did not advance recovery")

	_finish({
		"weapon_retained": str((equipment_system.get_equipment_snapshot(WORKER_ID).get("main_weapon", {}) as Dictionary).get("id", "")),
		"cooking_tool_visible": bool(cooking_art.get("cook_spoon_visible", false)),
		"fall_position": fall_position,
		"semantic_location_after_battle": target_state_after_battle.get("current_location", ""),
		"heal_distance": heal_distance,
		"hp_before": hp_before,
		"hp_after": int(npc_system.get_npc_state(WORKER_ID).get("hp", -1)),
	})


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_action(action_system: Node, npc_id: String, action_id: String, phase: String, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		if str(runtime.get("action_id", "")) == action_id and str(runtime.get("phase", "")) == phase:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	print("T0257_POSTBATTLE_HEAL_WORK_PRESENTATION_METRICS=%s" % JSON.stringify(metrics))
	if _failures.is_empty():
		print("T0257 post-battle healing and work presentation verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
