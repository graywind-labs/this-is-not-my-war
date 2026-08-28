extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const COMBAT_ANIMATION_TIMING := preload("res://scripts/presentation/characters/CombatAnimationTiming.gd")
const NPC_ID := "stableman_01"
const WEAPONS := ["sword_shield", "polearm", "bow", "crossbow"]
const RESOURCE_BY_WEAPON := {
	"sword_shield": "item_sword_shield",
	"polearm": "item_polearm",
	"bow": "item_bow",
	"crossbow": "item_crossbow",
}
const EPSILON_SECONDS := 0.01

var _failures: PackedStringArray = []
var _sequence := 100


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null, "CombatSystem missing")
	_check(npc_system != null, "NPCSystem missing")
	_check(equipment_system != null, "EquipmentSystem missing")
	_check(resource_system != null, "ResourceSystem missing")
	_check(time_system != null, "TimeSystem missing")
	if _failures.size() > 0:
		_finish()
		return

	npc_system.set_npc_recruited(NPC_ID, true)
	for weapon_id in WEAPONS:
		resource_system.add_resource(str(RESOURCE_BY_WEAPON[weapon_id]), 3)

	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	_check(npc_actor != null, "Stableman actor missing")
	if npc_actor == null:
		_finish()
		return
	npc_actor.global_position = Vector3.ZERO

	# Production art must consume the same timing in foot and mounted profiles.
	for weapon_id in WEAPONS:
		_check(_equip_weapon(npc_system, equipment_system, weapon_id), "Could not equip %s for profile timing" % weapon_id)
		var npc: Dictionary = npc_system.get_npc(NPC_ID)
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, npc, state)
		var timing: Dictionary = context.get("animation_timing", {})
		_check(not timing.is_empty(), "%s has no shared animation timing" % weapon_id)
		_check(str(timing.get("weapon_id", "")) == weapon_id, "%s timing resolved another weapon" % weapon_id)
		_check(float(timing.get("impact_seconds", 0.0)) > 0.0, "%s impact must be after windup" % weapon_id)
		_check(float(timing.get("impact_seconds", 0.0)) < float(timing.get("cycle_seconds", 0.0)), "%s impact must precede recovery end" % weapon_id)
		for mounted in [false, true]:
			_sequence += 1
			var cycle_seconds := float(timing.get("cycle_seconds", 1.0))
			var elapsed_seconds := cycle_seconds * 0.1
			npc_system.update_npc_state(NPC_ID, {
				"behavior_mode": "combat",
				"combat_mode": "combat",
				"combat_mounted": mounted,
				"current_action": "winding_up_t0142_dummy",
				"combat_attack_sequence": _sequence,
				"combat_attack_phase": "windup",
				"combat_attack_elapsed_seconds": elapsed_seconds,
				"combat_attack_cycle_seconds": cycle_seconds,
				"combat_attack_impact_seconds": float(timing.get("impact_seconds", 0.0)),
				"combat_attack_playback_multiplier": float(timing.get("playback_multiplier", 1.0)),
				"combat_attack_impact_committed": false,
			})
			var art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
			var expected_state := "mounted_attack" if mounted else "attack"
			var expected_authored_position := elapsed_seconds * float(timing.get("playback_multiplier", 1.0))
			_check(str(art.get("current_state", "")) == expected_state, "%s %s profile did not enter %s" % [weapon_id, "mounted" if mounted else "foot", expected_state])
			_check(int(art.get("combat_attack_sequence", -1)) == _sequence, "%s profile lost attack sequence" % weapon_id)
			_check(is_equal_approx(float(art.get("combat_attack_cycle_seconds", 0.0)), cycle_seconds), "%s profile cycle drifted" % weapon_id)
			_check(is_equal_approx(float(art.get("combat_attack_impact_seconds", 0.0)), float(timing.get("impact_seconds", 0.0))), "%s profile impact drifted" % weapon_id)
			_check(absf(float(art.get("combat_attack_animation_position", -1.0)) - expected_authored_position) <= 0.03, "%s %s clip did not seek to authoritative elapsed time: %s" % [weapon_id, "mounted" if mounted else "foot", JSON.stringify(art)])
			_check(absf(float(art.get("combat_attack_animation_speed_scale", 0.0)) - float(timing.get("playback_multiplier", 1.0))) <= 0.01, "%s attack speed still depends on locomotion personality speed" % weapon_id)

	# Raising the required weapon skill must shorten the full cycle and scale the
	# complete animation without changing its authored impact ratio.
	_check(_equip_weapon(npc_system, equipment_system, "sword_shield"), "Could not equip sword for attack-speed scaling")
	var before_npc: Dictionary = npc_system.get_npc(NPC_ID)
	var before_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var before_context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, before_npc, before_state)
	var training_result: Dictionary = npc_system.increase_npc_skill(NPC_ID, "剑盾", 10)
	var after_npc: Dictionary = npc_system.get_npc(NPC_ID)
	var after_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var after_context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, after_npc, after_state)
	var before_timing: Dictionary = before_context.get("animation_timing", {})
	var after_timing: Dictionary = after_context.get("animation_timing", {})
	_check(not training_result.is_empty(), "Sword training did not apply")
	_check(float(after_context.get("attack_interval", INF)) < float(before_context.get("attack_interval", 0.0)), "Higher attack speed did not shorten the complete cycle")
	_check(float(after_timing.get("playback_multiplier", 0.0)) > float(before_timing.get("playback_multiplier", INF)), "Higher attack speed did not accelerate the animation")
	_check(absf(float(after_timing.get("impact_ratio", 0.0)) - float(before_timing.get("impact_ratio", 1.0))) <= 0.0001, "Attack-speed scaling changed the authored impact ratio")

	# Freeze automatic simulation and exercise exact boundaries directly.
	time_system.set_paused(true)
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn_result.get("ok", false)), "Could not spawn timeline target wave: %s" % JSON.stringify(spawn_result))
	if not bool(spawn_result.get("ok", false)):
		_finish()
		return
	var enemy_id := _keep_one_enemy(combat_system)
	_check(not enemy_id.is_empty(), "No enemy remained for timeline verification")
	if enemy_id.is_empty():
		_finish()
		return

	for weapon_id in WEAPONS:
		combat_system._clear_combat_projectiles("verify_t0142_next_weapon")
		_check(_equip_weapon(npc_system, equipment_system, weapon_id), "Could not equip %s for damage timing" % weapon_id)
		var attack_position := Vector3(0.0, 0.0, 8.0) if weapon_id in ["bow", "crossbow"] else Vector3(0.0, 0.0, 1.0)
		_set_enemy_fixture(combat_system, enemy_id, attack_position, 10000)
		await physics_frame
		var mode_result: Dictionary = npc_system.set_npc_behavior_mode(NPC_ID, "combat", "verify_t0142_%s" % weapon_id, {
			"state_changes": {
				"current_action": "combat_ready",
				"combat_target_enemy_id": enemy_id,
				# Each weapon case is an independent authored-boundary probe rather
				# than a continuous battle; clear the production cadence lock between
				# cases so the direct single-attacker helper starts at its boundary.
				"combat_attack_sequence": 0,
				"combat_attack_last_sequence_time": -1.0,
				"combat_attack_next_sequence_time": 0.0,
				"combat_attack_sequence_lock_remaining": 0.0,
			},
			"request_plan_reevaluation": false,
		})
		_check(bool(mode_result.get("ok", false)), "Could not enter combat for %s" % weapon_id)
		var context: Dictionary = combat_system._calculate_npc_attack_context(NPC_ID, npc_system.get_npc(NPC_ID), npc_system.get_npc_state(NPC_ID))
		var timing: Dictionary = context.get("animation_timing", {})
		var impact_seconds := float(timing.get("impact_seconds", 0.0))
		var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
		var before_impact: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, maxf(0.001, impact_seconds - EPSILON_SECONDS))
		var windup_state: Dictionary = npc_system.get_npc_state(NPC_ID)
		_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "%s dealt damage before its authored impact/release" % weapon_id)
		_check(int(before_impact.get("attack_count", -1)) == 0, "%s reported an attack before impact" % weapon_id)
		_check(str(windup_state.get("combat_attack_phase", "")) == "windup", "%s did not remain in windup before impact" % weapon_id)
		_check(str(windup_state.get("current_action", "")).begins_with("winding_up_"), "%s did not expose winding presentation state" % weapon_id)
		var facing_art: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
		var expected_facing := attack_position.normalized()
		var target_facing: Vector3 = facing_art.get("target_facing_direction", Vector3.ZERO)
		_check(target_facing.dot(expected_facing) >= 0.999, "%s friendly attacker did not face its target" % weapon_id)
		if weapon_id in ["sword_shield", "polearm"]:
			# The formal melee sweep reads the retargeted weapon after the
			# BoneAttachment publishes the authored pre-impact pose.
			await process_frame

		var at_impact: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, EPSILON_SECONDS * 2.0)
		var is_ranged: bool = weapon_id in ["bow", "crossbow"]
		if is_ranged:
			_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "%s dealt compatibility damage at release" % weapon_id)
			_check(combat_system.get_active_projectile_snapshots().size() == 1, "%s release did not create one formal projectile" % weapon_id)
			var released_attacks: Array = at_impact.get("attacks", [])
			var released_attack: Dictionary = released_attacks[0] if not released_attacks.is_empty() else {}
			var active_projectile: Dictionary = combat_system.get_active_projectile_snapshots()[0] if combat_system.get_active_projectile_snapshots().size() == 1 else {}
			var ranged_attack_id := str(released_attack.get("attack_id", ""))
			_check(not ranged_attack_id.is_empty(), "%s release omitted attack_id" % weapon_id)
			_check(str(active_projectile.get("attack_id", "")) == ranged_attack_id, "%s timeline/projectile attack_id mismatch" % weapon_id)
			_check(int(active_projectile.get("attack_sequence", 0)) == int(released_attack.get("attack_sequence", -1)), "%s projectile lost the authoritative attack sequence" % weapon_id)
			for _projectile_step in range(100):
				if combat_system.get_active_projectile_snapshots().is_empty():
					break
				combat_system.debug_advance_combat_projectiles(0.05)
		var hp_after_impact := int(combat_system.get_enemy(enemy_id).get("hp", 0))
		var impact_state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if is_ranged:
			var projectile_result: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
			_check(combat_system.get_active_projectile_snapshots().is_empty(), "%s projectile did not finish physical flight" % weapon_id)
			_check(str(projectile_result.get("status", "")) in ["hit", "miss", "blocked", "expired"], "%s projectile did not publish a physical resolution" % weapon_id)
		else:
			var melee_attacks: Array = at_impact.get("attacks", [])
			var melee_resolution: Dictionary = melee_attacks[0] if not melee_attacks.is_empty() else {}
			_check(str(melee_resolution.get("melee_status", "")) in ["hit", "miss", "blocked"], "%s did not perform model-contact resolution at authored impact" % weapon_id)
		_check(int(at_impact.get("attack_count", 0)) == 1, "%s impact did not commit exactly once" % weapon_id)
		_check(str(impact_state.get("combat_attack_phase", "")) == "recovery", "%s did not enter recovery after impact" % weapon_id)
		_check(bool(impact_state.get("combat_attack_impact_committed", false)), "%s impact was not marked committed" % weapon_id)
		var after_once: Dictionary = combat_system._advance_single_npc_combat_attack(NPC_ID, 0.001)
		_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_after_impact, "%s dealt duplicate damage during recovery" % weapon_id)
		_check(int(after_once.get("attack_count", 0)) == 0, "%s reported duplicate recovery damage" % weapon_id)

	# Enemy attacks use the same boundary, face the target, support coarse steps,
	# and lose the old cycle when staggered.
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0142_enemy", {"request_plan_reevaluation": false})
	npc_system.update_npc_state(NPC_ID, {"hp": 100, "max_hp": 100, "unconscious": false, "escaped": false})
	_set_enemy_fixture(combat_system, enemy_id, Vector3(1.0, 0.0, 1.0), 10000)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["attack_power"] = 1
	combat_system._cancel_enemy_attack_timeline(enemy)
	var enemy_target := {
		"type": "npc",
		"id": NPC_ID,
		"name": "timeline target",
		"position": Vector3.ZERO,
		"distance": sqrt(2.0),
	}
	enemy["target"] = enemy_target.duplicate(true)
	var enemy_timing: Dictionary = COMBAT_ANIMATION_TIMING.get_timing(str(enemy.get("weapon_type", "sword_shield")), float(enemy.get("attack_interval", 1.8)))
	var enemy_impact := float(enemy_timing.get("impact_seconds", 0.0))
	var npc_hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var enemy_pre: Dictionary = combat_system._advance_enemy_attack(enemy, enemy_target, maxf(0.001, enemy_impact - EPSILON_SECONDS))
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) == npc_hp_before, "Enemy dealt damage before authored impact")
	_check(int(enemy_pre.get("attack_count", -1)) == 0 and str(enemy.get("attack_cycle_phase", "")) == "windup", "Enemy did not preserve windup boundary")
	_set_active_enemy(combat_system, enemy_id, enemy)
	combat_system._refresh_enemy_node(enemy_id)
	var enemy_art := _enemy_art_by_id(combat_system, enemy_id)
	var enemy_facing: Vector3 = (enemy_art.get("art", {}) as Dictionary).get("target_facing_direction", Vector3.ZERO)
	var expected_enemy_facing := Vector3(-1.0, 0.0, -1.0).normalized()
	_check(enemy_facing.dot(expected_enemy_facing) >= 0.999, "Enemy attacker did not face its target")
	await process_frame
	var enemy_hit: Dictionary = combat_system._advance_enemy_attack(enemy, enemy_target, EPSILON_SECONDS * 2.0)
	var npc_hp_after_hit := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var enemy_attacks: Array = enemy_hit.get("attacks", [])
	var enemy_resolution: Dictionary = enemy_attacks[0] if not enemy_attacks.is_empty() else {}
	_check(int(enemy_hit.get("attack_count", 0)) == 1 and str(enemy_resolution.get("melee_status", "")) in ["hit", "miss", "blocked"], "Enemy impact did not commit one model-contact resolution")
	combat_system._advance_enemy_attack(enemy, enemy_target, 0.001)
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) == npc_hp_after_hit, "Enemy dealt duplicate recovery damage")

	combat_system._cancel_enemy_attack_timeline(enemy)
	npc_system.update_npc_state(NPC_ID, {"hp": 100, "unconscious": false})
	var coarse_seconds := float(enemy_timing.get("cycle_seconds", 1.0)) * 3.0 + enemy_impact + EPSILON_SECONDS
	var coarse_result: Dictionary = combat_system._advance_enemy_attack(enemy, enemy_target, coarse_seconds)
	_check(int(coarse_result.get("attack_count", 0)) == 4, "Coarse enemy step did not preserve four ordered impacts: %s" % JSON.stringify(coarse_result))

	combat_system._cancel_enemy_attack_timeline(enemy)
	npc_system.update_npc_state(NPC_ID, {"hp": 100, "unconscious": false})
	combat_system._advance_enemy_attack(enemy, enemy_target, enemy_impact * 0.5)
	_set_active_enemy(combat_system, enemy_id, enemy)
	var hp_before_stagger := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	var stagger_result: Dictionary = combat_system.apply_enemy_stagger(enemy_id, 0.5, {"source_type": "verify_t0142"})
	var staggered_enemy: Dictionary = combat_system.get_enemy(enemy_id)
	_check(bool(stagger_result.get("interrupted_windup", false)), "Stagger did not report interrupted windup")
	_check(str(staggered_enemy.get("attack_cycle_phase", "")) == "idle" and float(staggered_enemy.get("attack_cycle_elapsed", -1.0)) == 0.0, "Stagger retained the old attack timeline")
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) == hp_before_stagger, "Interrupted enemy windup caused ghost damage")

	combat_system.debug_clear_enemies()
	await process_frame
	_finish()


func _equip_weapon(npc_system: Node, equipment_system: Node, weapon_id: String) -> bool:
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0142_equip", {"request_plan_reevaluation": false})
	npc_system.stop_npc_movement_with_state(NPC_ID, {"current_action": "idle", "combat_mounted": false})
	var current: Dictionary = equipment_system.get_unit_type_snapshot(NPC_ID)
	if str(current.get("main_weapon_id", "")) == weapon_id:
		return true
	var result: Dictionary = equipment_system.equip_npc_main_weapon(NPC_ID, weapon_id, "private")
	return bool(result.get("ok", false))


func _keep_one_enemy(combat_system: Node) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	var kept_id := str(enemy_ids[0])
	for raw_enemy_id in enemy_ids:
		var enemy_id := str(raw_enemy_id)
		if enemy_id != kept_id:
			combat_system._remove_enemy_from_combat(enemy_id)
	return kept_id


func _set_enemy_fixture(combat_system: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	enemy["target"] = {}
	combat_system._cancel_enemy_attack_timeline(enemy)
	_set_active_enemy(combat_system, enemy_id, enemy)
	var node_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(node_paths.get(enemy_id, NodePath())) as Node3D if node_paths.has(enemy_id) else null
	if enemy_node != null:
		enemy_node.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _set_active_enemy(combat_system: Node, enemy_id: String, enemy: Dictionary) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)


func _enemy_art_by_id(combat_system: Node, enemy_id: String) -> Dictionary:
	for entry in combat_system.debug_get_enemy_art_snapshots():
		if str(entry.get("enemy_id", "")) == enemy_id:
			return entry
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0142_COMBAT_ANIMATION_TIMELINE PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0142_COMBAT_ANIMATION_TIMELINE FAIL count=%d" % _failures.size())
	quit(1)
