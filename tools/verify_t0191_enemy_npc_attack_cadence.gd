extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const SAMPLE_FRAMES := 900
const EXPECTED_ATTACK_SPEED := 0.38
const FRAME_SECONDS := 1.0 / 60.0

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null and time_system != null, "T0191 required systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0191 failed to spawn production wave 1: %s" % started)
	if not bool(started.get("ok", false)):
		_finish()
		return

	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() == 8, "T0191 expected eight production enemies, got %d" % enemy_ids.size())
	var expected_cycle := 1.0 / EXPECTED_ATTACK_SPEED
	var timing_reference: Dictionary = {}
	for raw_enemy_id in enemy_ids:
		var enemy_id := str(raw_enemy_id)
		var enemy: Dictionary = combat_system.get_enemy(enemy_id)
		_check(is_equal_approx(float(enemy.get("attack_speed", 0.0)), EXPECTED_ATTACK_SPEED), "T0191 production attack speed drifted: %s" % enemy)
		_check(absf(float(enemy.get("attack_interval", 0.0)) - expected_cycle) <= 0.0001, "T0191 production attack cycle drifted: %s" % enemy)
		var target_npc := {"type": "npc", "id": NPC_ID, "name": "艾达", "position": Vector3.ZERO}
		var target_gate := {"type": "building", "id": "front_gate", "name": "正门", "position": Vector3.ZERO}
		var npc_probe := enemy.duplicate(true)
		var gate_probe := enemy.duplicate(true)
		combat_system._cancel_enemy_attack_timeline(npc_probe)
		combat_system._cancel_enemy_attack_timeline(gate_probe)
		combat_system._advance_enemy_attack(npc_probe, target_npc, 0.25)
		combat_system._advance_enemy_attack(gate_probe, target_gate, 0.25)
		var npc_timing := _attack_timing_snapshot(npc_probe)
		var gate_timing := _attack_timing_snapshot(gate_probe)
		_check(npc_timing == gate_timing, "T0191 target type changed enemy attack timing: npc=%s gate=%s" % [npc_timing, gate_timing])
		if timing_reference.is_empty():
			timing_reference = npc_timing
	_verify_interrupted_sequence_cadence(combat_system, combat_system.get_enemy(str(enemy_ids[0])), expected_cycle)

	var ada := root.get_node_or_null("Main/WorldRoot/Station/NPCs/VeteranDeputy01") as ActorMotionBody
	_check(ada != null, "T0191 Ada actor missing")
	if ada == null:
		_finish()
		return
	ada.cancel_motion("t0191_fixture")
	ada.global_position = Vector3(0.0, 0.0, 70.0)
	ada.velocity = Vector3.ZERO
	npc_system.set_npc_recruited(NPC_ID, true)
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0191_full_engagement", {
		"state_changes": {
			"hp": 120,
			"max_hp": 120,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_attack_cooldown": 0.0,
		},
		"request_plan_reevaluation": false,
	})

	for index in range(enemy_ids.size()):
		var enemy_id := str(enemy_ids[index])
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		_check(actor != null, "T0191 enemy actor missing: %s" % enemy_id)
		if actor == null:
			continue
		var angle := TAU * float(index) / float(enemy_ids.size())
		actor.cancel_motion("t0191_fixture")
		actor.global_position = ada.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 4.0
		actor.velocity = Vector3.ZERO
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		enemy["position"] = actor.global_position
		enemy["hp"] = 10000
		enemy["max_hp"] = 10000
		enemy["alive"] = true
		enemy["target"] = {}
		combat_system._cancel_enemy_attack_timeline(enemy)
		combat_system._active_enemies[enemy_id] = enemy
		combat_system._release_enemy_attack_position(enemy_id, "t0191_fixture")
		combat_system._refresh_enemy_node(enemy_id)

	var sequence_samples: Dictionary = {}
	var previous_sequences: Dictionary = {}
	var visual_enemy_id := ""
	var visual_art: Node = null
	for raw_enemy_id in enemy_ids:
		var candidate_id := str(raw_enemy_id)
		var candidate_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(candidate_id, NodePath())) as ActorMotionBody
		var candidate_art := candidate_actor.get_node_or_null("EnemyArtView") if candidate_actor != null else null
		if candidate_art != null and candidate_art.has_method("debug_get_snapshot"):
			visual_enemy_id = candidate_id
			visual_art = candidate_art
			break
	_check(visual_art != null, "T0191 production enemy art missing")
	if visual_art != null:
		var visual_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(visual_enemy_id, NodePath())) as ActorMotionBody
		visual_actor.cancel_motion("t0191_visual_fixture")
		visual_actor.global_position = ada.global_position + Vector3(0.0, 0.0, 1.08)
		visual_actor.velocity = Vector3.ZERO
		var visual_enemy: Dictionary = combat_system._active_enemies.get(visual_enemy_id, {})
		visual_enemy["position"] = visual_actor.global_position
		visual_enemy["target"] = {}
		combat_system._cancel_enemy_attack_timeline(visual_enemy)
		combat_system._active_enemies[visual_enemy_id] = visual_enemy
		combat_system._release_enemy_attack_position(visual_enemy_id, "t0191_visual_fixture")
		combat_system._refresh_enemy_node(visual_enemy_id)
	for raw_enemy_id in enemy_ids:
		var enemy_id := str(raw_enemy_id)
		previous_sequences[enemy_id] = int(combat_system.get_enemy(enemy_id).get("attack_sequence", 0))
		sequence_samples[enemy_id] = []
	var ada_state_before: Dictionary = npc_system.get_npc_state(NPC_ID)
	var ada_sequence_before := int(ada_state_before.get("combat_attack_sequence", 0))
	var ada_hp_before := int(ada_state_before.get("hp", 0))
	var enemy_hp_total_before := _enemy_hp_total(combat_system, enemy_ids)
	var visual_sequence_starts: Array[float] = []
	var visual_same_sequence_rewinds := 0
	var previous_visual_sequence := int(combat_system.get_enemy(visual_enemy_id).get("attack_sequence", 0)) if not visual_enemy_id.is_empty() else -1
	var previous_visual_position := -1.0
	var previous_visual_state := ""
	var previous_visual_clip := ""
	time_system.set_paused(false)
	for frame in range(SAMPLE_FRAMES):
		await physics_frame
		for raw_enemy_id in enemy_ids:
			var enemy_id := str(raw_enemy_id)
			var sequence := int(combat_system.get_enemy(enemy_id).get("attack_sequence", 0))
			if sequence <= int(previous_sequences.get(enemy_id, 0)):
				continue
			previous_sequences[enemy_id] = sequence
			(sequence_samples[enemy_id] as Array).append(float(frame) * FRAME_SECONDS)
		if visual_art != null:
			var visual_snapshot: Dictionary = visual_art.debug_get_snapshot()
			var visual_sequence := int(visual_snapshot.get("combat_attack_sequence", -1))
			var visual_state := str(visual_snapshot.get("current_state", ""))
			var visual_clip := str(visual_snapshot.get("current_clip", ""))
			var visual_position := float(visual_snapshot.get("combat_attack_animation_position", -1.0))
			var visual_sequence_changed := visual_sequence != previous_visual_sequence
			if visual_sequence_changed:
				visual_sequence_starts.append(float(frame) * FRAME_SECONDS)
			if (
				visual_state == "attack"
				and previous_visual_state == "attack"
				and visual_clip == previous_visual_clip
				and not visual_sequence_changed
				and visual_position >= 0.0
				and previous_visual_position >= 0.0
				and visual_position + 0.02 < previous_visual_position
			):
				visual_same_sequence_rewinds += 1
			previous_visual_sequence = visual_sequence
			previous_visual_position = visual_position
			previous_visual_state = visual_state
			previous_visual_clip = visual_clip

	var ada_state_after: Dictionary = npc_system.get_npc_state(NPC_ID)
	var ada_sequence_delta := int(ada_state_after.get("combat_attack_sequence", 0)) - ada_sequence_before
	var ada_damage := ada_hp_before - int(ada_state_after.get("hp", ada_hp_before))
	var enemy_damage := enemy_hp_total_before - _enemy_hp_total(combat_system, enemy_ids)
	var intervals := _collect_sequence_intervals(sequence_samples)
	var diagnostics := {
		"production_cycle_seconds": expected_cycle,
		"timing_reference": timing_reference,
		"enemy_sequence_intervals": intervals,
		"visual_enemy_id": visual_enemy_id,
		"visual_sequence_starts": visual_sequence_starts,
		"visual_same_sequence_rewinds": visual_same_sequence_rewinds,
		"ada_sequence_delta": ada_sequence_delta,
		"ada_damage_taken": ada_damage,
		"enemy_damage_taken": enemy_damage,
		"attack_positions": _attack_position_summary(combat_system.debug_get_enemy_attack_position_snapshot()),
	}
	print("T0191_CADENCE_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(ada_sequence_delta >= 2, "T0191 Ada did not counterattack before the production engagement resolved: %s" % diagnostics)
	_check(enemy_damage > 0, "T0191 Ada attack cycles did not damage an enemy: %s" % diagnostics)
	_check(visual_same_sequence_rewinds == 0, "T0191 enemy art replayed the attack clip inside one authority sequence: %s" % diagnostics)
	for interval in _collect_sample_intervals(visual_sequence_starts):
		_check(float(interval) >= expected_cycle - 0.12, "T0191 visible enemy swings restarted faster than production cadence: %s" % diagnostics)
	for interval in intervals:
		_check(float(interval) >= expected_cycle - 0.12, "T0191 enemy started attack cycles faster than production cadence: %s" % diagnostics)

	combat_system.clear_spawned_enemies()
	_finish()


func _attack_timing_snapshot(enemy: Dictionary) -> Dictionary:
	return {
		"phase": str(enemy.get("attack_cycle_phase", "")),
		"elapsed": snappedf(float(enemy.get("attack_cycle_elapsed", 0.0)), 0.0001),
		"cycle": snappedf(float(enemy.get("attack_cycle_duration", 0.0)), 0.0001),
		"impact": snappedf(float(enemy.get("attack_impact_seconds", 0.0)), 0.0001),
		"playback": snappedf(float(enemy.get("attack_playback_multiplier", 0.0)), 0.0001),
		"sequence": int(enemy.get("attack_sequence", 0)),
	}


func _verify_interrupted_sequence_cadence(combat_system: Node, source_enemy: Dictionary, expected_cycle: float) -> void:
	var enemy := source_enemy.duplicate(true)
	enemy["id"] = "t0191_interrupted_sequence_probe"
	enemy["attack_sequence"] = 0
	enemy["attack_last_sequence_time"] = -1.0
	enemy["attack_next_sequence_time"] = 0.0
	combat_system._cancel_enemy_attack_timeline(enemy)
	var target := {
		"type": "npc",
		"id": NPC_ID,
		"name": "艾达",
		"position": Vector3.ZERO,
	}
	var timeline_seconds := 0.0
	var previous_sequence := 0
	var sequence_starts: Array[float] = []
	for frame in range(720):
		timeline_seconds += FRAME_SECONDS
		# Reproduce the real failure mode: contact/path state repeatedly cancels
		# the visual windup before impact, then re-enters attack range shortly
		# afterwards. A cancellation must not grant a fresh attack immediately.
		if frame % 12 < 3:
			combat_system._advance_enemy_attack(enemy, target, FRAME_SECONDS, timeline_seconds)
		else:
			combat_system._cancel_enemy_attack_timeline(enemy)
		var sequence := int(enemy.get("attack_sequence", 0))
		if sequence > previous_sequence:
			sequence_starts.append(timeline_seconds)
			previous_sequence = sequence
	var intervals: Array[float] = []
	for index in range(1, sequence_starts.size()):
		intervals.append(sequence_starts[index] - sequence_starts[index - 1])
	_check(sequence_starts.size() >= 4, "T0191 interrupted cadence probe did not restart enough sequences: %s" % [sequence_starts])
	for interval in intervals:
		_check(
			interval >= expected_cycle - FRAME_SECONDS - 0.0001,
			"T0191 contact cancellation restarted the visible enemy swing too early: starts=%s intervals=%s" % [sequence_starts, intervals]
		)


func _enemy_hp_total(combat_system: Node, enemy_ids: Array) -> int:
	var total := 0
	for raw_enemy_id in enemy_ids:
		total += int(combat_system.get_enemy(str(raw_enemy_id)).get("hp", 0))
	return total


func _collect_sequence_intervals(sequence_samples: Dictionary) -> Array[float]:
	var result: Array[float] = []
	for raw_samples in sequence_samples.values():
		var samples := raw_samples as Array
		for index in range(1, samples.size()):
			result.append(float(samples[index]) - float(samples[index - 1]))
	return result


func _collect_sample_intervals(samples: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for index in range(1, samples.size()):
		result.append(samples[index] - samples[index - 1])
	return result


func _attack_position_summary(snapshot: Dictionary) -> Dictionary:
	var targets: Dictionary = {}
	var statuses: Dictionary = {}
	for raw_lease in snapshot.get("leases", []):
		var lease := raw_lease as Dictionary
		var target_key := str(lease.get("target_key", ""))
		var status := str(lease.get("status", ""))
		targets[target_key] = int(targets.get(target_key, 0)) + 1
		statuses[status] = int(statuses.get(status, 0)) + 1
	return {
		"lease_count": int(snapshot.get("lease_count", 0)),
		"waiter_count": int(snapshot.get("waiter_count", 0)),
		"targets": targets,
		"statuses": statuses,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0191_ENEMY_NPC_ATTACK_CADENCE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
