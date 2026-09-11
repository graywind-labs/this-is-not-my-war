extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const COMBAT_ANIMATION_TIMING := preload("res://scripts/presentation/characters/CombatAnimationTiming.gd")
const NPC_ID := "stableman_01"
const WEAPONS := {
	"sword_shield": "item_sword_shield",
	"polearm": "item_polearm",
}

var _failures: PackedStringArray = []
var _sequence := 1400


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
	_check(combat_system != null and npc_system != null and equipment_system != null and resource_system != null and time_system != null, "T0144 systems missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	npc_system.set_npc_recruited(NPC_ID, true)
	for weapon_id in WEAPONS:
		resource_system.add_resource(str(WEAPONS[weapon_id]), 2)
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	_check(bool(spawn_result.get("ok", false)), "Could not spawn T0144 target wave")
	var enemy_id := _keep_one_enemy(combat_system)
	_check(not enemy_id.is_empty(), "T0144 target enemy missing")
	if enemy_id.is_empty():
		_finish()
		return
	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	_check(npc_actor != null, "T0144 source NPC actor missing")
	if npc_actor == null:
		_finish()
		return

	for weapon_id in WEAPONS:
		npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0144_equip", {"request_plan_reevaluation": false})
		npc_system.stop_npc_movement_with_state(NPC_ID, {"current_action": "idle", "combat_mounted": false})
		var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(NPC_ID, weapon_id, "private")
		_check(bool(equip_result.get("ok", false)), "Could not equip %s" % weapon_id)
		var source_position := npc_actor.global_position
		_set_enemy_fixture(combat_system, enemy_id, source_position + Vector3(0.0, 0.0, -4.0), 500)
		await physics_frame
		var timing: Dictionary = COMBAT_ANIMATION_TIMING.get_timing(weapon_id, 1.0)
		var weapon: Dictionary = equipment_system.get_weapon_def(weapon_id)
		var contact_config: Dictionary = weapon.get("melee_contact", {})
		var impact_authored := float(timing.get("impact_authored_seconds", 0.0))
		var window := float(contact_config.get("sample_window_authored_seconds", 0.22))
		var count := int(contact_config.get("sample_count", 7))
		_sequence += 1
		npc_system.update_npc_state(NPC_ID, {
			"behavior_mode": "combat",
			"combat_mode": "combat",
			"combat_mounted": false,
			"current_action": "winding_up_%s" % enemy_id,
			"combat_attack_sequence": _sequence,
			"combat_attack_phase": "windup",
			"combat_attack_cycle_seconds": 1.0,
			"combat_attack_impact_seconds": float(timing.get("impact_seconds", 0.0)),
			"combat_attack_elapsed_seconds": 0.0,
			"combat_attack_playback_multiplier": float(timing.get("playback_multiplier", 1.0)),
		})
		npc_actor.set_facing_direction(Vector3(0.0, 0.0, -1.0))
		await process_frame
		var facing_snapshot: Dictionary = npc_system.debug_get_npc_character_art_snapshot(NPC_ID)
		var formal_facing: Vector3 = facing_snapshot.get("visual_forward", Vector3(0.0, 0.0, -1.0))
		var character_art := npc_actor.get("_character_art_view") as Node
		var animation_player := character_art.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer if character_art != null else null
		_check(animation_player != null, "%s animation player missing" % weapon_id)
		if animation_player == null:
			continue
		var clip_name := "Melee_1H_Attack_Slice_Horizontal" if weapon_id == "sword_shield" else "Melee_2H_Attack_Stab"
		var samples := await _collect_model_samples(npc_system, animation_player, weapon_id, clip_name, impact_authored, window, count)
		_check(samples.size() >= 2, "%s did not expose model contact samples" % weapon_id)
		if samples.size() < 2:
			continue
		var source_origin := npc_actor.global_position
		var max_reach := 0.0
		var max_forward_reach := 0.0
		var forward_contact_range := _measure_forward_contact_range(samples, source_origin, formal_facing, 0.42 + float(contact_config.get("radius", 0.1)))
		var contact_sample: Dictionary = samples[samples.size() - 1]
		for sample in samples:
			var tip: Vector3 = sample.get("contact_end", source_origin)
			var reach := Vector2(tip.x - source_origin.x, tip.z - source_origin.z).length()
			max_forward_reach = maxf(max_forward_reach, formal_facing.dot(Vector3(tip.x - source_origin.x, 0.0, tip.z - source_origin.z)))
			if reach > max_reach:
				max_reach = reach
				contact_sample = sample
		_check(max_reach > 0.5, "%s model reach was not measurable" % weapon_id)
		print("T0144_REACH %s radial=%.3f forward=%.3f front_contact=%.3f" % [weapon_id, max_reach, max_forward_reach, forward_contact_range])
		var contact_start: Vector3 = contact_sample.get("contact_start", source_origin)
		var contact_end: Vector3 = contact_sample.get("contact_end", contact_start)
		var visible_contact := contact_start.lerp(contact_end, 0.78)
		_set_enemy_fixture(combat_system, enemy_id, Vector3(visible_contact.x, source_origin.y, visible_contact.z), 500)
		await physics_frame
		var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
		combat_system._begin_melee_swing("friendly", NPC_ID, weapon_id, combat_system.get_enemy(enemy_id), _sequence)
		await _feed_model_samples(combat_system, animation_player, weapon_id, clip_name, impact_authored, window, count)
		var hit_result: Dictionary = combat_system._resolve_npc_melee_contact(
			NPC_ID,
			npc_system.get_npc(NPC_ID),
			combat_system.get_enemy(enemy_id),
			combat_system._calculate_npc_attack_context(NPC_ID, npc_system.get_npc(NPC_ID), npc_system.get_npc_state(NPC_ID))
		)
		_check(str(hit_result.get("melee_status", "")) == "hit", "%s visible model contact did not hit: %s" % [weapon_id, JSON.stringify(hit_result.get("melee_contact", {}))])
		_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) < hp_before, "%s contact did not apply damage" % weapon_id)

		var outward := Vector3(contact_end.x - source_origin.x, 0.0, contact_end.z - source_origin.z).normalized()
		var miss_position := source_origin + outward * (max_reach + 0.95)
		_set_enemy_fixture(combat_system, enemy_id, miss_position, 500)
		await physics_frame
		_sequence += 1
		npc_system.update_npc_state(NPC_ID, {
			"combat_attack_sequence": _sequence,
			"combat_attack_phase": "windup",
			"current_action": "winding_up_%s" % enemy_id,
		})
		combat_system._begin_melee_swing("friendly", NPC_ID, weapon_id, combat_system.get_enemy(enemy_id), _sequence)
		await _feed_model_samples(combat_system, animation_player, weapon_id, clip_name, impact_authored, window, count)
		var miss_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
		var miss_result: Dictionary = combat_system._resolve_npc_melee_contact(
			NPC_ID,
			npc_system.get_npc(NPC_ID),
			combat_system.get_enemy(enemy_id),
			combat_system._calculate_npc_attack_context(NPC_ID, npc_system.get_npc(NPC_ID), npc_system.get_npc_state(NPC_ID))
		)
		_check(str(miss_result.get("melee_status", "")) != "hit", "%s hit beyond its visible model reach" % weapon_id)
		_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == miss_hp_before, "%s miss applied phantom damage" % weapon_id)
		_sequence += 1
		npc_system.update_npc_state(NPC_ID, {
			"combat_mounted": true,
			"current_action": "winding_up_%s" % enemy_id,
			"combat_attack_sequence": _sequence,
			"combat_attack_phase": "windup",
			"combat_attack_elapsed_seconds": 0.0,
		})
		await process_frame
		var mounted_clip := "Mounted_1H_Attack" if weapon_id == "sword_shield" else "Mounted_Polearm_Stab"
		var mounted_timing: Dictionary = COMBAT_ANIMATION_TIMING.get_timing(weapon_id, 1.0, true)
		var mounted_impact_authored := float(mounted_timing.get("impact_authored_seconds", impact_authored))
		var mounted_samples := await _collect_model_samples(npc_system, animation_player, weapon_id, mounted_clip, mounted_impact_authored, window, count)
		var mounted_max_reach := 0.0
		var mounted_max_forward_reach := 0.0
		var mounted_forward_contact_range := _measure_forward_contact_range(mounted_samples, source_origin, formal_facing, 0.42 + float(contact_config.get("radius", 0.1)))
		var mounted_contact_sample: Dictionary = mounted_samples[mounted_samples.size() - 1] if not mounted_samples.is_empty() else {}
		for mounted_sample in mounted_samples:
			var mounted_tip: Vector3 = mounted_sample.get("contact_end", source_origin)
			var mounted_reach := Vector2(mounted_tip.x - source_origin.x, mounted_tip.z - source_origin.z).length()
			mounted_max_forward_reach = maxf(mounted_max_forward_reach, formal_facing.dot(Vector3(mounted_tip.x - source_origin.x, 0.0, mounted_tip.z - source_origin.z)))
			if mounted_reach > mounted_max_reach:
				mounted_max_reach = mounted_reach
				mounted_contact_sample = mounted_sample
		print("T0144_MOUNTED_REACH %s radial=%.3f forward=%.3f front_contact=%.3f" % [weapon_id, mounted_max_reach, mounted_max_forward_reach, mounted_forward_contact_range])
		_check(mounted_max_reach > 0.5, "%s mounted model reach was not measurable" % weapon_id)
		if not mounted_contact_sample.is_empty():
			var mounted_start: Vector3 = mounted_contact_sample.get("contact_start", source_origin)
			var mounted_end: Vector3 = mounted_contact_sample.get("contact_end", mounted_start)
			var mounted_contact := mounted_start.lerp(mounted_end, 0.78)
			_set_enemy_fixture(combat_system, enemy_id, Vector3(mounted_contact.x, source_origin.y, mounted_contact.z), 500)
			await physics_frame
			var displaced_lock := {
				"type": "enemy",
				"id": "displaced_locked_target",
				"name": "displaced lock",
				"position": source_origin + Vector3(4.0, 0.0, 4.0),
			}
			var mounted_hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
			combat_system._begin_melee_swing("friendly", NPC_ID, weapon_id, displaced_lock, _sequence)
			await _feed_model_samples(combat_system, animation_player, weapon_id, mounted_clip, mounted_impact_authored, window, count)
			var mounted_hit: Dictionary = combat_system._resolve_npc_melee_contact(
				NPC_ID,
				npc_system.get_npc(NPC_ID),
				displaced_lock,
				combat_system._calculate_npc_attack_context(NPC_ID, npc_system.get_npc(NPC_ID), npc_system.get_npc_state(NPC_ID))
			)
			_check(str(mounted_hit.get("actual_target_enemy_id", "")) == enemy_id, "%s mounted sweep did not damage the enemy actually touched" % weapon_id)
			_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) < mounted_hp_before, "%s mounted visible contact did not apply damage" % weapon_id)
		var configured_range := float(weapon.get("range", 0.0))
		var mounted_configured_range := float(contact_config.get("mounted_range", configured_range))
		_check(configured_range + 0.005 >= forward_contact_range, "%s configured foot range %.3f is shorter than model contact %.3f" % [weapon_id, configured_range, forward_contact_range])
		_check(mounted_configured_range + 0.005 >= mounted_forward_contact_range, "%s configured mounted range %.3f is shorter than model contact %.3f" % [weapon_id, mounted_configured_range, mounted_forward_contact_range])

	await _verify_enemy_foot_contact(combat_system, npc_system, npc_actor, enemy_id)
	combat_system.debug_clear_enemies()
	await process_frame
	_finish()


func _collect_model_samples(
	npc_system: Node,
	animation_player: AnimationPlayer,
	weapon_id: String,
	clip_name: String,
	impact_authored: float,
	window: float,
	count: int
) -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	animation_player.play(clip_name, 0.0)
	for index in range(maxi(2, count)):
		var weight := float(index) / float(maxi(2, count) - 1)
		animation_player.seek(lerpf(maxf(0.0, impact_authored - window), impact_authored, weight), true)
		animation_player.pause()
		await process_frame
		var sample: Dictionary = npc_system.get_npc_combat_melee_contact_segment(NPC_ID, weapon_id)
		if not sample.is_empty():
			samples.append(sample)
	return samples


func _feed_model_samples(
	combat_system: Node,
	animation_player: AnimationPlayer,
	weapon_id: String,
	clip_name: String,
	impact_authored: float,
	window: float,
	count: int
) -> void:
	animation_player.play(clip_name, 0.0)
	for index in range(maxi(2, count)):
		var weight := float(index) / float(maxi(2, count) - 1)
		animation_player.seek(lerpf(maxf(0.0, impact_authored - window), impact_authored, weight), true)
		animation_player.pause()
		await process_frame
		combat_system._sample_melee_swing("friendly:%s" % NPC_ID)


func _verify_enemy_foot_contact(combat_system: Node, npc_system: Node, npc_actor: Node3D, enemy_id: String) -> void:
	# Detach this one deterministic fixture from the marching-stage presenter so
	# its normal route sync cannot replace the attack pose between sampled frames.
	var formal_slices: Dictionary = combat_system.get("_formal_first_wave_slices")
	formal_slices.erase(enemy_id)
	combat_system.set("_formal_first_wave_slices", formal_slices)
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "verify_t0144_enemy_target", {"request_plan_reevaluation": false})
	npc_system.update_npc_state(NPC_ID, {"hp": 100, "max_hp": 100, "unconscious": false, "escaped": false, "combat_mounted": false})
	var enemy_position := Vector3(70.0, 0.0, 70.0)
	npc_actor.global_position = enemy_position + Vector3(0.0, 0.0, -4.0)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var timing: Dictionary = COMBAT_ANIMATION_TIMING.get_timing("sword_shield", float(enemy.get("attack_interval", 1.8)))
	var contact_config: Dictionary = combat_system._get_weapon_melee_contact_config("sword_shield")
	var impact_authored := float(timing.get("impact_authored_seconds", 0.0))
	var window := float(contact_config.get("sample_window_authored_seconds", 0.24))
	var count := int(contact_config.get("sample_count", 7))
	_sequence += 1
	var locked_target := {
		"type": "npc",
		"id": NPC_ID,
		"name": "Stableman",
		"position": npc_actor.global_position,
		"contact_radius": 0.35,
	}
	enemy["position"] = enemy_position
	enemy["weapon_type"] = "sword_shield"
	enemy["unit_type"] = "melee_infantry"
	enemy["target"] = locked_target.duplicate(true)
	enemy["current_action"] = "winding_up_%s" % NPC_ID
	enemy["attack_sequence"] = _sequence
	enemy["attack_cycle_phase"] = "windup"
	enemy["attack_cycle_elapsed"] = 0.0
	enemy["attack_cycle_duration"] = float(timing.get("cycle_seconds", 1.0))
	enemy["attack_impact_seconds"] = float(timing.get("impact_seconds", 0.0))
	enemy["attack_playback_multiplier"] = float(timing.get("playback_multiplier", 1.0))
	_set_active_enemy(combat_system, enemy_id, enemy)
	_set_enemy_fixture(combat_system, enemy_id, enemy_position, int(enemy.get("hp", 500)))
	await physics_frame
	await process_frame
	var node_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(node_paths.get(enemy_id, NodePath())) as Node3D if node_paths.has(enemy_id) else null
	var art_view := enemy_node.get_node_or_null("EnemyArtView") as Node3D if enemy_node != null else null
	var animation_player := art_view.find_child("PilotAnimationPlayer", true, false) as AnimationPlayer if art_view != null else null
	_check(art_view != null and animation_player != null, "Enemy formal sword model was unavailable")
	if art_view == null or animation_player == null:
		return
	var samples: Array[Dictionary] = []
	animation_player.play("Melee_1H_Attack_Slice_Horizontal", 0.0)
	for index in range(maxi(2, count)):
		var weight := float(index) / float(maxi(2, count) - 1)
		animation_player.seek(lerpf(maxf(0.0, impact_authored - window), impact_authored, weight), true)
		animation_player.pause()
		await process_frame
		var sample: Dictionary = art_view.get_combat_melee_contact_segment("sword_shield")
		if not sample.is_empty():
			samples.append(sample)
	_check(samples.size() >= 2, "Enemy formal sword did not publish contact samples")
	if samples.size() < 2:
		return
	var contact_sample: Dictionary = samples[samples.size() - 1]
	var max_reach := 0.0
	for sample in samples:
		var tip: Vector3 = sample.get("contact_end", enemy_position)
		var reach := Vector2(tip.x - enemy_position.x, tip.z - enemy_position.z).length()
		if reach > max_reach:
			max_reach = reach
			contact_sample = sample
	var contact_start: Vector3 = contact_sample.get("contact_start", enemy_position)
	var contact_end: Vector3 = contact_sample.get("contact_end", contact_start)
	var actual_contact := contact_start.lerp(contact_end, 0.78)
	npc_actor.global_position = Vector3(actual_contact.x, enemy_position.y, actual_contact.z)
	await physics_frame
	var hp_before := int(npc_system.get_npc_state(NPC_ID).get("hp", 0))
	combat_system._begin_melee_swing("enemy", enemy_id, "sword_shield", locked_target, _sequence)
	animation_player.play("Melee_1H_Attack_Slice_Horizontal", 0.0)
	for index in range(maxi(2, count)):
		var weight := float(index) / float(maxi(2, count) - 1)
		animation_player.seek(lerpf(maxf(0.0, impact_authored - window), impact_authored, weight), true)
		animation_player.pause()
		await process_frame
		combat_system._sample_melee_swing("enemy:%s" % enemy_id)
	var hit: Dictionary = combat_system._resolve_enemy_melee_contact(combat_system.get_enemy(enemy_id), locked_target)
	_check(str(hit.get("actual_target_id", "")) == NPC_ID, "Enemy sword did not resolve the NPC actually touched: %s" % JSON.stringify(hit.get("melee_contact", {})))
	_check(int(npc_system.get_npc_state(NPC_ID).get("hp", 0)) < hp_before, "Enemy visible sword contact did not apply damage: %s" % JSON.stringify(hit.get("melee_contact", {})))


func _set_active_enemy(combat_system: Node, enemy_id: String, enemy: Dictionary) -> void:
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)


func _measure_forward_contact_range(
	samples: Array[Dictionary],
	source_origin: Vector3,
	facing: Vector3,
	effective_radius: float
) -> float:
	var segments: Array[Dictionary] = []
	var previous: Dictionary = {}
	for sample in samples:
		var contact_start: Vector3 = sample.get("contact_start", source_origin)
		var contact_end: Vector3 = sample.get("contact_end", contact_start)
		segments.append({"from": contact_start, "to": contact_end})
		if not previous.is_empty():
			var previous_start: Vector3 = previous.get("contact_start", contact_start)
			var previous_end: Vector3 = previous.get("contact_end", contact_end)
			for blade_weight in [0.0, 0.5, 1.0]:
				segments.append({
					"from": previous_start.lerp(previous_end, blade_weight),
					"to": contact_start.lerp(contact_end, blade_weight),
				})
		previous = sample
	var normalized_facing := Vector2(facing.x, facing.z).normalized()
	var origin_2d := Vector2(source_origin.x, source_origin.z)
	var farthest := 0.0
	for step in range(401):
		var candidate_distance := float(step) * 0.01
		var candidate := origin_2d + normalized_facing * candidate_distance
		for segment in segments:
			var from_3d: Vector3 = segment.get("from", source_origin)
			var to_3d: Vector3 = segment.get("to", from_3d)
			var from_2d := Vector2(from_3d.x, from_3d.z)
			var to_2d := Vector2(to_3d.x, to_3d.z)
			if Geometry2D.get_closest_point_to_segment(candidate, from_2d, to_2d).distance_to(candidate) <= effective_radius:
				farthest = candidate_distance
				break
	return farthest


func _keep_one_enemy(combat_system: Node) -> String:
	var enemy_ids: Array = combat_system.get_active_enemy_ids()
	if enemy_ids.is_empty():
		return ""
	var kept_id := str(enemy_ids[0])
	for raw_enemy_id in enemy_ids:
		if str(raw_enemy_id) != kept_id:
			combat_system._remove_enemy_from_combat(str(raw_enemy_id))
	return kept_id


func _set_enemy_fixture(combat_system: Node, enemy_id: String, position: Vector3, hp: int) -> void:
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	var node_paths: Dictionary = combat_system.get("_enemy_nodes")
	var enemy_node := combat_system.get_node_or_null(node_paths.get(enemy_id, NodePath())) as Node3D if node_paths.has(enemy_id) else null
	if enemy_node != null:
		enemy_node.global_position = position
	combat_system._refresh_enemy_node(enemy_id)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0144_MELEE_MODEL_CONTACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0144_MELEE_MODEL_CONTACT FAIL count=%d" % _failures.size())
	quit(1)
