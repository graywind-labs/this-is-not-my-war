extends SceneTree

const NPCPromptProfile = preload("res://scripts/core/NPCPromptProfile.gd")
const FORBIDDEN_PROMPT_COMBAT_KEYS: Array[String] = [
	"combat_base",
	"defense",
	"penetration",
	"penetration_modifier",
	"attack_power_modifier",
	"attack_speed_modifier",
	"charge_speed_multiplier",
	"charge_weapon_damage_multiplier",
	"charge_damage",
	"charge_damage_riding_scale",
	"charge_stagger_seconds"
]


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn failed to load.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var slot_presenter := root.get_node_or_null("Main/UI/DefenseSlotPresenter")
	if [
		combat_system,
		npc_system,
		resource_system,
		equipment_system,
		building_system,
		device_system,
		llm_bridge,
		memory_system,
		slot_presenter
	].has(null):
		_fail("T0107 required runtime nodes are missing.")
		return

	if not _verify_wave_pressure(combat_system):
		return
	if not _verify_device_balance_and_slots(device_system, building_system, slot_presenter):
		return
	if not _verify_damage_resolution(combat_system):
		return
	if not _verify_npc_stats_and_prompt_boundary(
		combat_system,
		npc_system,
		resource_system,
		equipment_system,
		llm_bridge
	):
		return
	if not await _verify_deployment_and_range(
		device_system,
		resource_system,
		memory_system,
		slot_presenter
	):
		return
	if not _verify_charge_impact(
		combat_system,
		npc_system,
		equipment_system
	):
		return

	print("T0107 combat foundation verification passed.")
	quit(0)


func _verify_wave_pressure(combat_system: Node) -> bool:
	var counts: Array[int] = []
	for wave_number in combat_system.get_wave_numbers():
		var wave: Dictionary = combat_system.get_wave_config(int(wave_number))
		var count := 0
		for raw_group in wave.get("enemies", []):
			var group: Dictionary = raw_group
			count += int(group.get("count", 0))
			for required_field in ["defense", "penetration", "attack_speed", "attack_windup"]:
				if not group.has(required_field):
					return _fail("Wave %s group lacks %s." % [wave_number, required_field])
		counts.append(count)
	if counts != [8, 16, 24, 36, 48]:
		return _fail("Enemy pressure curve mismatch: %s" % str(counts))
	for index in range(1, counts.size()):
		if counts[index] <= counts[index - 1]:
			return _fail("Enemy counts must strictly increase by wave.")
	return true


func _verify_device_balance_and_slots(
	device_system: Node,
	building_system: Node,
	slot_presenter: Node
) -> bool:
	var ballista: Dictionary = device_system.get_device_definition("wall_ballista")
	var arrow_tower: Dictionary = device_system.get_device_definition("wall_arrow_tower")
	var ballista_effect: Dictionary = ballista.get("effect", {})
	var arrow_effect: Dictionary = arrow_tower.get("effect", {})
	if int(ballista.get("tier", 0)) != int(arrow_tower.get("tier", -1)):
		return _fail("Ballista and arrow tower must share a tier.")
	if (
		float(ballista_effect.get("damage", 0.0)) <= float(arrow_effect.get("damage", 0.0))
		or float(ballista_effect.get("penetration", 0.0)) <= float(arrow_effect.get("penetration", 0.0))
		or float(ballista_effect.get("range", 0.0)) <= float(arrow_effect.get("range", 0.0))
		or float(ballista_effect.get("attack_speed", 0.0)) >= float(arrow_effect.get("attack_speed", 0.0))
		or int(ballista.get("max_hp", 0)) >= int(arrow_tower.get("max_hp", 0))
	):
		return _fail("Defense device tradeoffs do not match the design.")

	for building_id in ["wall", "main_hall"]:
		var slots: Array = device_system.get_slots_for_building(building_id, true)
		if slots.size() != 4:
			return _fail("%s must define four deployment slots." % building_id)
		var required_levels: Array[int] = []
		for raw_slot in slots:
			var slot: Dictionary = raw_slot
			required_levels.append(int(slot.get("required_building_level", 0)))
			if not (slot.get("allowed_device_ids", []) as Array).has("wall_ballista"):
				return _fail("%s slot must accept ballista." % building_id)
			if not (slot.get("allowed_device_ids", []) as Array).has("wall_arrow_tower"):
				return _fail("%s slot must accept arrow tower." % building_id)
			var range_multiplier := float((slot.get("effect_modifiers", {}) as Dictionary).get("range_multiplier", 0.0))
			var expected_multiplier := 2.0 if building_id == "main_hall" else 1.0
			if not is_equal_approx(range_multiplier, expected_multiplier):
				return _fail("%s slot range multiplier mismatch." % building_id)
		required_levels.sort()
		var expected_levels: Array = (
			[1, 3, 5, 6]
			if building_id == "main_hall"
			else [1, 2, 4, 6]
		)
		if required_levels != expected_levels:
			return _fail("%s slot unlock levels mismatch: %s." % [
				building_id,
				str(required_levels)
			])
		var building: Dictionary = building_system.get_building(building_id)
		if int((building.get("upgrade", {}) as Dictionary).get("max_level", 0)) != 6:
			return _fail("%s must support Lv.6." % building_id)

	var open_marker: Dictionary = slot_presenter.debug_get_marker_snapshot("wall_slot_01")
	var locked_marker: Dictionary = slot_presenter.debug_get_marker_snapshot("wall_slot_02")
	if str(open_marker.get("text", "")) != "+" or not bool(open_marker.get("unlocked", false)):
		return _fail("The first wall slot must expose a clickable + marker.")
	if (
		bool(locked_marker.get("visible", true))
		or not str(locked_marker.get("text", "")).is_empty()
		or bool(locked_marker.get("unlocked", true))
	):
		return _fail("Locked world slots must stay hidden until their host level unlocks them.")
	if not slot_presenter.debug_open_slot("wall_slot_01"):
		return _fail("The world slot + must open the deployment selector.")
	return true


func _verify_damage_resolution(combat_system: Node) -> bool:
	var blocked: Dictionary = combat_system.calculate_damage_resolution(20.0, 10.0, 0.0)
	var penetrated: Dictionary = combat_system.calculate_damage_resolution(20.0, 10.0, 6.0)
	if not is_equal_approx(float(penetrated.get("effective_defense", -1.0)), 4.0):
		return _fail("Effective defense must be max(0, defense - penetration).")
	if int(penetrated.get("damage", 0)) <= int(blocked.get("damage", 0)):
		return _fail("Penetration must increase resolved damage against armor.")
	if not is_equal_approx(float(blocked.get("damage_multiplier", 0.0)), 20.0 / 30.0):
		return _fail("Defense must use the 20 / (20 + effective defense) curve.")
	return true


func _verify_npc_stats_and_prompt_boundary(
	combat_system: Node,
	npc_system: Node,
	resource_system: Node,
	equipment_system: Node,
	llm_bridge: Node
) -> bool:
	if int(npc_system.get_npc_state("veteran_deputy_01").get("max_hp", 0)) != 120:
		return _fail("Veteran deputy initial HP profile mismatch.")
	if int(npc_system.get_npc_state("priest_01").get("max_hp", 0)) != 85:
		return _fail("Priest initial HP profile mismatch.")

	resource_system.add_resources({
		"item_sword_shield": 1,
		"item_mail_chest": 1
	})
	if not bool(equipment_system.equip_npc_main_weapon(
		"veteran_deputy_01",
		"sword_shield",
		"private"
	).get("ok", false)):
		return _fail("Failed to equip sword and shield for combat stat verification.")
	var armed_stats: Dictionary = combat_system.get_npc_combat_stats("veteran_deputy_01")
	var armed_final: Dictionary = armed_stats.get("final", {})
	if float(armed_final.get("defense", 0.0)) <= 0.0 or float(armed_final.get("penetration", 0.0)) <= 0.0:
		return _fail("Weapon and NPC base stats must produce defense and penetration.")

	if not bool(equipment_system.equip_npc_armor(
		"veteran_deputy_01",
		"chest",
		"mail_chest",
		"private"
	).get("ok", false)):
		return _fail("Failed to equip armor for combat stat verification.")
	var armored_stats: Dictionary = combat_system.get_npc_combat_stats("veteran_deputy_01")
	var armored_final: Dictionary = armored_stats.get("final", {})
	if float(armored_final.get("defense", 0.0)) <= float(armed_final.get("defense", 0.0)):
		return _fail("Armor must increase defense.")
	if float(armored_final.get("attack_speed", INF)) >= float(armed_final.get("attack_speed", 0.0)):
		return _fail("Heavy chest armor must reduce attack speed.")

	var before_growth := armored_stats
	npc_system.increase_npc_skill("veteran_deputy_01", "剑盾", 10)
	var leveled_stats: Dictionary = combat_system.get_npc_combat_stats("veteran_deputy_01")
	if int(leveled_stats.get("level", 1)) <= int(before_growth.get("level", 1)):
		return _fail("Ten points in one weapon-training track must raise combat level.")
	var before_strength: Dictionary = leveled_stats.get("final", {}).duplicate(true)
	var strength_result: Dictionary = npc_system.assign_npc_attribute_point(
		"veteran_deputy_01",
		"strength"
	)
	if not bool(strength_result.get("ok", false)):
		return _fail("Growth XP should provide a strength point for verification.")
	var after_strength: Dictionary = combat_system.get_npc_combat_stats(
		"veteran_deputy_01"
	).get("final", {})
	for stat_id in ["attack_power", "defense", "penetration"]:
		if float(after_strength.get(stat_id, 0.0)) <= float(before_strength.get(stat_id, 0.0)):
			return _fail("Strength must increase %s." % stat_id)

	var npc: Dictionary = npc_system.get_npc("veteran_deputy_01")
	var state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
	var prompt_state: Dictionary = llm_bridge._build_npc_state_context(npc, state)
	var prompt_setting: Dictionary = NPCPromptProfile.build_setting(npc)
	var leaked_key := _find_forbidden_key(prompt_state)
	if not leaked_key.is_empty():
		return _fail("New combat field leaked into NPC state Prompt payload: %s" % leaked_key)
	leaked_key = _find_forbidden_key(prompt_setting)
	if not leaked_key.is_empty():
		return _fail("New combat field leaked into NPC setting Prompt payload: %s" % leaked_key)
	var prompt_weapon: Dictionary = (prompt_state.get("equipment", {}) as Dictionary).get("main_weapon", {})
	if str(prompt_weapon.get("id", "")) != "sword_shield":
		return _fail("Prompt equipment projection must retain weapon identity.")
	return true


func _verify_deployment_and_range(
	device_system: Node,
	resource_system: Node,
	memory_system: Node,
	slot_presenter: Node
) -> bool:
	resource_system.add_resource("item_wall_ballista", 2)
	var wall_result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var hall_result: Dictionary = device_system.deploy_device("wall_ballista", "main_hall_slot_01")
	if not bool(wall_result.get("ok", false)) or not bool(hall_result.get("ok", false)):
		return _fail("Wall and main hall deployment should both succeed.")
	await process_frame
	var wall: Dictionary = device_system.get_deployment(str(wall_result.get("deployment_id", "")))
	var hall: Dictionary = device_system.get_deployment(str(hall_result.get("deployment_id", "")))
	var wall_range := float((wall.get("effect", {}) as Dictionary).get("range", 0.0))
	var hall_range := float((hall.get("effect", {}) as Dictionary).get("range", 0.0))
	if not is_equal_approx(hall_range, wall_range * 2.0):
		return _fail("Main hall deployment must double effective range.")
	if bool(slot_presenter.debug_get_marker_snapshot("wall_slot_01").get("visible", true)):
		return _fail("Occupied world slot must hide its + marker.")

	var event_count_before: int = memory_system.get_event_log().size()
	var hp_before := int(hall.get("hp", 0))
	var damage_result: Dictionary = device_system.apply_damage_to_device(
		str(hall.get("deployment_id", "")),
		5,
		{"attacker_id": "verify_enemy"}
	)
	if int(damage_result.get("hp_after", hp_before)) != hp_before - 5:
		return _fail("Defense device HP must accept enemy damage.")
	if memory_system.get_event_log().size() != event_count_before:
		return _fail("Device damage must not add a new information-system event.")
	return true


func _verify_charge_impact(
	combat_system: Node,
	npc_system: Node,
	equipment_system: Node
) -> bool:
	var npc_id := "veteran_deputy_01"
	var mount_result: Dictionary = equipment_system.equip_npc_mount(npc_id, "", "private")
	if not bool(mount_result.get("ok", false)):
		return _fail("Failed to equip a mount for charge verification: %s" % JSON.stringify(mount_result))
	var strategy_result: Dictionary = combat_system.set_npc_combat_strategy(
		npc_id,
		"charge_cycle",
		"private",
		"verify_t0107"
	)
	if not bool(strategy_result.get("ok", false)):
		return _fail("Mounted melee NPC must accept charge_cycle.")

	combat_system.debug_clear_enemies()
	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		return _fail("Failed to spawn charge verification target.")
	var enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var npc_position := Vector3(0.0, 0.0, 0.0)
	_set_npc_world_position(npc_system, npc_id, npc_position)
	var active_enemies: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active_enemies.get(enemy_id, {})
	enemy["position"] = Vector3(0.0, 0.0, 1.0)
	enemy["hp"] = 200
	enemy["max_hp"] = 200
	enemy["attack_windup_remaining"] = 0.3
	enemy["attack_windup_target"] = {"type": "npc", "id": npc_id}
	active_enemies[enemy_id] = enemy
	combat_system.set("_active_enemies", active_enemies)
	npc_system.set_npc_behavior_mode(npc_id, "combat", "verify_t0107_charge", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": enemy_id,
			"combat_attack_cooldown": 0.0,
			"combat_charge_phase": "impact"
		},
		"request_plan_reevaluation": false
	})
	var base_attack := float(
		(combat_system.get_npc_combat_stats(npc_id).get("final", {}) as Dictionary).get(
			"attack_power",
			0.0
		)
	)
	var attack_context: Dictionary = combat_system._calculate_npc_attack_context(
		npc_id,
		npc_system.get_npc(npc_id),
		npc_system.get_npc_state(npc_id)
	)
	var impact_seconds := float((attack_context.get("animation_timing", {}) as Dictionary).get("impact_seconds", 0.0))
	var windup_result: Dictionary = combat_system._advance_single_npc_combat_attack(npc_id, maxf(0.001, impact_seconds - 0.01))
	if int(windup_result.get("attack_count", 0)) != 0:
		return _fail("Charge collision must wait for the approved weapon impact: %s" % JSON.stringify(windup_result))
	var attack_result: Dictionary = combat_system._advance_single_npc_combat_attack(npc_id, 0.02)
	if int(attack_result.get("attack_count", 0)) != 1:
		return _fail("Charge impact must resolve exactly one attack: %s" % JSON.stringify(attack_result))
	var attacks: Array = attack_result.get("attacks", [])
	var attack: Dictionary = attacks[0]
	var impact: Dictionary = attack.get("charge_impact", {})
	if (
		impact.is_empty()
		or int(impact.get("collision_damage", 0)) <= 0
		or float(impact.get("weapon_damage_multiplier", 1.0)) <= 1.0
		or (int(attack.get("damage", 0)) > 0 and float(attack.get("raw_attack_power", 0.0)) <= base_attack)
	):
		return _fail("Charge must always add horse collision and amplify weapon damage only when the weapon actually contacts.")
	if not bool(impact.get("interrupted_windup", false)):
		return _fail("Horse collision stagger must interrupt an enemy windup.")
	var enemy_after: Dictionary = combat_system.get_enemy(enemy_id)
	if float(enemy_after.get("stagger_remaining", 0.0)) <= 0.0:
		return _fail("Charge target must retain a visible stagger state.")
	var state_after: Dictionary = npc_system.get_npc_state(npc_id)
	if str(state_after.get("combat_charge_phase", "")) != "withdraw":
		return _fail("Cavalry must withdraw after impact.")
	return true


func _set_npc_world_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var npc_nodes: Dictionary = npc_system.get("_npc_nodes")
	var npc_node := root.get_node_or_null(NodePath(str(npc_nodes.get(npc_id, "")))) as Node3D
	if npc_node != null:
		npc_node.global_position = position


func _find_forbidden_key(value: Variant) -> String:
	if value is Dictionary:
		for raw_key in (value as Dictionary).keys():
			var key := str(raw_key)
			if FORBIDDEN_PROMPT_COMBAT_KEYS.has(key) or key.begins_with("charge_"):
				return key
			var nested := _find_forbidden_key((value as Dictionary).get(raw_key))
			if not nested.is_empty():
				return nested
	elif value is Array:
		for item in value:
			var nested := _find_forbidden_key(item)
			if not nested.is_empty():
				return nested
	return ""


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
