extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const BUILDING_SAMPLE_FRAMES := 720
const DUEL_SAMPLE_FRAMES := 900

var _failures: PackedStringArray = []
var _building_hits_by_enemy: Dictionary = {}


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
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var event_bus := root.get_node_or_null("EventBus")
	_check(combat_system != null and building_system != null and npc_system != null and time_system != null and event_bus != null, "T0186 required systems missing")
	if not _failures.is_empty():
		_finish()
		return
	if not event_bus.event_recorded.is_connected(_on_event_recorded):
		event_bus.event_recorded.connect(_on_event_recorded)

	await _verify_building_assault(combat_system, building_system, npc_system, time_system)
	await _verify_ada_duel(combat_system, npc_system, time_system)
	combat_system.clear_spawned_enemies()
	_finish()


func _verify_building_assault(combat_system: Node, building_system: Node, npc_system: Node, time_system: Node) -> void:
	time_system.set_paused(true)
	_building_hits_by_enemy.clear()
	# T0196 expands the single enemy awareness radius to 37.2m. Keep this pure
	# building-timeline fixture's NPCs explicitly outside that radius; unit-target
	# acquisition and unrestricted NPC contact have their own dedicated coverage.
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(120.0 + float(index) * 2.0, 0.0, 120.0)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0186 building fixture failed to spawn: %s" % started)
	if not bool(started.get("ok", false)):
		return
	var gate: Dictionary = building_system._buildings.get("front_gate", {})
	gate["hp"] = 100000
	gate["max_hp"] = 100000
	building_system._buildings["front_gate"] = gate
	combat_system.debug_step_enemy_ai(0.1)

	var attackers: Array[String] = []
	var initial_sequences: Dictionary = {}
	var last_observed_attack_sequence: Dictionary = {}
	var contacts_by_enemy: Dictionary = {}
	var active_enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	var fixture_target: Dictionary = combat_system._make_building_target("front_gate")
	for fixture_index in range(mini(5, active_enemy_ids.size())):
		var enemy_id := active_enemy_ids[fixture_index]
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		if actor == null:
			continue
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var fixture_candidates: Array[Dictionary] = combat_system._get_enemy_attack_position_candidates(enemy_id, enemy, fixture_target)
		if fixture_candidates.size() <= fixture_index:
			continue
		# Guidance zones are non-exclusive. Give this isolated timeline fixture one
		# real body per authored door contact; T0180 covers the natural eight-body
		# crowd and its stall recovery separately.
		var fixture_candidate := fixture_candidates[fixture_index]
		var attack_position := _to_vector3(fixture_candidate.get("position", actor.global_position))
		var contact_position := _to_vector3(fixture_candidate.get("contact_position", attack_position))
		var outward := attack_position - contact_position
		outward.y = 0.0
		outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
		actor.cancel_motion("superseded")
		actor.global_position = attack_position + outward * 0.30
		actor.velocity = Vector3.ZERO
		enemy["position"] = actor.global_position
		combat_system._active_enemies[enemy_id] = enemy
		attackers.append(enemy_id)
		initial_sequences[enemy_id] = int(enemy.get("attack_sequence", 0))
		last_observed_attack_sequence[enemy_id] = int(enemy.get("attack_sequence", 0))
	_check(attackers.size() == 5, "T0186 expected five door-panel attackers, got %d" % attackers.size())
	for active_enemy_id in combat_system.get_active_enemy_ids():
		if not attackers.has(active_enemy_id):
			combat_system._remove_enemy_from_combat(active_enemy_id)
	combat_system.debug_step_enemy_ai(0.01)
	time_system.set_paused(false)
	for _frame in range(BUILDING_SAMPLE_FRAMES):
		await physics_frame
		for enemy_id in attackers:
			var sampled_enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
			var last_attack: Dictionary = sampled_enemy.get("last_attack_result", {}) if sampled_enemy.get("last_attack_result", {}) is Dictionary else {}
			for raw_attack in last_attack.get("attacks", []):
				var attack := raw_attack as Dictionary
				var attack_sequence := int(attack.get("attack_sequence", -1))
				if attack_sequence <= int(last_observed_attack_sequence.get(enemy_id, -1)):
					continue
				last_observed_attack_sequence[enemy_id] = attack_sequence
				var contacts: Array = contacts_by_enemy.get(enemy_id, [])
				var contact := attack.get("melee_contact", {}) as Dictionary
				contacts.append({
					"sequence": attack_sequence,
					"status": contact.get("status", ""),
					"reason": contact.get("reason", ""),
					"samples": contact.get("sample_count", 0),
					"reach": contact.get("model_max_horizontal_reach", 0.0),
					"collider": contact.get("collider_path", ""),
					"identity": contact.get("collision_identity", {}),
				})
				contacts_by_enemy[enemy_id] = contacts

	var building_diagnostics: Array[Dictionary] = []
	for enemy_id in attackers:
		var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
		var attempts := maxi(0, int(enemy.get("attack_sequence", 0)) - int(initial_sequences.get(enemy_id, 0)))
		var hits := int(_building_hits_by_enemy.get(enemy_id, 0))
		var actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
		var contacts: Array = contacts_by_enemy.get(enemy_id, [])
		var contact_statuses: Array[String] = []
		var contact_reasons: Array[String] = []
		var contact_identities: Array[Dictionary] = []
		for raw_contact in contacts:
			var contact := raw_contact as Dictionary
			contact_statuses.append(str(contact.get("status", "")))
			contact_reasons.append(str(contact.get("reason", "")))
			contact_identities.append((contact.get("identity", {}) as Dictionary).duplicate(true))
		var target: Dictionary = enemy.get("target", {}) if enemy.get("target", {}) is Dictionary else {}
		building_diagnostics.append({
			"enemy_id": enemy_id,
			"attempts": attempts,
			"hits": hits,
			"phase": enemy.get("attack_cycle_phase", ""),
			"action": enemy.get("current_action", ""),
			"position": actor.global_position if actor != null else Vector3.INF,
			"target_id": target.get("id", ""),
			"attack_position_status": target.get("attack_position_status", ""),
			"contact_statuses": contact_statuses,
			"contact_reasons": contact_reasons,
			"contact_identities": contact_identities,
		})
		_check(attempts >= 3, "T0186 building attacker did not sustain its timeline: %s" % building_diagnostics[-1])
		_check(hits >= maxi(2, attempts - 1), "T0186 building attacker produced too many visible misses: %s" % building_diagnostics[-1])
	_check(int(building_system.get_building("front_gate").get("hp", 100000)) <= 99920, "T0186 five-attacker building assault damage remained abnormally low: %s" % [building_diagnostics])
	print("T0186_BUILDING_DIAGNOSTICS %s" % JSON.stringify(building_diagnostics))
	combat_system.clear_spawned_enemies()
	for _frame in range(3):
		await process_frame
		await physics_frame


func _verify_ada_duel(combat_system: Node, npc_system: Node, time_system: Node) -> void:
	time_system.set_paused(true)
	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0186 duel fixture failed to spawn: %s" % started)
	if not bool(started.get("ok", false)):
		return
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	_check(not enemy_ids.is_empty(), "T0186 duel fixture has no enemy")
	if enemy_ids.is_empty():
		return
	var enemy_id := str(enemy_ids[0])
	for raw_enemy_id in enemy_ids:
		if str(raw_enemy_id) != enemy_id:
			combat_system._remove_enemy_from_combat(str(raw_enemy_id))

	var ada := root.get_node_or_null("Main/WorldRoot/Station/NPCs/VeteranDeputy01") as ActorMotionBody
	var enemy_actor := combat_system.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as ActorMotionBody
	_check(ada != null and enemy_actor != null, "T0186 duel actors missing")
	if ada == null or enemy_actor == null:
		return
	ada.cancel_motion("t0186_duel_fixture")
	ada.global_position = Vector3(0.0, 0.0, 70.0)
	ada.velocity = Vector3.ZERO
	npc_system.set_npc_recruited(NPC_ID, true)
	npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0186_duel", {
		"state_changes": {
			"hp": 10000,
			"max_hp": 10000,
			"unconscious": false,
			"escaped": false,
			"combat_mounted": false,
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0,
		},
		"request_plan_reevaluation": false,
	})

	enemy_actor.cancel_motion("t0186_duel_fixture")
	enemy_actor.global_position = ada.global_position + Vector3(0.0, 0.0, 1.08)
	enemy_actor.velocity = Vector3.ZERO
	var enemy: Dictionary = combat_system._active_enemies.get(enemy_id, {})
	enemy["position"] = enemy_actor.global_position
	enemy["hp"] = 10000
	enemy["max_hp"] = 10000
	enemy["alive"] = true
	enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(enemy)
	combat_system._active_enemies[enemy_id] = enemy
	combat_system._release_enemy_attack_position(enemy_id, "t0186_duel_reset")
	combat_system._refresh_enemy_node(enemy_id)

	var ada_hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var enemy_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var ada_sequence_before := int(npc_system.get_npc_state(NPC_ID).get("combat_attack_sequence", 0))
	var enemy_sequence_before := int(combat_system.get_enemy(enemy_id).get("attack_sequence", 0))
	var ada_damage_frames := 0
	var enemy_damage_frames := 0
	var action_transitions := 0
	var last_pair := ""
	time_system.set_paused(false)
	for _frame in range(DUEL_SAMPLE_FRAMES):
		await physics_frame
		var ada_state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var current_enemy: Dictionary = combat_system.get_enemy(enemy_id)
		var pair := "%s|%s" % [str(ada_state.get("current_action", "")), str(current_enemy.get("current_action", ""))]
		if not last_pair.is_empty() and pair != last_pair:
			action_transitions += 1
		last_pair = pair
		var ada_hp := int(ada_state.get("hp", ada_hp_before))
		var enemy_hp := int(current_enemy.get("hp", enemy_hp_before))
		if ada_hp < ada_hp_before:
			ada_damage_frames += 1
			ada_hp_before = ada_hp
		if enemy_hp < enemy_hp_before:
			enemy_damage_frames += 1
			enemy_hp_before = enemy_hp

	var ada_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var final_enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var last_melee: Dictionary = combat_system.debug_get_combat_snapshot().get("last_melee_contact_result", {})
	var diagnostics := {
		"ada_damage_events": ada_damage_frames,
		"enemy_damage_events": enemy_damage_frames,
		"ada_sequence_delta": int(ada_state.get("combat_attack_sequence", 0)) - ada_sequence_before,
		"enemy_sequence_delta": int(final_enemy.get("attack_sequence", 0)) - enemy_sequence_before,
		"action_transitions": action_transitions,
		"ada_action": ada_state.get("current_action", ""),
		"enemy_action": final_enemy.get("current_action", ""),
		"distance": ada.global_position.distance_to(enemy_actor.global_position),
		"ada_motion_state": ada.debug_get_motion_snapshot().get("state", ""),
		"enemy_motion_state": enemy_actor.debug_get_motion_snapshot().get("state", ""),
		"last_melee": {
			"status": last_melee.get("status", ""),
			"reason": last_melee.get("reason", ""),
			"source_side": last_melee.get("source_side", ""),
			"source_id": last_melee.get("source_id", ""),
			"actual_target_type": last_melee.get("actual_target_type", ""),
			"actual_target_id": last_melee.get("actual_target_id", ""),
		},
	}
	print("T0186_DUEL_DIAGNOSTICS %s" % JSON.stringify(diagnostics))
	_check(int(diagnostics.get("ada_sequence_delta", 0)) >= 4, "T0186 Ada did not sustain attack sequences: %s" % diagnostics)
	_check(int(diagnostics.get("enemy_sequence_delta", 0)) >= 4, "T0186 enemy did not sustain attack sequences: %s" % diagnostics)
	_check(enemy_damage_frames >= 3, "T0186 Ada repeatedly animated without damaging the enemy: %s" % diagnostics)
	_check(ada_damage_frames >= 3, "T0186 enemy repeatedly animated without damaging Ada: %s" % diagnostics)
	_check(action_transitions <= 80, "T0186 duel oscillated between movement and attack too often: %s" % diagnostics)


func _on_event_recorded(event: Dictionary) -> void:
	if str(event.get("type", "")) != "building_damaged":
		return
	var payload: Dictionary = event.get("payload", {}) if event.get("payload", {}) is Dictionary else {}
	if str(payload.get("building_id", "")) != "front_gate":
		return
	for raw_actor_id in event.get("actor_ids", []):
		var actor_id := str(raw_actor_id)
		_building_hits_by_enemy[actor_id] = int(_building_hits_by_enemy.get(actor_id, 0)) + 1


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0186_MELEE_ENGAGEMENT_STABILITY_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
