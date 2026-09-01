extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	if [npc_system, combat_system, horse_system, building_system, device_system, resource_system, presenter].has(null):
		_fail("T0312 required systems or presenter not found")
		return

	if not _verify_npc_damage_and_healing(npc_system, presenter):
		return
	if not _verify_enemy_damage_and_removal(combat_system, presenter):
		return
	if not _verify_horse_damage(horse_system, presenter):
		return
	if not _verify_building_damage_and_repair(building_system, presenter):
		return
	if not _verify_device_damage(device_system, resource_system, presenter):
		return

	for _frame in 8:
		await process_frame
	main.queue_free()
	for _frame in 3:
		await process_frame
		await physics_frame
	print("T0312 combat world feedback verification passed.")
	quit(0)


func _verify_npc_damage_and_healing(npc_system: Node, presenter: Node) -> bool:
	var damage_id := "priest_01"
	npc_system.update_npc_state(damage_id, {"hp": 30, "max_hp": 100, "unconscious": false})
	var first: Dictionary = npc_system.apply_damage_to_npc(damage_id, 7, "veteran_deputy_01", "private", {
		"request_plan_reevaluation": false,
		"skip_low_hp_judgement": true
	})
	if int(first.get("hp_before", 0)) - int(first.get("hp_after", 0)) != 7:
		return _fail("NPC damage authority did not commit the expected delta")
	var damage_group := _find_group(presenter, "npc:%s" % damage_id, "damage")
	if not _has_number_entry(damage_group, "damage", -7):
		return _fail("NPC damage did not create a red actual-delta number")

	var second: Dictionary = npc_system.apply_damage_to_npc(damage_id, 99, "veteran_deputy_01", "private", {
		"request_plan_reevaluation": false,
		"skip_low_hp_judgement": true
	})
	if int(second.get("hp_before", 0)) - int(second.get("hp_after", 0)) != 23:
		return _fail("NPC overkill did not clamp to actual remaining HP")
	var groups: Array = presenter.debug_get_snapshot()
	if _count_groups(groups, "npc:%s" % damage_id, "damage") != 1:
		return _fail("A new NPC hit did not immediately replace its prior damage number")
	damage_group = _find_group(presenter, "npc:%s" % damage_id, "damage")
	if not _has_number_entry(damage_group, "damage", -23):
		return _fail("NPC overkill feedback reported requested damage instead of actual HP loss")

	presenter.debug_advance_feedback(2.1)
	var recovery_hp_before := int(npc_system.get_npc_state(damage_id).get("hp", 0))
	npc_system.debug_advance_unconscious_recovery(damage_id, 3600.0)
	var recovered := int(npc_system.get_npc_state(damage_id).get("hp", 0)) - recovery_hp_before
	if recovered <= 0:
		return _fail("Unconscious natural recovery did not commit HP")
	var healing_group := _find_group(presenter, "npc:%s" % damage_id, "healing")
	if not _has_number_entry(healing_group, "heal", recovered):
		return _fail("Unconscious natural recovery did not create a green actual-delta number")

	presenter.debug_advance_feedback(2.1)
	var clinic_id := "cook_01"
	npc_system.update_npc_state(clinic_id, {"hp": 90, "max_hp": 100, "unconscious": false, "escaped": false})
	var clinic_first: Dictionary = npc_system.restore_npc_hp(clinic_id, 4, "clinic_treatment", "doctor_01")
	if int(clinic_first.get("hp_after", 0)) - int(clinic_first.get("hp_before", 0)) != 4:
		return _fail("Clinic healing did not clamp to actual missing HP")
	var clinic: Dictionary = npc_system.restore_npc_hp(clinic_id, 50, "clinic_treatment", "doctor_01")
	if int(clinic.get("hp_after", 0)) - int(clinic.get("hp_before", 0)) != 6:
		return _fail("Clinic over-healing did not clamp to actual missing HP")
	healing_group = _find_group(presenter, "npc:%s" % clinic_id, "healing")
	if not _has_number_entry(healing_group, "heal", 10):
		return _fail("Rapid clinic healing did not merge its two actual HP gains")
	var count_before: int = presenter.debug_get_snapshot().size()
	npc_system.restore_npc_hp(clinic_id, 10, "clinic_treatment", "doctor_01")
	if presenter.debug_get_snapshot().size() != count_before:
		return _fail("Zero-effective NPC healing fabricated feedback")
	presenter.debug_advance_feedback(2.1)
	return true


func _verify_enemy_damage_and_removal(combat_system: Node, presenter: Node) -> bool:
	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn.get("ok", false)):
		return _fail("Could not prepare enemies for T0312 verification")
	var enemies: Array[Dictionary] = combat_system.get_active_enemies()
	if enemies.size() < 2:
		return _fail("T0312 area-style verification requires at least two enemies")
	for index in 2:
		var enemy: Dictionary = enemies[index]
		var enemy_id := str(enemy.get("id", enemy.get("enemy_id", "")))
		combat_system._apply_damage_to_enemy(enemy_id, 3 + index, "veteran_deputy_01")
		var group := _find_group(presenter, "enemy:%s" % enemy_id, "damage")
		if not _has_number_entry(group, "damage", -(3 + index)):
			return _fail("Multi-target enemy damage did not emit one actual number per target")

	var defeated_enemy: Dictionary = enemies[0]
	var defeated_id := str(defeated_enemy.get("id", defeated_enemy.get("enemy_id", "")))
	var remaining_hp := int(combat_system.get_enemy(defeated_id).get("hp", 0))
	var defeated: Dictionary = combat_system._apply_damage_to_enemy(defeated_id, remaining_hp + 999, "veteran_deputy_01")
	if not bool(defeated.get("defeated", false)) or not combat_system.get_enemy(defeated_id).is_empty():
		return _fail("Enemy removal setup did not complete")
	var defeated_group := _find_group(presenter, "enemy:%s" % defeated_id, "damage")
	if defeated_group.is_empty() or not _has_number_entry(defeated_group, "damage", -remaining_hp):
		return _fail("Removed enemy did not retain its last-position actual damage feedback")
	if not defeated_group.get("last_world_position", null) is Vector3:
		return _fail("Removed enemy feedback did not preserve a fallback world position")
	presenter.debug_advance_feedback(2.1)
	combat_system.debug_clear_enemies()
	return true


func _verify_horse_damage(horse_system: Node, presenter: Node) -> bool:
	var horse_ids: Array[String] = horse_system.get_horse_ids()
	if horse_ids.is_empty():
		return _fail("No horse available for T0312 verification")
	var horse_id := horse_ids[0]
	var hp_before := float(horse_system.get_horse_snapshot(horse_id).get("hp", 0.0))
	var result: Dictionary = horse_system.apply_damage_to_horse(horse_id, 4.0, {"attacker_id": "verify_t0312"})
	var actual := float(result.get("hp_before", 0.0)) - float(result.get("hp_after", 0.0))
	if not is_equal_approx(actual, minf(4.0, hp_before)):
		return _fail("Horse authority did not report actual HP loss")
	var group := _find_group(presenter, "horse:%s" % horse_id, "damage")
	if not _has_number_entry(group, "damage", -actual):
		return _fail("Horse damage did not create a separate red actual-delta number")
	presenter.debug_advance_feedback(2.1)
	return true


func _verify_building_damage_and_repair(building_system: Node, presenter: Node) -> bool:
	var building_id := "warehouse"
	var building: Dictionary = building_system.get_building(building_id)
	var hp_before := int(building.get("hp", 0))
	var hit_position := Vector3(9.0, 1.5, 11.0)
	var damaged: Dictionary = building_system.apply_damage_to_building(
		building_id,
		7,
		"verify_t0312",
		"private",
		{"hit_world_position": hit_position}
	)
	if hp_before - int(damaged.get("hp_after", hp_before)) != 7:
		return _fail("Building damage authority did not commit the expected delta")
	var group := _find_group(presenter, "building:%s" % building_id, "damage")
	if not _has_number_entry(group, "damage", -7):
		return _fail("Building damage did not create a red actual-delta number")
	if not bool(group.get("prefer_fallback_position", false)) or group.get("fallback_world_position", null) != hit_position:
		return _fail("Building damage did not prefer the supplied hit position")
	presenter.debug_advance_feedback(2.1)
	if not building_system.restore_building_hp(building_id, 99):
		return _fail("Building repair authority rejected a valid repair")
	group = _find_group(presenter, "building:%s" % building_id, "healing")
	if not _has_number_entry(group, "heal", 7):
		return _fail("Building repair did not create a green actual-delta number")
	var count_before: int = presenter.debug_get_snapshot().size()
	building_system.restore_building_hp(building_id, 1)
	if presenter.debug_get_snapshot().size() != count_before:
		return _fail("Zero-effective building repair fabricated feedback")
	presenter.debug_advance_feedback(2.1)
	return true


func _verify_device_damage(device_system: Node, resource_system: Node, presenter: Node) -> bool:
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	if not bool(deployed.get("ok", false)):
		return _fail("Could not deploy a defense device for T0312 verification")
	var deployment_id := str(deployed.get("deployment_id", ""))
	var hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var result: Dictionary = device_system.apply_damage_to_device(deployment_id, hp_before + 999, {
		"attacker_id": "verify_t0312"
	})
	if int(result.get("hp_before", 0)) - int(result.get("hp_after", 0)) != hp_before:
		return _fail("Defense device overkill did not clamp to actual HP")
	if not device_system.get_deployment(deployment_id).is_empty():
		return _fail("Destroyed defense device was not removed")
	var group := _find_group(presenter, "defense_device:%s" % deployment_id, "damage")
	if not _has_number_entry(group, "damage", -hp_before):
		return _fail("Destroyed defense device did not retain actual damage feedback")
	if not group.get("last_world_position", null) is Vector3:
		return _fail("Destroyed defense device feedback did not preserve its last position")
	presenter.debug_advance_feedback(2.1)
	return true


func _find_group(presenter: Node, anchor_key: String, channel: String) -> Dictionary:
	for raw_group in presenter.debug_get_snapshot():
		if not raw_group is Dictionary:
			continue
		var group: Dictionary = raw_group
		if str(group.get("anchor_key", "")) == anchor_key and str(group.get("channel", "")) == channel:
			return group
	return {}


func _count_groups(groups: Array, anchor_key: String, channel: String) -> int:
	var count := 0
	for raw_group in groups:
		if raw_group is Dictionary and str(raw_group.get("anchor_key", "")) == anchor_key and str(raw_group.get("channel", "")) == channel:
			count += 1
	return count


func _has_number_entry(group: Dictionary, color_role: String, amount: Variant) -> bool:
	for raw_entry in group.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if (
			str(entry.get("display_name", "")) == ""
			and str(entry.get("color_role", "")) == color_role
			and is_equal_approx(float(entry.get("amount", 0.0)), float(amount))
		):
			return true
	return false


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
