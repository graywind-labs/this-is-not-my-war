extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0350 could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	if [combat_system, npc_system, equipment_system, presenter].has(null):
		_fail("T0350 required runtime nodes are missing")
		return

	var config: Dictionary = combat_system.get_combat_progression_config()
	if (
		int(config.get("weapon_damage_per_skill_point", 0)) != 50
		or int(config.get("riding_damage_per_skill_point", 0)) != 100
		or int(config.get("kill_total_experience", 0)) != 1
		or bool(config.get("count_overkill_damage", true))
		or bool(config.get("defense_device_grants_npc_growth", true))
		or bool(config.get("meteor_grants_npc_growth", true))
		or bool(config.get("horse_collision_grants_npc_growth", true))
	):
		_fail("T0350 combat progression config mismatch: %s" % JSON.stringify(config))
		return

	combat_system.debug_clear_enemies()
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("T0350 failed to prepare wave targets")
		return
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	if enemy_ids.size() < 5:
		_fail("T0350 requires at least five wave targets")
		return

	if not _verify_weapon_thresholds_and_feedback(
		combat_system,
		npc_system,
		presenter,
		enemy_ids[0]
	):
		return
	if not _verify_mounted_dual_growth_and_launch_snapshot(
		combat_system,
		npc_system,
		presenter,
		enemy_ids[1]
	):
		return
	if not _verify_kill_overkill_and_exclusions(
		combat_system,
		npc_system,
		presenter,
		enemy_ids
	):
		return
	if not _verify_riding_combat_multipliers(
		combat_system,
		npc_system,
		equipment_system
	):
		return
	if not _verify_growth_checkpoint_roundtrip(npc_system):
		return

	main.queue_free()
	await process_frame
	print("T0350 combat growth and riding verification passed.")
	quit(0)


func _verify_weapon_thresholds_and_feedback(
	combat_system: Node,
	npc_system: Node,
	presenter: Node,
	enemy_id: String
) -> bool:
	var npc_id := "veteran_deputy_01"
	_reset_growth(npc_system, npc_id, {"剑盾": 0, "弓": 0, "骑术": 0})
	_prepare_enemy(combat_system, enemy_id, 1000)
	presenter.debug_advance_feedback(3.0)

	var first: Dictionary = combat_system._apply_damage_to_enemy(
		enemy_id,
		49,
		npc_id,
		_growth_context("剑盾", false)
	)
	var first_growth: Dictionary = first.get("combat_growth", {})
	if (
		int(first.get("actual_damage", 0)) != 49
		or int((first_growth.get("weapon_growth", {}) as Dictionary).get("amount", -1)) != 0
		or _skill_remainder(npc_system, npc_id, "剑盾") != 49
		or _growth_groups(presenter, npc_id).size() != 0
	):
		return _fail("T0350 sub-threshold weapon damage or silent feedback mismatch")

	combat_system._apply_damage_to_enemy(
		enemy_id,
		1,
		npc_id,
		_growth_context("剑盾", false)
	)
	var after_threshold: Dictionary = npc_system.get_npc(npc_id)
	if (
		int((after_threshold.get("skills", {}) as Dictionary).get("剑盾", 0)) != 1
		or int(npc_system.get_npc_progression(npc_id).get("total_experience", 0)) != 1
		or _skill_remainder(npc_system, npc_id, "剑盾") != 0
	):
		return _fail("T0350 50 actual damage did not grant exactly one weapon point")
	var groups := _growth_groups(presenter, npc_id)
	if groups.size() != 1 or not _has_component(groups[0], "剑盾", 1) or not _has_component(groups[0], "经验", 1):
		return _fail("T0350 weapon threshold did not show one combined overhead growth group")
	presenter.debug_advance_feedback(3.0)

	combat_system._apply_damage_to_enemy(enemy_id, 25, npc_id, _growth_context("弓", false))
	combat_system._apply_damage_to_enemy(enemy_id, 25, npc_id, _growth_context("剑盾", false))
	if _skill_remainder(npc_system, npc_id, "弓") != 25 or _skill_remainder(npc_system, npc_id, "剑盾") != 25:
		return _fail("T0350 weapon damage remainders did not remain separated after switching weapons")

	_reset_growth(npc_system, npc_id, {"剑盾": 99, "骑术": 0}, {"剑盾": 49})
	combat_system._apply_damage_to_enemy(enemy_id, 100, npc_id, _growth_context("剑盾", false))
	var capped: Dictionary = npc_system.get_npc(npc_id)
	if (
		int((capped.get("skills", {}) as Dictionary).get("剑盾", 0)) != 100
		or _skill_remainder(npc_system, npc_id, "剑盾") != 0
		or int(npc_system.get_npc_progression(npc_id).get("total_experience", 0)) != 1
	):
		return _fail("T0350 skill cap must clamp growth and discard surplus combat damage")
	presenter.debug_advance_feedback(3.0)
	return true


func _verify_mounted_dual_growth_and_launch_snapshot(
	combat_system: Node,
	npc_system: Node,
	presenter: Node,
	enemy_id: String
) -> bool:
	var npc_id := "stableman_01"
	_reset_growth(npc_system, npc_id, {"长杆": 0, "弓": 0, "骑术": 0})
	_prepare_enemy(combat_system, enemy_id, 1000)
	presenter.debug_advance_feedback(3.0)
	var captured_context := _growth_context("长杆", true)
	# The live state changes before impact; only captured_context may decide riding growth.
	npc_system.update_npc_state(npc_id, {"combat_mounted": false})
	combat_system._apply_damage_to_enemy(enemy_id, 100, npc_id, captured_context)
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {})
	var progression: Dictionary = npc_system.get_npc_progression(npc_id)
	if (
		int(skills.get("长杆", 0)) != 2
		or int(skills.get("骑术", 0)) != 1
		or int(progression.get("total_experience", 0)) != 3
	):
		return _fail("T0350 mounted damage did not grant weapon and riding growth from launch snapshot")
	var groups := _growth_groups(presenter, npc_id)
	if (
		groups.size() != 1
		or not _has_component(groups[0], "长杆", 2)
		or not _has_component(groups[0], "骑术", 1)
		or not _has_component(groups[0], "经验", 3)
	):
		return _fail("T0350 mounted dual growth was not merged into one overhead group")
	presenter.debug_advance_feedback(3.0)
	return true


func _verify_kill_overkill_and_exclusions(
	combat_system: Node,
	npc_system: Node,
	presenter: Node,
	enemy_ids: Array[String]
) -> bool:
	var npc_id := "blacksmith_01"
	_reset_growth(npc_system, npc_id, {"剑盾": 0, "骑术": 0})
	var kill_target := enemy_ids[2]
	_prepare_enemy(combat_system, kill_target, 20)
	presenter.debug_advance_feedback(3.0)
	var kill_result: Dictionary = combat_system._apply_damage_to_enemy(
		kill_target,
		999,
		npc_id,
		_growth_context("剑盾", false)
	)
	var progression: Dictionary = npc_system.get_npc_progression(npc_id)
	var skill_experience: Dictionary = progression.get("skill_experience", {})
	if (
		int(kill_result.get("actual_damage", 0)) != 20
		or _skill_remainder(npc_system, npc_id, "剑盾") != 20
		or int(progression.get("total_experience", 0)) != 1
		or int(skill_experience.get("剑盾", 0)) != 0
	):
		return _fail("T0350 overkill or total-only kill experience mismatch")
	var groups := _growth_groups(presenter, npc_id)
	if groups.size() != 1 or not _has_component(groups[0], "经验", 1) or _has_component(groups[0], "剑盾", 1):
		return _fail("T0350 kill experience overhead feedback mismatch")
	var duplicate: Dictionary = combat_system._apply_damage_to_enemy(
		kill_target,
		1,
		npc_id,
		_growth_context("剑盾", false)
	)
	if not duplicate.is_empty() or int(npc_system.get_npc_progression(npc_id).get("total_experience", 0)) != 1:
		return _fail("T0350 one enemy granted kill experience more than once")
	presenter.debug_advance_feedback(3.0)

	var device_target := enemy_ids[3]
	_prepare_enemy(combat_system, device_target, 1000)
	var before_device: Dictionary = npc_system.get_npc_progression(npc_id).duplicate(true)
	combat_system.apply_defense_device_attack(device_target, 120.0, {
		"deployment_id": "t0350_device",
		"device_id": "ballista"
	})
	combat_system._apply_damage_to_enemy(device_target, 120, npc_id, {
		"source_type": "horse_collision"
	})
	combat_system.apply_enemy_area_damage(
		combat_system.get_enemy_world_position(device_target),
		100.0,
		120.0,
		{"source_type": "piety_meteor", "source_id": "meteor"}
	)
	var after_exclusions: Dictionary = npc_system.get_npc_progression(npc_id)
	if (
		int(after_exclusions.get("total_experience", 0)) != int(before_device.get("total_experience", 0))
		or _skill_remainder(npc_system, npc_id, "剑盾") != 20
		or not _growth_groups(presenter, npc_id).is_empty()
	):
		return _fail("T0350 device, meteor, or horse-collision damage granted NPC growth")
	return true


func _verify_riding_combat_multipliers(
	combat_system: Node,
	npc_system: Node,
	equipment_system: Node
) -> bool:
	var npc_id := "veteran_deputy_01"
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var equipment: Dictionary = profile.get("equipment", {}).duplicate(true)
	var mount: Dictionary = equipment_system.get_mount_def("riding_horse")
	mount["horse_id"] = "t0350_horse"
	mount["horse_name"] = "验收马"
	equipment["mount"] = mount
	profile["equipment"] = equipment
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	skills["骑术"] = 0
	profile["skills"] = skills
	npc_system._profiles[npc_id] = profile
	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "combat",
		"combat_mounted": false,
		"satiety": 100.0,
		"fatigue": 0.0
	})
	var npc_node := _npc_node(npc_system, npc_id)
	var unmounted_speed := float(npc_node.get_locomotion_needs_snapshot().get("authoritative_move_speed", 0.0))
	var unmounted_attack := float((combat_system.get_npc_combat_stats(npc_id).get("final", {}) as Dictionary).get("attack_speed", 0.0))

	npc_system.update_npc_state(npc_id, {"combat_mounted": true})
	var riding_zero_speed := float(npc_node.get_locomotion_needs_snapshot().get("authoritative_move_speed", 0.0))
	var riding_zero_attack := float((combat_system.get_npc_combat_stats(npc_id).get("final", {}) as Dictionary).get("attack_speed", 0.0))
	if (
		not is_equal_approx(riding_zero_speed / unmounted_speed, 1.35)
		or not is_equal_approx(riding_zero_attack / unmounted_attack, 1.05)
	):
		return _fail("T0350 fixed mount multipliers must require true mounted state")

	for riding_value in [35, 48, 100]:
		profile = npc_system.get_npc(npc_id)
		skills = profile.get("skills", {}).duplicate(true)
		skills["骑术"] = riding_value
		profile["skills"] = skills
		npc_system._profiles[npc_id] = profile
		npc_system._refresh_npc_node(npc_id)
		var riding_speed := float(npc_node.get_locomotion_needs_snapshot().get("authoritative_move_speed", 0.0))
		var riding_stats: Dictionary = combat_system.get_npc_combat_stats(npc_id)
		var riding_attack := float((riding_stats.get("final", {}) as Dictionary).get("attack_speed", 0.0))
		var expected_speed_multiplier := 1.0 + float(riding_value) / 100.0 * 0.12
		var expected_attack_multiplier := 1.0 + float(riding_value) / 100.0 * 0.08
		if (
			not is_equal_approx(riding_speed / riding_zero_speed, expected_speed_multiplier)
			or not is_equal_approx(riding_attack / riding_zero_attack, expected_attack_multiplier)
			or not is_equal_approx(
				float((riding_stats.get("growth", {}) as Dictionary).get("riding_attack_speed_multiplier", 0.0)),
				expected_attack_multiplier
			)
		):
			return _fail("T0350 riding %d multiplier interpolation mismatch" % riding_value)
	return true


func _verify_growth_checkpoint_roundtrip(npc_system: Node) -> bool:
	var npc_id := "doctor_01"
	_reset_growth(npc_system, npc_id, {"弓": 7, "骑术": 3}, {"弓": 37, "骑术": 81}, 9)
	var checkpoint: Dictionary = npc_system.create_formal_spatial_checkpoint()
	var saved_actor := _find_checkpoint_actor(checkpoint, npc_id)
	var saved_growth: Dictionary = saved_actor.get("growth", {})
	if (
		int((saved_growth.get("skills", {}) as Dictionary).get("弓", 0)) != 7
		or int(((saved_growth.get("progression", {}) as Dictionary).get("combat_damage_remainders", {}) as Dictionary).get("弓", 0)) != 37
	):
		return _fail("T0350 spatial checkpoint omitted combat growth progress")
	_reset_growth(npc_system, npc_id, {"弓": 99, "骑术": 99}, {"弓": 0, "骑术": 0}, 99)
	var restore_result: Dictionary = npc_system.restore_formal_spatial_checkpoint(checkpoint)
	if not bool(restore_result.get("ok", false)):
		return _fail("T0350 growth checkpoint restore failed: %s" % JSON.stringify(restore_result))
	var restored: Dictionary = npc_system.get_npc(npc_id)
	var restored_progression: Dictionary = npc_system.get_npc_progression(npc_id)
	if (
		int((restored.get("skills", {}) as Dictionary).get("弓", 0)) != 7
		or _skill_remainder(npc_system, npc_id, "弓") != 37
		or _skill_remainder(npc_system, npc_id, "骑术") != 81
		or int(restored_progression.get("total_experience", 0)) != 9
	):
		return _fail("T0350 combat growth did not survive checkpoint roundtrip")
	return true


func _growth_context(skill_name: String, mounted_at_attack: bool) -> Dictionary:
	return {
		"source_type": "npc_weapon",
		"npc_combat_growth_eligible": true,
		"required_skill": skill_name,
		"mounted_at_attack": mounted_at_attack
	}


func _reset_growth(
	npc_system: Node,
	npc_id: String,
	skill_values: Dictionary,
	remainders: Dictionary = {},
	total_experience: int = 0
) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var skills: Dictionary = profile.get("skills", {}).duplicate(true)
	for raw_skill_name in skill_values.keys():
		skills[str(raw_skill_name)] = int(skill_values[raw_skill_name])
	profile["skills"] = skills
	profile["progression"] = {
		"total_experience": total_experience,
		"unspent_skill_points": 0,
		"spent_skill_points": 0,
		"skill_experience": {},
		"combat_damage_remainders": remainders.duplicate(true)
	}
	npc_system._profiles[npc_id] = profile
	npc_system._refresh_npc_node(npc_id)


func _prepare_enemy(combat_system: Node, enemy_id: String, hp: int) -> void:
	var enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = enemies.get(enemy_id, {}).duplicate(true)
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", enemies)


func _skill_remainder(npc_system: Node, npc_id: String, skill_name: String) -> int:
	var progression: Dictionary = npc_system.get_npc_progression(npc_id)
	var remainders: Dictionary = progression.get("combat_damage_remainders", {})
	return int(remainders.get(skill_name, 0))


func _growth_groups(presenter: Node, npc_id: String) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for raw_group in presenter.debug_get_snapshot():
		if not raw_group is Dictionary:
			continue
		var group: Dictionary = raw_group
		if str(group.get("anchor_key", "")) == "npc:%s" % npc_id and str(group.get("channel", "")) == "growth":
			groups.append(group)
	return groups


func _has_component(group: Dictionary, display_name: String, amount: int) -> bool:
	for raw_entry in group.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		for raw_component in (raw_entry as Dictionary).get("components", []):
			if (
				raw_component is Dictionary
				and str((raw_component as Dictionary).get("display_name", "")) == display_name
				and int((raw_component as Dictionary).get("amount", 0)) == amount
			):
				return true
	return false


func _find_checkpoint_actor(checkpoint: Dictionary, npc_id: String) -> Dictionary:
	for raw_actor in checkpoint.get("actors", []):
		if raw_actor is Dictionary and str((raw_actor as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_actor as Dictionary).duplicate(true)
	return {}


func _npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
