extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const FRAME_SECONDS := 1.0 / 60.0
const PRESSURE_FRAMES := 480
const RECOVERY_FRAMES := 360

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(5):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and npc_system != null and equipment_system != null, "T0193 combat systems missing")
	_check(resource_system != null and time_system != null and event_bus != null, "T0193 world systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	resource_system.add_resource("item_sword_shield", 1)
	_check(bool(equipment_system.equip_npc_main_weapon(NPC_ID, "sword_shield", "private").get("ok", false)), "T0193 failed to arm Ada")
	combat_system.set_npc_combat_strategy(NPC_ID, "attack", "private")
	npc_system.set_npc_recruited(NPC_ID, true)
	var spawned: Dictionary = combat_system.spawn_wave(1, false, "verify_t0193_formal_save_runtime")
	_check(bool(spawned.get("ok", false)), "T0193 failed to spawn production wave: %s" % spawned)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0193 production enemy missing")
	if enemy_ids.is_empty():
		_finish()
		return
	var enemy_id := enemy_ids[0]
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])

	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var ada := npc_system.get_node_or_null(npc_paths.get(NPC_ID, NodePath())) as ActorMotionBody
	var enemy_actor := combat_system.get_node_or_null(
		combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())
	) as ActorMotionBody
	_check(ada != null and enemy_actor != null, "T0193 production actors missing")
	if ada == null or enemy_actor == null:
		_finish()
		return

	ada.cancel_motion("t0193_fixture")
	enemy_actor.cancel_motion("t0193_fixture")
	ada.global_position = Vector3(0.0, 0.2, 20.0)
	enemy_actor.global_position = ada.global_position + Vector3(0.0, 0.0, 1.08)
	ada.velocity = Vector3.ZERO
	enemy_actor.velocity = Vector3.ZERO
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = enemy_actor.global_position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["stagger_remaining"] = 10000.0
	enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(enemy)
	combat_system._active_enemies[enemy_id] = enemy
	combat_system._set_formal_enemy_tactical_motion_paused(enemy_id, true)
	combat_system._refresh_enemy_node(enemy_id)
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0193_friendly_cadence", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0,
			"combat_attack_sequence": 0,
			"combat_attack_last_sequence_time": -1.0,
			"combat_attack_next_sequence_time": 0.0,
			"combat_attack_sequence_lock_remaining": 0.0,
		},
		"request_plan_reevaluation": false,
	})

	var context: Dictionary = combat_system._calculate_npc_attack_context(
		NPC_ID,
		npc_system.get_npc(NPC_ID),
		npc_system.get_npc_state(NPC_ID)
	)
	var expected_cycle := float(context.get("attack_interval", 0.0))
	_check(expected_cycle > 0.0, "T0193 friendly production cycle missing: %s" % context)

	# Manual authoritative stepping prevents the regular logical tick from racing
	# this deterministic 0.2-second cancel/re-entry pressure fixture.
	var combat_tick := Callable(combat_system, "_on_logical_time_tick")
	if event_bus.logical_time_tick.is_connected(combat_tick):
		event_bus.logical_time_tick.disconnect(combat_tick)
	var sequence_starts: Array[float] = []
	var previous_sequence := 0
	var same_sequence_rewinds := 0
	var previous_visual_sequence := -1
	var previous_visual_position := -1.0
	var previous_visual_state := ""
	var previous_visual_clip := ""
	var save_probe := {}
	var enemy_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	time_system.set_paused(false)
	for frame in range(PRESSURE_FRAMES + RECOVERY_FRAMES):
		combat_system._advance_combat_ai(FRAME_SECONDS, false)
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var sequence := int(state.get("combat_attack_sequence", 0))
		if sequence > previous_sequence:
			sequence_starts.append(float(frame) * FRAME_SECONDS)
			previous_sequence = sequence
		# Exercise the real behavior-mode reset path once while the monotonic lock
		# is active. Legacy cooldown fields are cleared, but the next start time is
		# intentionally retained across the immediate combat re-entry.
		if frame == 15:
			npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0193_short_mode_interrupt", {
				"request_plan_reevaluation": false,
			})
			npc_system.set_npc_behavior_mode(NPC_ID, "combat", "t0193_short_mode_reentry", {
				"state_changes": {"current_action": "combat_ready", "combat_target_enemy_id": enemy_id},
				"request_plan_reevaluation": false,
			})
		# Reproduce the original enemy failure mode on the friendly authority:
		# every 0.2 seconds discard the current phase and re-enter combat-ready.
		# The monotonic next-sequence timestamp deliberately remains untouched.
		if frame < PRESSURE_FRAMES and frame % 12 == 3:
			combat_system._active_melee_swings.erase(combat_system._melee_swing_key("friendly", NPC_ID))
			npc_system.update_npc_state(NPC_ID, {
				"combat_attack_cooldown": 0.0,
				"combat_attack_target_enemy_id": "",
				"combat_attack_phase": "idle",
				"combat_attack_elapsed_seconds": 0.0,
				"combat_attack_cycle_seconds": 0.0,
				"combat_attack_impact_seconds": 0.0,
				"combat_attack_impact_committed": false,
				"current_action": "combat_ready",
			})
		var art: Dictionary = ada.debug_get_character_art_snapshot()
		var visual_sequence := int(art.get("combat_attack_sequence", -1))
		var visual_state := str(art.get("current_state", ""))
		var visual_clip := str(art.get("current_clip", ""))
		var visual_position := float(art.get("combat_attack_animation_position", -1.0))
		var visual_sequence_changed := visual_sequence != previous_visual_sequence
		if (
			visual_state in ["attack", "mounted_attack"]
			and previous_visual_state == visual_state
			and visual_clip == previous_visual_clip
			and not visual_sequence_changed
			and visual_position >= 0.0
			and previous_visual_position >= 0.0
			and visual_position + 0.02 < previous_visual_position
		):
			same_sequence_rewinds += 1
		previous_visual_sequence = visual_sequence
		previous_visual_position = visual_position
		previous_visual_state = visual_state
		previous_visual_clip = visual_clip

	var final_state_before_restore: Dictionary = npc_system.get_npc_state(NPC_ID)
	var enemy_damage := enemy_hp_before - int(combat_system.get_enemy(enemy_id).get("hp", enemy_hp_before))
	save_probe = _verify_checkpoint_lock(combat_system, npc_system)
	var intervals: Array[float] = []
	for index in range(1, sequence_starts.size()):
		intervals.append(sequence_starts[index] - sequence_starts[index - 1])
	var diagnostics := {
		"production_cycle_seconds": expected_cycle,
		"sequence_starts": sequence_starts,
		"sequence_intervals": intervals,
		"same_sequence_rewinds": same_sequence_rewinds,
		"enemy_damage": enemy_damage,
		"save_probe": save_probe,
		"final_state_before_restore": final_state_before_restore,
	}
	print("T0193_FRIENDLY_CADENCE_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(sequence_starts.size() >= 4, "T0193 friendly pressure did not produce enough legal restarts: %s" % diagnostics)
	for interval in intervals:
		_check(interval >= expected_cycle - FRAME_SECONDS - 0.0001, "T0193 friendly attack restarted before its complete cycle: %s" % diagnostics)
	_check(same_sequence_rewinds == 0, "T0193 friendly art rewound inside one authority sequence: %s" % diagnostics)
	_check(enemy_damage > 0, "T0193 friendly model-contact attack never damaged the enemy after pressure ended: %s" % diagnostics)
	_check(bool(save_probe.get("ok", false)), "T0193 friendly checkpoint did not preserve/rebuild the remaining lock: %s" % diagnostics)

	combat_system.clear_spawned_enemies()
	_finish()


func _verify_checkpoint_lock(combat_system: Node, npc_system: Node) -> Dictionary:
	var before: Dictionary = npc_system.get_npc_state(NPC_ID)
	var before_sequence := int(before.get("combat_attack_sequence", 0))
	var before_remaining := float(before.get("combat_attack_sequence_lock_remaining", 0.0))
	var checkpoint: Dictionary = npc_system.create_formal_spatial_checkpoint()
	var combat_checkpoint: Dictionary = combat_system.create_formal_spatial_checkpoint()
	var saved_actor := {}
	for raw_actor in checkpoint.get("actors", []):
		if raw_actor is Dictionary and str((raw_actor as Dictionary).get("npc_id", "")) == NPC_ID:
			saved_actor = raw_actor
			break
	var saved_remaining := float(saved_actor.get("combat_attack_sequence_lock_remaining", 0.0))
	var restored: Dictionary = npc_system.restore_formal_spatial_checkpoint(checkpoint)
	var combat_restored: Dictionary = combat_system.restore_formal_spatial_checkpoint(combat_checkpoint)
	var after: Dictionary = npc_system.get_npc_state(NPC_ID)
	return {
		"ok": (
			bool(restored.get("ok", false))
			and bool(combat_restored.get("ok", false))
			and bool((combat_restored.get("friendly_cadence_result", {}) as Dictionary).get("ok", false))
			and before_sequence > 0
			and int(saved_actor.get("combat_attack_sequence", 0)) == before_sequence
			and saved_remaining > 0.0
			and absf(saved_remaining - before_remaining) <= 0.0001
			and int(after.get("combat_attack_sequence", 0)) == before_sequence
			and float(after.get("combat_attack_sequence_lock_remaining", 0.0)) > 0.0
			and is_zero_approx(float(after.get("combat_attack_next_sequence_time", 0.0)))
		),
		"before_sequence": before_sequence,
		"before_remaining": before_remaining,
		"saved_sequence": int(saved_actor.get("combat_attack_sequence", 0)),
		"saved_remaining": saved_remaining,
		"restored_remaining": float(after.get("combat_attack_sequence_lock_remaining", 0.0)),
		"restored_next_sequence_time": float(after.get("combat_attack_next_sequence_time", 0.0)),
		"combat_restore": combat_restored.get("friendly_cadence_result", {}),
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0193_FRIENDLY_ATTACK_CADENCE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
